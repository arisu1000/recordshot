import XCTest
@testable import RecordShot

final class AnnotationModelTests: XCTestCase {

    // MARK: - Annotation.rect

    func test_rect_normalDrag() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 10, y: 20)
        ann.endPoint   = CGPoint(x: 110, y: 70)
        XCTAssertEqual(ann.rect, CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    func test_rect_reverseDrag() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 110, y: 70)
        ann.endPoint   = CGPoint(x: 10, y: 20)
        XCTAssertEqual(ann.rect, CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    func test_rect_zeroSize() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 50, y: 50)
        ann.endPoint   = CGPoint(x: 50, y: 50)
        XCTAssertEqual(ann.rect.width, 0)
        XCTAssertEqual(ann.rect.height, 0)
    }

    func test_rect_originIsAlwaysMinXY() {
        var ann = Annotation(tool: .circle)
        ann.startPoint = CGPoint(x: 100, y: 200)
        ann.endPoint   = CGPoint(x: 50, y: 80)
        XCTAssertEqual(ann.rect.origin.x, 50)
        XCTAssertEqual(ann.rect.origin.y, 80)
        XCTAssertEqual(ann.rect.width, 50)
        XCTAssertEqual(ann.rect.height, 120)
    }

    // MARK: - isValid: rectangle / circle / blur

    func test_isValid_rectangle_sufficientSize() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 10, y: 10)
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_rectangle_tooSmall() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 3, y: 3)
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_rectangle_exactBoundary() {
        // width=5, height=5 — not strictly greater than 5 → invalid
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 5, y: 5)
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_rectangle_justAboveBoundary() {
        var ann = Annotation(tool: .rectangle)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 6, y: 6)
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_circle_sufficientSize() {
        var ann = Annotation(tool: .circle)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 20, y: 15)
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_blur_sufficientSize() {
        var ann = Annotation(tool: .blur)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 20, y: 20)
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_blur_tooSmall() {
        var ann = Annotation(tool: .blur)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 4, y: 4)
        XCTAssertFalse(ann.isValid)
    }

    // MARK: - isValid: arrow

    func test_isValid_arrow_longEnough() {
        var ann = Annotation(tool: .arrow)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 15, y: 0)
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_arrow_tooShort() {
        var ann = Annotation(tool: .arrow)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 5, y: 0)
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_arrow_exactBoundary() {
        // length == 10, isValid requires > 10 (strict) → false
        var ann = Annotation(tool: .arrow)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 6, y: 8)  // length = sqrt(36+64) = 10
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_arrow_diagonal_short() {
        // 3-4-5 triangle: length = 5 → invalid
        var ann = Annotation(tool: .arrow)
        ann.startPoint = CGPoint(x: 0, y: 0)
        ann.endPoint   = CGPoint(x: 3, y: 4)
        XCTAssertFalse(ann.isValid)
    }

    // MARK: - isValid: text

    func test_isValid_text_nonEmpty() {
        var ann = Annotation(tool: .text)
        ann.text = "Hello"
        XCTAssertTrue(ann.isValid)
    }

    func test_isValid_text_empty() {
        var ann = Annotation(tool: .text)
        ann.text = ""
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_text_whitespaceOnly() {
        var ann = Annotation(tool: .text)
        ann.text = "   "
        XCTAssertFalse(ann.isValid)
    }

    func test_isValid_text_multiline() {
        var ann = Annotation(tool: .text)
        ann.text = "line1\nline2"
        XCTAssertTrue(ann.isValid)
    }

    // MARK: - AnnotationTool

    func test_allCasesCount() {
        XCTAssertEqual(AnnotationTool.allCases.count, 5)
    }

    func test_toolIcons_notEmpty() {
        for tool in AnnotationTool.allCases {
            XCTAssertFalse(tool.icon.isEmpty, "\(tool) icon should not be empty")
        }
    }

    func test_toolLabels_notEmpty() {
        for tool in AnnotationTool.allCases {
            XCTAssertFalse(tool.label.isEmpty, "\(tool) label should not be empty")
        }
    }

    func test_toolIdentifiable() {
        for tool in AnnotationTool.allCases {
            XCTAssertEqual(tool.id, tool)
        }
    }

    // MARK: - Annotation defaults

    func test_annotation_defaultLineWidth() {
        let ann = Annotation(tool: .rectangle)
        XCTAssertEqual(ann.lineWidth, 3)
    }

    func test_annotation_defaultFontSize() {
        let ann = Annotation(tool: .text)
        XCTAssertEqual(ann.fontSize, 18)
    }

    func test_annotation_defaultPoints_areZero() {
        let ann = Annotation(tool: .circle)
        XCTAssertEqual(ann.startPoint, .zero)
        XCTAssertEqual(ann.endPoint, .zero)
    }

    func test_annotation_uniqueIds() {
        let ann1 = Annotation(tool: .rectangle)
        let ann2 = Annotation(tool: .rectangle)
        XCTAssertNotEqual(ann1.id, ann2.id)
    }
}
