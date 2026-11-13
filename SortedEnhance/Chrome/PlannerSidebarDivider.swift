import AppKit
import SwiftUI

struct PlannerSidebarDivider: NSViewRepresentable {
    var width: CGFloat
    var range: ClosedRange<CGFloat>
    var availableWidth: CGFloat
    var onResize: (CGFloat) -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    func makeNSView(context: Context) -> DividerView {
        let view = DividerView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.splitter)
        view.setAccessibilityOrientation(.vertical)
        view.setAccessibilityLabel(String(localized: "Sidebar width"))
        view.setAccessibilityIdentifier("PlannerSidebarDivider")
        view.focusRingType = .default
        return view
    }

    func updateNSView(_ view: DividerView, context: Context) {
        view.range = range
        view.availableWidth = availableWidth
        view.width = width
        view.direction = layoutDirection == .rightToLeft ? -1 : 1
        view.onResize = onResize
    }

    final class DividerView: NSView {
        var width: CGFloat = 300 {
            didSet {
                if width != oldValue {
                    NSAccessibility.post(element: self, notification: .valueChanged)
                }
            }
        }
        var range: ClosedRange<CGFloat> = 200...500
        var availableWidth: CGFloat = 1024
        var direction: CGFloat = 1
        var onResize: ((CGFloat) -> Void)?
        private var dragOrigin: (x: CGFloat, width: CGFloat)?

        override var acceptsFirstResponder: Bool { true }
        override var focusRingMaskBounds: NSRect { bounds }
        override func drawFocusRingMask() { bounds.fill() }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            dragOrigin = (event.locationInWindow.x, width)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let dragOrigin else { return }
            resize(to: dragOrigin.width + direction * (event.locationInWindow.x - dragOrigin.x))
        }

        override func mouseUp(with event: NSEvent) { dragOrigin = nil }

        override func keyDown(with event: NSEvent) {
            switch event.specialKey {
            case .leftArrow: resize(to: width - direction * 10)
            case .rightArrow: resize(to: width + direction * 10)
            default: super.keyDown(with: event)
            }
        }

        override func accessibilityValue() -> Any? { percentage(of: width) }
        override func accessibilityMinValue() -> Any? { percentage(of: range.lowerBound) }
        override func accessibilityMaxValue() -> Any? { percentage(of: range.upperBound) }
        override func accessibilityValueDescription() -> String? {
            Double(width / max(1, availableWidth)).formatted(.percent.precision(.fractionLength(0...1)))
        }

        override func isAccessibilitySelectorAllowed(_ selector: Selector) -> Bool {
            selector == #selector(setAccessibilityValue(_:)) || super.isAccessibilitySelectorAllowed(selector)
        }

        private func percentage(of width: CGFloat) -> NSNumber {
            NSNumber(value: 100 * width / max(1, availableWidth))
        }

        override func setAccessibilityValue(_ value: Any?) {
            guard let number = value as? NSNumber else { return }
            resize(to: number.doubleValue * availableWidth / 100)
        }

        override func accessibilityPerformIncrement() -> Bool { resize(to: width + 10) }
        override func accessibilityPerformDecrement() -> Bool { resize(to: width - 10) }

        @discardableResult
        private func resize(to value: CGFloat) -> Bool {
            guard value.isFinite else { return false }
            let constrained = min(range.upperBound, max(range.lowerBound, value))
            guard constrained != width else { return false }
            width = constrained
            onResize?(constrained)
            return true
        }
    }
}
