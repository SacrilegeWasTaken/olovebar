import AppKit

struct Globals {
    static func computeValues() -> (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat) {
        guard let screen = NSScreen.main else {
            let width = NSScreen.main?.frame.width ?? 0
            return (0, width, 0, width)
        }
        
        if let topLeft = screen.auxiliaryTopLeftArea, let topRight = screen.auxiliaryTopRightArea {
            let screenWidth = screen.frame.width
            let leftWidth = topLeft.width
            let rightWidth = topRight.width
            let notchWidth = screenWidth - leftWidth - rightWidth
            let notchStart = leftWidth
            let notchEnd = notchStart + notchWidth
            
            print("screenWidth: \(screenWidth), notchWidth: \(notchWidth), notchStart: \(notchStart), notchEnd: \(notchEnd)")

            return (notchWidth, screenWidth, notchStart, notchEnd)
        } else {
            let screenWidth = screen.frame.width
            return (0, screenWidth, 0, screenWidth)
        }
    }

    static var values: (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat) {
        computeValues()
    }

    static var notchWidth: CGFloat { values.notchWidth }
    static var screenWidth: CGFloat { values.screenWidth }
    static var notchStart: CGFloat { values.notchStart }
    static var notchEnd: CGFloat { values.notchEnd }
}
