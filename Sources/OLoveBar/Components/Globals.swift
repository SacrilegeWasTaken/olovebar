import AppKit

struct Globals {
    static func computeValues() -> (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat, notchHeight: CGFloat) {
        guard let screen = NSScreen.main else {
            let width = NSScreen.main?.frame.width ?? 0
            return (0, width, 0, width, 0)
        }
        
        if let topLeft = screen.auxiliaryTopLeftArea, let topRight = screen.auxiliaryTopRightArea {
            let screenWidth = screen.frame.width
            let leftWidth = topLeft.width
            let rightWidth = topRight.width
            let notchWidth = screenWidth - leftWidth - rightWidth
            let notchStart = leftWidth
            let notchEnd = notchStart + notchWidth
            let notchHeight = topLeft.height
            print("screenWidth: \(screenWidth), notchWidth: \(notchWidth), notchStart: \(notchStart), notchEnd: \(notchEnd), notchHeight: \(notchHeight)")

            return (notchWidth, screenWidth, notchStart, notchEnd, notchHeight)
        } else {
            let screenWidth = screen.frame.width
            return (0, screenWidth, 0, screenWidth, 0)
        }
    }

    static var values: (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat, notchHeight: CGFloat) {
        computeValues()
    }

    static var notchWidth: CGFloat { values.notchWidth }
    static var screenWidth: CGFloat { values.screenWidth }
    static var notchStart: CGFloat { values.notchStart }
    static var notchEnd: CGFloat { values.notchEnd }
    static var notchHeight: CGFloat { values.notchHeight }
}
