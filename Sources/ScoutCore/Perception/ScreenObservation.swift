import Foundation

/// Snapshot completo do estado percebido num passo: a11y (barato em tokens) +
/// screenshot (pro modelo de visão quando a árvore não basta).
public struct ScreenObservation: Sendable, Codable {
    public var screenshotPNG: Data
    public var accessibility: AccessibilitySnapshot
    public var screenSize: Size

    public struct Size: Sendable, Codable, Equatable {
        public var width: Double
        public var height: Double
        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public init(screenshotPNG: Data, accessibility: AccessibilitySnapshot, screenSize: Size) {
        self.screenshotPNG = screenshotPNG
        self.accessibility = accessibility
        self.screenSize = screenSize
    }
}
