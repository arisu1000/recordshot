import AppKit

struct ClipboardManager {
    static func copyImage(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // tiffRepresentation 경유로 안전하게 복사 (writeObjects가 유효하지 않은 rep에서 크래시 가능)
        if let tiff = image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    static func copyString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
