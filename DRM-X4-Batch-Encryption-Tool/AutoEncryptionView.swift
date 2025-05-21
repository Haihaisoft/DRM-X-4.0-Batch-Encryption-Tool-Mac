import SwiftUI
import SQLite3
class TimerHolder: ObservableObject {
    @Published var timer: Timer?
}
struct AutoEncryptionView: View {
    let user: User?

    @State private var watchDirectory: URL?
    @State private var outputDirectory: URL?
    @State private var watchDirectoryScopedAccess: Bool = false
    @State private var outputDirectoryScopedAccess: Bool = false
    @State private var isWatching: Bool = false
    
    @State private var isProcessing: Bool = false
    @State private var fileStabilityMap: [String: (size: Int64, timestamp: Date)] = [:]
    
    @State private var files: [FileItem] = []
    @State private var showingWatchDirectoryPicker = false
    @State private var showingOutputDirectoryPicker = false
    @State private var Rights: [Right] = []
    @State private var selectedRight: Right? = nil
    @State private var isLoadingRights = false
    @State private var selectedFileID: UUID? = nil
    @State private var shouldStopEncryption: Bool = false
    @State private var currentProcessingFileID: UUID? = nil
    @StateObject private var timerHolder = TimerHolder()

    struct Right: Identifiable, Hashable {
        let id: String
        let name: String
    }

    // Add window proxy properties
    @State private var windowDelegate: WindowDelegate? = nil
    private var serviceURL: String {
        user?.isChineseVersion ?? false ? "https://4.drm-x.cn/haihaisoftlicenseservice.asmx" : "https://4.drm-x.com/haihaisoftlicenseservice.asmx"
    }

    private let databasePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("FileProcessLogDB.db").path

    // MARK: Interface layout entry
    var body: some View {
        let isChinese = user?.isChineseVersion ?? false
        VStack(spacing: 16) {
            HStack {
                Text(localized("scan_directory", isChinese: isChinese)).frame(width: 110, alignment: .leading)
                TextField(localized("set_scan_directory", isChinese: isChinese), text: Binding(get: { watchDirectory?.path ?? "" }, set: { _ in })).disabled(true)
                Button(localized("browse", isChinese: isChinese)) {
                    showingWatchDirectoryPicker = true
                }
                .fileImporter(isPresented: $showingWatchDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        watchDirectory?.stopAccessingSecurityScopedResource()
                        watchDirectory = url
                    }
                }
            }

            HStack {
                Text(localized("output_directory", isChinese: isChinese)).frame(width: 110, alignment: .leading)
                TextField(localized("select_output_directory", isChinese: isChinese), text: Binding(get: { outputDirectory?.path ?? "" }, set: { _ in })).disabled(true)
                Button(localized("browse", isChinese: isChinese)) {
                    showingOutputDirectoryPicker = true
                }
                // File chooser code
                .fileImporter(isPresented: $showingOutputDirectoryPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        outputDirectory?.stopAccessingSecurityScopedResource()
                        outputDirectory = url
                        outputDirectoryScopedAccess = url.startAccessingSecurityScopedResource()
                    }
                }
            }
            
            //MARK: License Rights Selection
            HStack {
                Text(localized("license_right", isChinese: isChinese))
                    .frame(width: 110, alignment: .leading)
                
                if isLoadingRights {
                    ProgressView()
                } else {
                    Picker("", selection: $selectedRight) {
                        ForEach(Rights, id: \.self) { right in
                            Text("\(right.id) || \(right.name)").tag(right as Right?)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedRight) { newValue in }
                }
            }

            // MARK: File List
            ScrollViewReader { proxy in
                List(selection: $selectedFileID) {
                    HStack {
                        Text(localized("file_name", isChinese: isChinese)).font(.headline).frame(width: 200, alignment: .leading)
                        Text(localized("input_path", isChinese: isChinese)).font(.headline).frame(width: 180, alignment: .leading)
                        Text(localized("output_path", isChinese: isChinese)).font(.headline).frame(width: 180, alignment: .leading)
                        Text(localized("file_size", isChinese: isChinese)).font(.headline).frame(width: 80, alignment: .leading)
                        Text(localized("status", isChinese: isChinese)).font(.headline).frame(width: 140, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    ForEach(files) { file in
                        HStack {
                            Text(file.name).frame(width: 200, alignment: .leading).lineLimit(1).help(file.name)
                            Text(file.inputPath).frame(width: 180, alignment: .leading).lineLimit(1).help(file.inputPath)
                            Text(file.outputPath.isEmpty ? "..." : file.outputPath).frame(width: 180, alignment: .leading).foregroundColor(file.outputPath.isEmpty ? .gray : .primary).lineLimit(1).help(file.outputPath.isEmpty ? "..." : file.outputPath)
                            Text(file.formattedSize).frame(width: 80, alignment: .leading)
                            Text(file.status.localizedString(isChinese: user?.isChineseVersion ?? false)).frame(width: 140, alignment: .leading).foregroundColor(statusColor(for: file.status))
                        }
                        .padding(.vertical, 2)
                        .tag(file.id)
                        .id(file.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFileID = file.id
                        }
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded { // Double click to open
                                selectedFileID = file.id
                                openFile(url: URL(fileURLWithPath: file.inputPath))
                            }
                        )
                        .contextMenu {
                            Button(localized("open_input_folder", isChinese: isChinese)) {
                                selectedFileID = file.id
                                openFolder(url: URL(fileURLWithPath: file.inputPath))
                            }
                            Button(localized("open_output_folder", isChinese: isChinese)) {
                                selectedFileID = file.id
                                if !file.outputPath.isEmpty {
                                    openFolder(url: URL(fileURLWithPath: file.outputPath))
                                }
                            }
                        }
                        .background(
                            selectedFileID == file.id ? Color.blue.opacity(0.2) : Color.clear
                        )
                    }
                }
                .frame(maxHeight: .infinity)
                .listStyle(PlainListStyle())
                .onChange(of: currentProcessingFileID) { newValue in
                    if let id = newValue {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }

            // MARK: Interface buttons
            HStack {
                Button(action: startScanning) {
                    Text(isWatching ? localized("scanning", isChinese: isChinese) : localized("start_scanning", isChinese: isChinese)).frame(width: 100, height: 30)
                }
                .disabled(isWatching || watchDirectory == nil || outputDirectory == nil)
                .buttonStyle(.borderedProminent)

                Button(action: stopScanning) {
                    Text(localized("stop_scanning", isChinese: isChinese)).frame(width: 100, height: 30)
                }
                .disabled(!isWatching)
                .buttonStyle(.bordered)

                Button(action: clearFiles) {
                    Text(localized("clear_list", isChinese: isChinese)).frame(width: 100, height: 30)
                }
                .disabled(isWatching)
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding()
        
        // Set the window delegate in onAppear
        .onAppear {
            createLogDatabaseIfNeeded()
            loadRights()
            // Setting the window proxy
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                    let isChinese = user?.isChineseVersion ?? false
                    self.windowDelegate = WindowDelegate(
                        isProcessing: isWatching, 
                        isChinese: isChinese,
                        taskType: .autoScanning,
                        onWindowClose: {
                            // Set a stop flag
                            self.shouldStopEncryption = true
                            self.isWatching = false
                            self.timerHolder.timer?.invalidate()
                            self.timerHolder.timer = nil
                            
                            // Wait for the current task to complete
                            DispatchQueue.global(qos: .background).async {
                                // Wait for the current process to complete
                                while self.isProcessing {
                                    Thread.sleep(forTimeInterval: 0.1)
                                }
                            }
                        }
                    )
                    window.delegate = self.windowDelegate
                    
                    // Listen for isWatching status changes
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("WatchingStatusChanged"), object: nil, queue: .main) { notification in
                        if let isWatching = notification.userInfo?["isWatching"] as? Bool {
                            self.windowDelegate = WindowDelegate(
                                isProcessing: isWatching, 
                                isChinese: isChinese,
                                taskType: .autoScanning,
                                onWindowClose: {
                                    // Set a stop flag
                                    self.shouldStopEncryption = true
                                    self.isWatching = false
                                    self.timerHolder.timer?.invalidate()
                                    self.timerHolder.timer = nil
                                    
                                    // Wait for the current task to complete
                                    DispatchQueue.global(qos: .background).async {
                                        // Wait for the current process to complete
                                        while self.isProcessing {
                                            Thread.sleep(forTimeInterval: 0.1)
                                        }
                                    }
                                }
                            )
                            window.delegate = self.windowDelegate
                        }
                    }
                }
            }
        }
    }
    // Send a notification when isWatching changes
    private func updateWatchingStatus() {
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchingStatusChanged"),
            object: nil,
            userInfo: ["isWatching": isWatching]
        )
    }
    
    // Loading permission list
    private func loadRights() {
        guard let user = user else { return }
        
        isLoadingRights = true
        
        let client = SOAPClient()
        client.listRights(
            endpoint: serviceURL,
            soapAction: serviceURL + "?op=ListRightsAsString",
            adminemail: user.adminemail,
            authStr: user.webServiceCode
        ) { result in
            DispatchQueue.main.async {
                isLoadingRights = false
                if let result = result {
                    // Parse the permission string
                    let rightsList = result.components(separatedBy: ";;")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    // Parse each permission string into an ID and a name
                    self.Rights = rightsList.compactMap { rightStr -> Right? in
                        let parts = rightStr.components(separatedBy: "||")
                        if parts.count >= 2 {
                            return Right(id: parts[0], name: parts[1])
                        }
                        return nil
                    }
                    
                    // If you have Rights, the first one is selected by default
                    if !self.Rights.isEmpty {
                        self.selectedRight = self.Rights[0]
                        //print("Selected Rights: ID=\(self.selectedRight!.id), Name=\(self.selectedRight!.name)")
                    }
                } else {
                    print("Failed to obtain permission list")
                }
            }
        }
    }

    // MARK: Start Scanning
    private func startScanning() {
        isWatching = true
        shouldStopEncryption = false  // Reset stop flag
        updateWatchingStatus()

        // Perform scanning and encryption operations in a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.scanAndUpdateFiles()
        }
        
        timerHolder.timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if self.isWatching {
                // Perform scanning and encryption operations in a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    self.scanAndUpdateFiles()
                }
            }
        }
    }

    // MARK: Stop Scanning
    private func stopScanning() {
        let isChinese = user?.isChineseVersion ?? false
        
        //Creating a Confirmation Dialog Box
        let alert = NSAlert()
        alert.messageText = localized("stop_scanning_confirmation_title", isChinese: isChinese)
        alert.informativeText = localized("stop_scanning_confirmation_message", isChinese: isChinese)
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("confirm", isChinese: isChinese))
        alert.addButton(withTitle: localized("cancel", isChinese: isChinese))
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User confirms stop
            isWatching = false
            shouldStopEncryption = true  // Set a stop flag
            timerHolder.timer?.invalidate()
            timerHolder.timer = nil
            
            // Show stop prompt
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = localized("scan_stopped_title", isChinese: isChinese)
                alert.informativeText = localized("scan_stopped_message", isChinese: isChinese)
                alert.alertStyle = .informational
                alert.addButton(withTitle: localized("ok", isChinese: isChinese))
                alert.runModal()
            }
        }
        // If the user cancels, no action is taken
    }

    // MARK: Clear Files
    private func clearFiles() {
        files.removeAll()
    }

    // MARK: Scan and update the file list
    private func scanAndUpdateFiles() {
        // If it is already being processed, return directly
        guard !isProcessing else { return }
        
        // Set the processing flag
        isProcessing = true
        
        // Reset the processing flag at the end of the function
        defer {
            isProcessing = false
        }
        
        guard let watchURL = watchDirectory, let outputDir = outputDirectory else { return }
        let scoped = watchURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                watchURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        var updatedFiles = files

        do {
            let items = try fileManager.contentsOfDirectory(at: watchURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            // Phase 1: Scan files only, no encryption
            for item in items {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    // Recursively scan all files in a directory
                    scanDirectory(item, allFiles: &updatedFiles)
                }
            }
            
            // Update UI to display scanned files
            DispatchQueue.main.async {
                self.files = updatedFiles
            }
            
            // Phase 2: Processing the license template and encrypting the file
            for item in items {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    var licenseID = ""
                    let folderName = item.lastPathComponent
                    
                    // Check if the folder has been processed
                    if !folderExistsInDB(path: item.path) {
                        let components = folderName.split(separator: "_")
                        let firstComponent = components.count >= 2 ? String(components[0]) : "0"
                        
                        // Check if productID is a valid digital ID
                        let productID: String
                        if let _ = Int(firstComponent) {
                            productID = firstComponent  // If it is a number, use that value
                        } else {
                            productID = "0"  // If not a number, the default value 0 is used.
                        }

                        // Call the API to add a license profile
                        let client = SOAPClient()
                        let group = DispatchGroup()
                        group.enter()
                        
                        client.addLicenseProfile(
                            endpoint: serviceURL,
                            soapAction: serviceURL + "?op=AddLicenseProfile",
                            adminemail: user?.adminemail ?? "",
                            authStr: user?.webServiceCode ?? "",
                            profileName: folderName,
                            productID: productID,
                            forceInternet: "False"
                        ) { result in
                            if let profileID = result {
                                licenseID = profileID
                                insertFolderLicenseRecord(folderName: folderName, folderPath: item.path, licenseID: profileID, productID: productID)
                                
                                // Adding Rights to a License Profile
                                if let selectedRight = self.selectedRight {
                                    let rightClient = SOAPClient()
                                    
                                    rightClient.addRightToLicenseProfile(
                                        endpoint: serviceURL,
                                        soapAction: serviceURL + "?op=AddRightToLicenseProfile",
                                        adminemail: user?.adminemail ?? "",
                                        authStr: user?.webServiceCode ?? "",
                                        rightID: Int(selectedRight.id) ?? 0,
                                        licenseProfileID: Int(licenseID) ?? 0
                                    ) { result in
                                        if result == "1" {
                                            print("Successfully added RIghts to the License Profile")
                                        } else {
                                            print("Failed to add Rights to License Profile: \(result ?? "Unknown error")")
                                        }
                                    }
                                }
                            }
                            group.leave()
                        }
                        
                        group.wait()
                    } else {
                        // Get the License Profile ID from the database
                        licenseID = getLicenseIDFromDB(folderPath: item.path)
                    }
                    
                    // If the license ID is obtained, the files in the directory are encrypted
                    if !licenseID.isEmpty {
                        // Create a new copy to avoid concurrent modifications
                        var localUpdatedFiles = updatedFiles
                        
                        // Process files in file list order
                        processFilesInOrder(dir: item, licenseID: licenseID, outputDir: outputDir, allFiles: &localUpdatedFiles)
                        
                        // Safely update the file list
                        updatedFiles = localUpdatedFiles
                        
                        // Update the UI every time a directory is processed to improve user experience
                        DispatchQueue.main.async {
                            self.files = updatedFiles
                        }
                    }
                }
            }
        } catch {
            print("Scanning directory failed: \(error)")
        }
    }

    // MARK: Scan Directory
    private func scanDirectory(_ dir: URL, allFiles: inout [FileItem]) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            for url in fileURLs {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // Recursively process subdirectories
                    scanDirectory(url, allFiles: &allFiles)
                } else {
                    guard ["mp3", "mp4", "pdf"].contains(url.pathExtension.lowercased()) else { continue }
                    
                    // Check if the file already exists in the database, if so skip it
                    if fileExistsInDB(filePath: url.path) {
                        continue
                    }
                    
                    // Check if the file is stable (fully copied and size is not 0)
                    if !isFileStable(url: url) {
                        continue // Skip unstable files
                    }
                    
                    // Check if the file is already in the list
                    if let existingIndex = allFiles.firstIndex(where: { $0.inputPath == url.path }) {
                        // The file already exists and is marked as pending only if the file status is not completed
                        if allFiles[existingIndex].status != .completed && !fileExistsInDB(filePath: url.path) {
                            allFiles[existingIndex].status = .pending
                        }
                    } else {
                        // New file, added to the list
                        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        let fileItem = FileItem(
                            name: url.lastPathComponent,
                            inputPath: url.path,
                            outputPath: "",
                            size: Int64(size)
                        )
                        allFiles.append(fileItem)
                    }
                }
            }
        } catch {
            print("Scanning directory failed: \(error)")
        }
    }

    // MARK: Process files in file list order
    private func processFilesInOrder(dir: URL, licenseID: String, outputDir: URL, allFiles: inout [FileItem]) {
        
        // 1. Get all pending files in the current directory and its subdirectories
        let pendingFiles = allFiles.filter {
            $0.status == .pending && 
            $0.inputPath.hasPrefix(dir.path)
        }
        
        // 2. Get the order of files displayed in the UI
        let tempFiles = self.files
        var uiFileOrder: [UUID] = []
        
        // Use the main thread to synchronize the UI file order
        DispatchQueue.main.sync {
            uiFileOrder = tempFiles.map { $0.id }
        }
        
        // 3. Sort the files to be processed according to the UI display order
        let sortedPendingFiles = pendingFiles.sorted { file1, file2 in
            let index1 = uiFileOrder.firstIndex(of: file1.id) ?? Int.max
            let index2 = uiFileOrder.firstIndex(of: file2.id) ?? Int.max
            return index1 < index2
        }
        
        // 4. Process files in sorted order
        for fileItem in sortedPendingFiles {
            // Check if encryption should be stopped
            if shouldStopEncryption {
                break
            }

            // Processing files
            if let index = allFiles.firstIndex(where: { $0.id == fileItem.id }) {
                var updatedItem = allFiles[index]
                
                // If the file has been processed, skip processing
                if updatedItem.status == .completed || fileExistsInDB(filePath: updatedItem.inputPath) {
                    continue
                }
                
                // Set the status to processing and update the UI
                updatedItem.status = .processing
                let fileID = updatedItem.id
                
                DispatchQueue.main.async {
                    self.currentProcessingFileID = fileID  // Set the ID of the currently processed file
                    if let uiIndex = self.files.firstIndex(where: { $0.id == fileID }) {
                        self.files[uiIndex].status = .processing
                    }
                }
                
                // Encrypt File
                encryptFile(fileItem: &updatedItem, licenseID: licenseID, outputDir: outputDir)
                
                // Update file list
                allFiles[index] = updatedItem
                
                // Update UI
                let finalStatus = updatedItem.status
                let outputPath = updatedItem.outputPath
                let errorMessage = updatedItem.errorMessage
                
                DispatchQueue.main.async {
                    if let uiIndex = self.files.firstIndex(where: { $0.id == fileID }) {
                        self.files[uiIndex].status = finalStatus
                        self.files[uiIndex].outputPath = outputPath
                        self.files[uiIndex].errorMessage = errorMessage
                    }
                }
            }
        }
        
        // 5. Finally, update the UI again to ensure that all file status and output paths are displayed correctly
        // Create a copy to avoid capturing inout parameters in the closure
        let finalAllFiles = allFiles
        
        // Use the main thread to update the UI synchronously and ensure that the update is completed before continuing execution
        DispatchQueue.main.sync {
            for file in finalAllFiles {
                if let uiIndex = self.files.firstIndex(where: { $0.id == file.id }) {
                    if self.files[uiIndex].status != .completed {
                        // Update output path only if file status is Completed
                        if file.status == .completed {
                            self.files[uiIndex].outputPath = file.outputPath
                        }
                        self.files[uiIndex].status = file.status
                        self.files[uiIndex].errorMessage = file.errorMessage
                    }
                }
            }
        }
    }

    // MARK: Encrypt pending files
    private func encryptPendingFiles(dir: URL, licenseID: String, outputDir: URL, allFiles: inout [FileItem]) {
        // Create a copy that processes the files in the order they appear in the interface
        let filesToProcess = allFiles.filter { $0.status == .pending }
        
        // Process files in the order they are displayed on the interface
        for i in 0..<filesToProcess.count {
            // Check if encryption should be stopped
            if shouldStopEncryption {
                break
            }

            let fileItem = filesToProcess[i]
            
            // 查Find the index of the file in allFiles
            if let index = allFiles.firstIndex(where: { $0.id == fileItem.id }) {
                // If the file has been processed, skip processing
                if allFiles[index].status == .completed || fileExistsInDB(filePath: fileItem.inputPath) {
                    continue
                }
                // Set the status to "Processing" and update the UI immediately
                var updatedItem = allFiles[index]
                updatedItem.status = .processing
                let fileID = updatedItem.id
                
                DispatchQueue.main.async {
                    if let uiIndex = self.files.firstIndex(where: { $0.id == fileID }) {
                        self.files[uiIndex].status = .processing
                    }
                }
                
                // Encrypt File
                encryptFile(fileItem: &updatedItem, licenseID: licenseID, outputDir: outputDir)
                
                // Update the status of a file in the file list
                allFiles[index] = updatedItem
                
                // Update UI now
                let finalStatus = updatedItem.status
                let outputPath = updatedItem.outputPath
                let errorMessage = updatedItem.errorMessage
                
                DispatchQueue.main.async {
                    if let uiIndex = self.files.firstIndex(where: { $0.id == fileID }) {
                        self.files[uiIndex].status = finalStatus
                        self.files[uiIndex].outputPath = outputPath
                        self.files[uiIndex].errorMessage = errorMessage
                    }
                }
            }
        }
        
        // Recursively process subdirectories
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
            
            for url in fileURLs {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // Recursively process subdirectories
                    encryptPendingFiles(dir: url, licenseID: licenseID, outputDir: outputDir, allFiles: &allFiles)
                }
            }
        } catch {
            print("Scanning directory failed: \(error)")
        }
    }
    
    // MARK: Encrypt File
    private func encryptFile(fileItem: inout FileItem, licenseID: String, outputDir: URL) {
    
        // Make sure you have access rights to the output directory
        let outputScoped = outputDirectory?.startAccessingSecurityScopedResource() ?? false
        defer {
            if outputScoped {
                outputDirectory?.stopAccessingSecurityScopedResource()
            }
        }
        
        let inputURL = URL(fileURLWithPath: fileItem.inputPath)
        
        // Calculate relative paths, preserving directory structure
        let relativePath = inputURL.path.replacingOccurrences(of: watchDirectory?.path ?? "", with: "")
        let relativeURL = URL(fileURLWithPath: relativePath)
        let relativeDir = relativeURL.deletingLastPathComponent().path
        
        // Get the top-level folder name (first-level directory)
        var pathComponents = relativeDir.split(separator: "/").map(String.init)
        let topLevelFolderName = pathComponents.isEmpty ? "" : pathComponents[0]
        
        // Create a new top-level folder name: LicenseProfileID_OriginalFolderName
        let newTopLevelFolderName = "\(licenseID)_\(topLevelFolderName)"
        
        // Construct a new relative path, replacing only the top-level folder name
        if !pathComponents.isEmpty {
            pathComponents[0] = newTopLevelFolderName
            let newRelativeDir = "/" + pathComponents.joined(separator: "/")
            
            // Create Output Directory
            let outputFolder = outputDir.appendingPathComponent(newRelativeDir)
            do {
                try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create output directory: \(error.localizedDescription)")
                fileItem.status = .failed
                fileItem.errorMessage = "Failed to create directory: \(error.localizedDescription)"
                return
            }
            
            // Construct output file name (add _P suffix)
            let fileName = inputURL.deletingPathExtension().lastPathComponent + "_P"
            let fileExtension = inputURL.pathExtension
            let outputFileName = fileName + "." + fileExtension
            let outputPath = outputFolder.appendingPathComponent(outputFileName).path
            
            // Set the output path
            fileItem.outputPath = outputPath
        } else {
            // If there is no relative path (the file is directly under the monitoring directory), the file is created directly in the output directory
            let outputFolder = outputDir.appendingPathComponent("\(licenseID)_files")
            do {
                try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create output directory: \(error.localizedDescription)")
                fileItem.status = .failed
                fileItem.errorMessage = "Failed to create directory: \(error.localizedDescription)"
                return
            }
            
            // Construct output file name (add _P suffix)
            let fileName = inputURL.deletingPathExtension().lastPathComponent + "_P"
            let fileExtension = inputURL.pathExtension
            let outputFileName = fileName + "." + fileExtension
            let outputPath = outputFolder.appendingPathComponent(outputFileName).path
            
            // Set the output path
            fileItem.outputPath = outputPath
        }
        
        // Get the encryption tool path
        guard let mp4encryptPath = Bundle.main.resourceURL?.appendingPathComponent("mp4encrypt").path else {
            fileItem.status = .failed
            fileItem.errorMessage = "Unable to find mp4encrypt executable"
            return
        }
        
        // MARK: Set encryption command parameters
        let domain = user?.isChineseVersion ?? false ? "CN" : "COM"
        let adminEmail = user?.adminemail ?? ""
        let authStr = user?.webServiceCode ?? ""
        
        let command = [
            mp4encryptPath,
            "-ServerDomain", domain,
            "-AdminEmail", adminEmail,
            "-WebServiceAuthStr", authStr,
            "-ID", licenseID,
            "-Input", fileItem.inputPath,
            "-Output", fileItem.outputPath
        ]
        
        // MARK: Execute encryption command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Update the UI after encryption is successful
            if process.terminationStatus == 0 {
                fileItem.status = .completed
                
                var licenseProfileName = ""
                
                // Get the license profiler name from the database
                var db: OpaquePointer?
                if sqlite3_open(databasePath, &db) == SQLITE_OK {
                    let query = "SELECT folder_name FROM Folder_License_Map WHERE license_id = ? LIMIT 1"
                    var stmt: OpaquePointer?
                    
                    if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                        sqlite3_bind_text(stmt, 1, (licenseID as NSString).utf8String, -1, nil)
                        
                        if sqlite3_step(stmt) == SQLITE_ROW {
                            if let cString = sqlite3_column_text(stmt, 0) {
                                licenseProfileName = String(cString: cString)
                            }
                        }
                        sqlite3_finalize(stmt)
                    }
                    sqlite3_close(db)
                }
                
                // After encryption is successful, the record is added to the database
                // Insert the record only if the file does not exist in the database
                if !fileExistsInDB(filePath: fileItem.inputPath) {
                    insertFileProcessRecord(
                        fileName: fileItem.name,
                        filePath: fileItem.inputPath,
                        profileID: licenseID,
                        licenseProfile: licenseProfileName
                    )
                }

            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                fileItem.status = .failed
                fileItem.errorMessage = errorMessage

                print("Encryption failed: \(errorMessage)")
            }
        } catch {
            fileItem.status = .failed
            fileItem.errorMessage = error.localizedDescription
            
            print("Encryption failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: Get the license ID from the database
    private func getLicenseIDFromDB(folderPath: String) -> String {
        var db: OpaquePointer?
        var licenseID = ""
        
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            let query = "SELECT license_id FROM Folder_License_Map WHERE folder_path = ? LIMIT 1"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (folderPath as NSString).utf8String, -1, nil)
                
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(stmt, 0) {
                        licenseID = String(cString: cString)
                    }
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
        }
        
        return licenseID
    }

    // MARK: Create a database
    private func createLogDatabaseIfNeeded() {
        var db: OpaquePointer?
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            
            let createFolderTableQuery = """
                CREATE TABLE IF NOT EXISTS Folder_License_Map (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    folder_name TEXT,
                    folder_path TEXT,
                    license_id TEXT,
                    license_name TEXT,
                    product_id TEXT
                );
            """
            
            let createFileTableQuery = """
                CREATE TABLE IF NOT EXISTS File_Process_Details (
                    file_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_name TEXT NOT NULL,
                    file_path TEXT NOT NULL UNIQUE,
                    profile_id TEXT NOT NULL,
                    license_profile TEXT NOT NULL,
                    process_time TEXT NOT NULL
                );
            """
            
            // Create the Folder_License_Map table
            if sqlite3_exec(db, createFolderTableQuery, nil, nil, nil) != SQLITE_OK {
                print("❌ Failed to create folder license mapping table")
            } else {
                print("✅ Folder license mapping table is ready")
            }
            
            // Create the File_Process_Details table
            if sqlite3_exec(db, createFileTableQuery, nil, nil, nil) != SQLITE_OK {
                print("❌ Failed to create file processing record table")
            } else {
                print("✅ File processing record table is ready")
            }
            
            sqlite3_close(db)
        } else {
            print("❌ Unable to open database")
        }
    }
    
    // MARK: Check if the folder (license Profile) exists
    private func folderExistsInDB(path: String) -> Bool {
        var db: OpaquePointer?
        var exists = false
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            let query = "SELECT 1 FROM Folder_License_Map WHERE folder_path = ? LIMIT 1"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    exists = true
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
        }
        return exists
    }
    
    // MARK: Insert License Profile and folder records into the database
    private func insertFolderLicenseRecord(folderName: String, folderPath: String, licenseID: String, productID: String) {
        var db: OpaquePointer?
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            let insertQuery = "INSERT INTO Folder_License_Map (folder_name, folder_path, license_id, license_name, product_id) VALUES (?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertQuery, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (folderName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (folderPath as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (licenseID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (folderName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (productID as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_DONE {
                    print("✅ Insert record successfully")
                } else {
                    print("❌ Failed to insert record")
                }
                sqlite3_finalize(stmt)
            } else {
                print("❌ Preprocessing failed")
            }
            sqlite3_close(db)
        } else {
            print("❌ Unable to open database")
        }
    }
    
    // MARK: Check if the file already exists in the database
    private func fileExistsInDB(filePath: String) -> Bool {
        var db: OpaquePointer?
        var exists = false
        
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            let queryString = "SELECT COUNT(*) FROM File_Process_Details WHERE file_path = ?;"
            var queryStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(queryStatement, 1, (filePath as NSString).utf8String, -1, nil)
                
                if sqlite3_step(queryStatement) == SQLITE_ROW {
                    let count = sqlite3_column_int(queryStatement, 0)
                    exists = (count > 0)
                }
            }
            
            sqlite3_finalize(queryStatement)
            sqlite3_close(db)
        }
        
        return exists
    }
    
    // MARK: Insert file encryption records into the database
    private func insertFileProcessRecord(fileName: String, filePath: String, profileID: String, licenseProfile: String) {
        var db: OpaquePointer?
        
        if sqlite3_open(databasePath, &db) == SQLITE_OK {
            let insertString = """
            INSERT INTO File_Process_Details (file_name, file_path, profile_id, license_profile, process_time)
            VALUES (?, ?, ?, ?, datetime('now', 'localtime'));
            """
            
            var insertStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStatement, 1, (fileName as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 2, (filePath as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 3, (profileID as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 4, (licenseProfile as NSString).utf8String, -1, nil)
                
                if sqlite3_step(insertStatement) == SQLITE_DONE {
                    print("✅ File processing record added successfully: \(fileName)")
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    print("❌ Failed to add file processing record: \(fileName), Error: \(errorMessage)")
                }
            }
            
            sqlite3_finalize(insertStatement)
            sqlite3_close(db)
        }
    }

    // MARK: Check if file is stable (full copy done)
    private func isFileStable(url: URL) -> Bool {
        let path = url.path
        let now = Date()
        
        do {
            // Get the current file size and modification time
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let currentSize = Int64(resourceValues.fileSize ?? 0)
            _ = resourceValues.contentModificationDate ?? now
            
            // If the file size is 0, the file is considered unstable (being created or copied)
            if currentSize == 0 {
                return false
            }
            
            // Checks whether the file can be opened for reading (may fail if the file is being written)
            if let fileHandle = try? FileHandle(forReadingFrom: url) {
                // File can be opened for reading
                defer {
                    try? fileHandle.close()
                }
                
                // Check if the file is in our stability map
                if let previousCheck = fileStabilityMap[path] {
                    // A file is considered stable if its size has not changed for a period of time and its modification time has not been updated.
                    let sizeStable = previousCheck.size == currentSize
                    let timeElapsed = now.timeIntervalSince(previousCheck.timestamp) >= 2.0 // No change for at least 2 seconds
                    
                    if sizeStable && timeElapsed {
                        // File is stable, removed from mapping
                        fileStabilityMap.removeValue(forKey: path)
                        return true
                    } else {
                        // The file is still changing, update the check information
                        fileStabilityMap[path] = (currentSize, now)
                        return false
                    }
                } else {
                    // This file is checked for the first time and added to the mapping
                    fileStabilityMap[path] = (currentSize, now)
                    return false
                }
            } else {
                // The file could not be opened for reading, it may be being written to
                return false
            }
        } catch {
            print("Checking file stability failed: \(error)")
            return false
        }
    }

    // MARK: Set the status color
    private func statusColor(for status: FileStatus) -> Color {
        switch status {
        case .pending: return .primary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    // MARK: Open the folder and select the file
    private func openFolder(url: URL?) {
        guard let url = url else { return }
        
        // Get file and folder paths
        let filePath = url.path
        let folderPath = url.deletingLastPathComponent().path
        
        // Use the selectFile method of NSWorkspace to open the folder and select the file
        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: folderPath)
    }
    
    // MARK: Open File
    private func openFile(url: URL?) {
        guard let url = url else { return }
        NSWorkspace.shared.open(url)
    }
}
