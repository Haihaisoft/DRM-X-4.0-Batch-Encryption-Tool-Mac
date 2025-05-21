import Foundation

enum FileStatus: String {
    case pending
    case processing
    case completed
    case failed

    func localizedString(isChinese: Bool) -> String {
        switch self {
        case .pending:
            return localized("STATUS_PENDING", isChinese: isChinese)
        case .processing:
            return localized("STATUS_PROCESSING", isChinese: isChinese)
        case .completed:
            return localized("STATUS_COMPLETED", isChinese: isChinese)
        case .failed:
            return localized("STATUS_FAILED", isChinese: isChinese)
        }
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let inputPath: String
    var outputPath: String
    var inputURL: URL?
    var outputURL: URL? 
    let size: Int64
    var status: FileStatus = .pending
    var errorMessage: String = ""    // 添加错误信息属性
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
