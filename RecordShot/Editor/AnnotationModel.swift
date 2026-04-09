import SwiftUI
import AppKit

enum AnnotationTool: CaseIterable, Identifiable {
    case rectangle, circle, arrow, text, blur

    var id: Self { self }

    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .circle:    return "circle"
        case .arrow:     return "arrow.up.right"
        case .text:      return "textformat"
        case .blur:      return "eye.slash"
        }
    }

    var label: String {
        switch self {
        case .rectangle: return NSLocalizedString("tool.rectangle", comment: "")
        case .circle:    return NSLocalizedString("tool.circle", comment: "")
        case .arrow:     return NSLocalizedString("tool.arrow", comment: "")
        case .text:      return NSLocalizedString("tool.text", comment: "")
        case .blur:      return NSLocalizedString("tool.blur", comment: "")
        }
    }
}

struct Annotation: Identifiable {
    var id = UUID()
    var tool: AnnotationTool
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    var text: String = NSLocalizedString("annotation.defaultText", comment: "")
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 3
    var fontSize: CGFloat = 18

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }

    var isValid: Bool {
        switch tool {
        case .text:
            return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .rectangle, .circle, .blur:
            return rect.width > 5 && rect.height > 5
        case .arrow:
            let dx = endPoint.x - startPoint.x
            let dy = endPoint.y - startPoint.y
            return sqrt(dx * dx + dy * dy) > 10
        }
    }
}
