import AppKit

struct Globals {
    private static func computeValues() -> (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat, notchHeight: CGFloat, screenHeight: CGFloat) {
        guard let screen = NSScreen.main else {
            // No main screen (e.g. headless); use fallback to avoid zero/negative layout.
            let fallbackWidth: CGFloat = 1920
            let fallbackHeight: CGFloat = 1080
            return (0, fallbackWidth, 0, fallbackWidth, 0, fallbackHeight)
        }

        if let topLeft = screen.auxiliaryTopLeftArea, let topRight = screen.auxiliaryTopRightArea {
            let screenWidth = screen.frame.width
            let screenHeight = screen.frame.height
            let leftWidth = topLeft.width
            let rightWidth = topRight.width
            let notchWidth = screenWidth - leftWidth - rightWidth
            let notchStart = leftWidth
            let notchEnd = notchStart + notchWidth
            let notchHeight = topLeft.height
            return (notchWidth, screenWidth, notchStart, notchEnd, notchHeight, screenHeight)
        } else {
            let screenWidth = screen.frame.width
            let screenHeight = screen.frame.height
            return (0, screenWidth, 0, screenWidth, 0, screenHeight)
        }
    }

    static var notchWidth: CGFloat { computeValues().notchWidth }
    static var screenWidth: CGFloat { computeValues().screenWidth }
    static var notchStart: CGFloat { computeValues().notchStart }
    static var notchEnd: CGFloat { computeValues().notchEnd }
    static var notchHeight: CGFloat { computeValues().notchHeight }
    static var screenHeight: CGFloat { computeValues().screenHeight }
}
