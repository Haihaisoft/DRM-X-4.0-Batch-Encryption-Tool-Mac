import AppKit

// Define task type enumeration
enum TaskType {
    case manualEncryption
    case autoScanning
}

class WindowDelegate: NSObject, NSWindowDelegate {
    var isProcessing: Bool
    var isChinese: Bool
    var taskType: TaskType
    var onWindowClose: (() -> Void)?
    
    init(isProcessing: Bool, isChinese: Bool, taskType: TaskType, onWindowClose: (() -> Void)? = nil) {
        self.isProcessing = isProcessing
        self.isChinese = isChinese
        self.taskType = taskType
        self.onWindowClose = onWindowClose
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If there is no task being processed, close it directly
        if !isProcessing {
            // Calling the close callback
            onWindowClose?()
            return true
        }
        
        // Creating a Confirmation Dialog Box
        let alert = NSAlert()
        alert.messageText = localized("close_window_title", isChinese: isChinese)
        
        // Display different prompts according to the task type
        switch taskType {
        case .manualEncryption:
            alert.informativeText = localized("close_window_message", isChinese: isChinese)
        case .autoScanning:
            alert.informativeText = localized("close_window_message", isChinese: isChinese)
        }
        
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("confirm", isChinese: isChinese))
        alert.addButton(withTitle: localized("cancel", isChinese: isChinese))
        
        let response = alert.runModal()
        
        // If the user confirms closing, call the close callback and return true; otherwise return false
        if response == .alertFirstButtonReturn {
            onWindowClose?()
            return true
        }
        return false
    }
}
