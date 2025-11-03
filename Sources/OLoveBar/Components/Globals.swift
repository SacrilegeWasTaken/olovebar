import AppKit

struct Globals {
    private static let cachedValues: (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat, notchHeight: CGFloat, screenHeight: CGFloat) = {
        guard let screen = NSScreen.main else {
            let width = NSScreen.main?.frame.width ?? 0
            let height = NSScreen.main?.frame.height ?? 0
            return (0, width, 0, width, 0, height)
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
            print("screenWidth: \(screenWidth), notchWidth: \(notchWidth), notchStart: \(notchStart), notchEnd: \(notchEnd), notchHeight: \(notchHeight)")

            return (notchWidth, screenWidth, notchStart, notchEnd, notchHeight, screenHeight)
        } else {
            let screenWidth = screen.frame.width
            let screenHeight = screen.frame.height
            return (0, screenWidth, 0, screenWidth, 0, screenHeight)
        }
    }()

    static var notchWidth: CGFloat { cachedValues.notchWidth }
    static var screenWidth: CGFloat { cachedValues.screenWidth }
    static var notchStart: CGFloat { cachedValues.notchStart }
    static var notchEnd: CGFloat { cachedValues.notchEnd }
    static var notchHeight: CGFloat { cachedValues.notchHeight }
    static var screenHeight: CGFloat { cachedValues.screenHeight }
}
