import Foundation

enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["NOTCHTERMINAL_UI_TEST"] == "1"
    }
}
