import SwiftUI

struct ManualEncryptionView: View {
    let user: User?
    
    @State private var inputDirectory: URL?
    @State private var outputDirectory: URL?
    @State private var selectedLicenseProfile: LicenseProfile? = nil
    @State private var createFolders: Bool = true
    @State private var files: [FileItem] = []
    @State private var isProcessing: Bool = false
    @State private var shouldCancel: Bool = false
    @State private var showingInputDirectoryPicker = false
    @State private var showingOutputDirectoryPicker = false
    @State private var licenseProfiles: [LicenseProfile] = []
    @State private var isLoadingLicenseProfiles = false
    @State private var selectedFileID: UUID? = nil
    
    @State private var windowDelegate: WindowDelegate? = nil
    
    @State private var inputDirectoryScopedAccess: Bool = false
    @State private var outputDirectoryScopedAccess: Bool = false
    
    struct LicenseProfile: Identifiable, Hashable {
        let id: String
        let name: String
    }
    
    private var serviceURL: String {
        user?.isChineseVersion ?? false ? "https://4.drm-x.cn/haihaisoftlicenseservice.asmx" : "https://4.drm-x.com/haihaisoftlicenseservice.asmx"
    }
    
    private var soapAction: String {
        user?.isChineseVersion ?? false ? "https://4.drm-x.cn/haihaisoftlicenseservice.asmx?op=ListLicenseProfilesAsString" : "https://4.drm-x.com/haihaisoftlicenseservice.asmx?op=ListLicenseProfilesAsString"
    }
    
    // MARK: - Interface layout entry-View Body
    var body: some View {
        let isChinese = user?.isChineseVersion ?? false
        VStack(spacing: 16) {
            //MARK: Input Directory Selection
            HStack {
                Text(localized("input_directory", isChinese: isChinese))
                    .frame(width: 110, alignment: .leading)
                
                TextField(localized("select_input_directory", isChinese: isChinese), text: Binding(
                    get: { inputDirectory?.path ?? "" },
                    set: { _ in }
                ))
                .disabled(true)
                
                Button(localized("browse", isChinese: isChinese)) {
                    showingInputDirectoryPicker = true
                }
                .fileImporter(
                    isPresented: $showingInputDirectoryPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            inputDirectory?.stopAccessingSecurityScopedResource()
                            inputDirectory = url
                            inputDirectoryScopedAccess = url.startAccessingSecurityScopedResource()
                            loadFiles()
                        }
                    case .failure(let error):
                        print("Failed to select directory: \(error.localizedDescription)")
                    }
                }
            }
            
            //MARK: Output directory selection
            HStack {
                Text(localized("output_directory", isChinese: isChinese))
                    .frame(width: 110, alignment: .leading)
                
                TextField(localized("select_output_directory", isChinese: isChinese), text: Binding(
                    get: { outputDirectory?.path ?? "" },
                    set: { _ in }
                ))
                .disabled(true)
                
                Button(localized("browse", isChinese: isChinese)) {
                    showingOutputDirectoryPicker = true
                }
                .fileImporter(
                    isPresented: $showingOutputDirectoryPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            outputDirectory?.stopAccessingSecurityScopedResource()
                            outputDirectory = url
                            outputDirectoryScopedAccess = url.startAccessingSecurityScopedResource()
                        }
                    case .failure(let error):
                        print("Failed to select directory: \(error.localizedDescription)")
                    }
                }
            }
            
            //MARK: License Profile Selection
            HStack {
                Text(localized("license_profile", isChinese: isChinese))
                    .frame(width: 110, alignment: .leading)
                
                if isLoadingLicenseProfiles {
                    ProgressView()
                } else {
                    Picker("", selection: $selectedLicenseProfile) {
                        ForEach(licenseProfiles, id: \.self) { licenseProfile in
                            Text("\(licenseProfile.id) || \(licenseProfile.name)").tag(licenseProfile as LicenseProfile?)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Toggle(localized("create_folder_toggle", isChinese: isChinese), isOn: $createFolders)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            //MARK: File List
            List(selection: $selectedFileID) {
                // Header Row
                HStack {
                    Text(localized("file_name", isChinese: isChinese)).font(.headline).frame(width: 200, alignment: .leading)
                    Text(localized("input_path", isChinese: isChinese)).font(.headline).frame(width: 180, alignment: .leading)
                    Text(localized("output_path", isChinese: isChinese)).font(.headline).frame(width: 180, alignment: .leading)
                    Text(localized("file_size", isChinese: isChinese)).font(.headline).frame(width: 80, alignment: .leading)
                    Text(localized("status", isChinese: isChinese)).font(.headline).frame(width: 140, alignment: .leading)
                }
                .padding(.vertical, 4)
                
                //MARK: File data row
                ForEach(files) { file in
                    HStack {
                        Text(file.name)
                            .frame(width: 200, alignment: .leading)
                            .lineLimit(1)
                            .help(file.name)
                        
                        Text(file.inputPath)
                            .frame(width: 180, alignment: .leading)
                            .lineLimit(1)
                            .help(file.inputPath)
                        
                        Text(file.outputPath.isEmpty ? localized("auto_generated", isChinese: isChinese) : file.outputPath)
                            .frame(width: 180, alignment: .leading)
                            .foregroundColor(file.outputPath.isEmpty ? .gray : .primary)
                            .lineLimit(1)
                            .help(file.outputPath.isEmpty ? localized("tooltip_auto_generate", isChinese: isChinese) : file.outputPath)
                        
                        Text(file.formattedSize)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(file.status.localizedString(isChinese: user?.isChineseVersion ?? false))
                            .frame(width: 140, alignment: .leading)
                            .foregroundColor(statusColor(for: file.status))
                    }
                    .padding(.vertical, 2)
                    .tag(file.id)
                    .contentShape(Rectangle()) // Make the entire row clickable
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
                        Button(localized("refresh", isChinese: isChinese)) {
                            selectedFileID = file.id // Select when right clicking
                            loadFiles()
                        }
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
            .padding(.horizontal, 0)
            .padding(.top, 0)
            
            //MARK: Start-Cancel button
            HStack {
                Button(action: startEncryption) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text(localized("start_encryption", isChinese: isChinese))
                            .frame(width: 100, height: 30)
                    }
                }
                .disabled(isProcessing || files.isEmpty || selectedLicenseProfile == nil)
                .buttonStyle(.borderedProminent)
                
                Button(action: cancelEncryption) {
                    Text(localized("cancel_encryption", isChinese: isChinese))
                        .frame(width: 100, height: 30)
                }
                .disabled(!isProcessing)
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding()
        .onAppear {
        loadLicenseProfiles()
        // Setting the window proxy
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                let isChinese = user?.isChineseVersion ?? false
                self.windowDelegate = WindowDelegate(
                    isProcessing: isProcessing, 
                    isChinese: isChinese,
                    taskType: .manualEncryption,
                    onWindowClose: {
                        // Set the cancel flag
                        self.shouldCancel = true
                        
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
                
                // Listen for isProcessing status changes
                NotificationCenter.default.addObserver(forName: NSNotification.Name("ProcessingStatusChanged"), object: nil, queue: .main) { notification in
                    if let isProcessing = notification.userInfo?["isProcessing"] as? Bool {
                        self.windowDelegate = WindowDelegate(
                            isProcessing: isProcessing, 
                            isChinese: isChinese,
                            taskType: .manualEncryption,
                            onWindowClose: {
                                // Set the cancel flag
                                self.shouldCancel = true
                                
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
        .onDisappear {
            if inputDirectoryScopedAccess {
                inputDirectory?.stopAccessingSecurityScopedResource()
            }
            if outputDirectoryScopedAccess {
                outputDirectory?.stopAccessingSecurityScopedResource()
            }
        }
    }
    // Send a notification when isProcessing changes
    private func updateProcessingStatus() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ProcessingStatusChanged"),
            object: nil,
            userInfo: ["isProcessing": isProcessing]
        )
    }

    // MARK: Loading a License Profile
    private func loadLicenseProfiles() {
        isLoadingLicenseProfiles = true
        let client = SOAPClient()
        client.listLicenseProfiles(
            endpoint: serviceURL,
            soapAction: soapAction,
            adminemail: user?.adminemail ?? "",
            authStr: user?.webServiceCode ?? ""
        ) { result in
            DispatchQueue.main.async {
                isLoadingLicenseProfiles = false
                if let result = result {
                    // Parse the licenseProfile string
                    let licenseProfileList = result.components(separatedBy: ";;")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    // Parse each licenseProfile string into an ID and a name
                    self.licenseProfiles = licenseProfileList.compactMap { profileStr -> LicenseProfile? in
                        let parts = profileStr.components(separatedBy: "||")
                        if parts.count >= 2 {
                            return LicenseProfile(id: parts[0], name: parts[1])
                        }
                        return nil
                    }
                    
                    // If you have license Profile, the first one is selected by default
                    if !self.licenseProfiles.isEmpty {
                        self.selectedLicenseProfile = self.licenseProfiles[0]
                        //print("Selected licenseProfile: ID=\(self.selectedRight!.id), Name=\(self.selectedRight!.name)")
                    }
                } else {
                    print("Failed to obtain License Profile")
                }
            }
        }
    }

    // MARK: Loading Files
    private func loadFiles() {
        guard let inputDir = inputDirectory else { return }
        
        let securityScoped = inputDir.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                inputDir.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        var allFiles: [FileItem] = []
        
        func scanDirectory(_ dir: URL) {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
                
                for url in fileURLs {
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    
                    if isDirectory.boolValue {
                        scanDirectory(url)
                    } else {
                        guard ["mp3", "mp4", "pdf"].contains(url.pathExtension.lowercased()) else { continue }
                        
                        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        
                        let fileItem = FileItem(
                            name: url.lastPathComponent,
                            inputPath: url.path,
                            outputPath: "",
                            inputURL: url,
                            outputURL: nil,
                            size: Int64(size)
                        )
                        allFiles.append(fileItem)
                    }
                }
            } catch {
                print("Scanning directory failed: \(error)")
            }
        }
        
        scanDirectory(inputDir)
        files = allFiles
    }


    // MARK: Start Encryption
    private func startEncryption() {
        isProcessing = true
        updateProcessingStatus()

        guard let inputDir = inputDirectory,
              let outputDir = outputDirectory,
              !files.isEmpty  else { return }
        
        shouldCancel = false
        isProcessing = true
        
        let licenseID = selectedLicenseProfile?.id ?? ""
        let domain = user?.isChineseVersion ?? false ? "CN" : "COM"
        let adminEmail = user?.adminemail ?? ""
        let authStr = user?.webServiceCode ?? ""
        
        let securityScoped = outputDir.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                outputDir.stopAccessingSecurityScopedResource()
            }
        }
        
        var targetOutputDir = outputDir
        
        if createFolders {
            let folderName = inputDir.lastPathComponent
            let targetFolderName = "\(licenseID)_\(folderName)"
            targetOutputDir = outputDir.appendingPathComponent(targetFolderName)
            
            if !FileManager.default.fileExists(atPath: targetOutputDir.path) {
                do {
                    try FileManager.default.createDirectory(at: targetOutputDir, withIntermediateDirectories: true)
                } catch {
                    print("❌ Failed to create output subfolder: \(error.localizedDescription)")
                    isProcessing = false
                    return
                }
            }
        }
        
        // Concurrent execution of encryption tasks
        DispatchQueue.global(qos: .userInitiated).async {
            for i in files.indices {
                // Check whether to cancel
                if shouldCancel {
                    DispatchQueue.main.async {
                        files[i].status = .pending
                        isProcessing = false
                    }
                    break
                }
                
                DispatchQueue.main.async {
                    files[i].status = .processing
                }

                let file = files[i]
                let inputURL = URL(fileURLWithPath: file.inputPath)
                
                // Calculate input relative path (to preserve directory structure)
                let relativePath = inputURL.path.replacingOccurrences(of: inputDir.path, with: "")
                let relativeURL = URL(fileURLWithPath: relativePath)
                let relativeDir = relativeURL.deletingLastPathComponent().path
                let outputFolder = targetOutputDir.appendingPathComponent(relativeDir)
    
                // Create output subdirectory
                do {
                    try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
                } catch {
                    DispatchQueue.main.async {
                        files[i].status = .failed
                        files[i].errorMessage = "Failed to create directory: \(error.localizedDescription)"
                        if i == files.count - 1 {
                            isProcessing = false
                        }
                    }
                    continue
                }
                
                // Construct output file name (add _P suffix)
                let fileName = inputURL.deletingPathExtension().lastPathComponent + "_P"
                let fileExtension = inputURL.pathExtension
                let outputFileName = fileName + "." + fileExtension
                let outputPath = outputFolder.appendingPathComponent(outputFileName).path

                guard let mp4encryptPath = Bundle.main.resourceURL?.appendingPathComponent("mp4encrypt").path else {
                    DispatchQueue.main.async {
                        files[i].status = .failed
                        files[i].errorMessage = "Unable to find mp4encrypt executable"
                        if i == files.count - 1 {
                            isProcessing = false
                        }
                    }
                    return
                }
                // Setting encryption parameters
                let command = [
                    mp4encryptPath,
                    "-ServerDomain", domain,        // CN or COM
                    "-AdminEmail", adminEmail,      // DRM-X 4.0 Login Account
                    "-WebServiceAuthStr", authStr,  // DRM-X 4.0 Web Service Auth String
                    "-ID", licenseID,               // License Profile ID
                    "-Input", file.inputPath,       // Input File path
                    "-Output", outputPath           // Output File path
                ]

                let process = Process()
                process.executableURL = URL(fileURLWithPath: command[0])
                process.arguments = Array(command.dropFirst())

                let pipe = Pipe()
                process.standardError = pipe
                process.standardOutput = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            files[i].outputPath = outputPath
                            files[i].status = .completed
                        } else {
                            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                            let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown error"
                            files[i].status = .failed
                            files[i].errorMessage = errorMessage
                            print("Encryption failed: \(errorMessage)")
                        }

                        // Check if it is the last file or if it has been cancelled
                        if i == files.count - 1 || shouldCancel {
                            isProcessing = false
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        files[i].status = .failed
                        files[i].errorMessage = error.localizedDescription
                        print("Encryption failed: \(error.localizedDescription)")
                        
                        // Check if it is the last file or if it has been cancelled
                        if i == files.count - 1 || shouldCancel {
                            isProcessing = false
                        }
                    }
                }
            }
        }
    }

    // MARK: Cancel encryption
    private func cancelEncryption() {
        let isChinese = user?.isChineseVersion ?? false
        
        // Creating a Confirmation Dialog Box
        let alert = NSAlert()
        alert.messageText = localized("cancel_confirmation_title", isChinese: isChinese)
        alert.informativeText = localized("cancel_confirmation_message", isChinese: isChinese)
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("confirm", isChinese: isChinese))
        alert.addButton(withTitle: localized("cancel", isChinese: isChinese))
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // The user clicks the Confirm button
            shouldCancel = true
            
            // Reset the status of all files being processed to pending
            files = files.map { file in
                var updatedFile = file
                if updatedFile.status == .processing {
                    updatedFile.status = .pending
                }
                return updatedFile
            }
            
            // Display canceled reminder message
            let notification = NSAlert()
            notification.messageText = localized("cancel_success_title", isChinese: isChinese)
            notification.informativeText = localized("cancel_success_message", isChinese: isChinese)
            notification.alertStyle = .informational
            notification.addButton(withTitle: localized("ok", isChinese: isChinese))
            notification.runModal()
        }
        isProcessing = false
        updateProcessingStatus()
    }
    
    // MARK: Set various status colors
    private func statusColor(for status: FileStatus) -> Color {
        switch status {
        case .pending: return .primary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    // MARK: Open File
    private func openFile(url: URL?) {
        guard let url = url else { return }
        NSWorkspace.shared.open(url)
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
}
