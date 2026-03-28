import XCTest
import ServiceManagement
@testable import NotchTerminal

@MainActor
final class LaunchAtLoginManagerTests: XCTestCase {
    func testEnabledStatusMapsToEnabledState() {
        let controller = MockLaunchAtLoginController(status: .enabled)
        let manager = LaunchAtLoginManager(controller: controller)

        XCTAssertTrue(manager.isEnabled)
        XCTAssertFalse(manager.requiresApproval)
        XCTAssertNil(manager.errorMessage)
    }

    func testRequiresApprovalStillShowsEnabledState() {
        let controller = MockLaunchAtLoginController(status: .requiresApproval)
        let manager = LaunchAtLoginManager(controller: controller)

        XCTAssertTrue(manager.isEnabled)
        XCTAssertTrue(manager.requiresApproval)
    }

    func testSetEnabledRegistersServiceAndClearsApprovalWhenEnabled() {
        let controller = MockLaunchAtLoginController(status: .notRegistered)
        let manager = LaunchAtLoginManager(controller: controller)

        manager.setEnabled(true)

        XCTAssertEqual(controller.registerCallCount, 1)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertFalse(manager.requiresApproval)
        XCTAssertNil(manager.errorMessage)
    }

    func testSetEnabledCapturesRegisterErrorsAndLeavesStateUnchanged() {
        let controller = MockLaunchAtLoginController(
            status: .notRegistered,
            registerError: MockLaunchAtLoginError.registrationFailed
        )
        let manager = LaunchAtLoginManager(controller: controller)

        manager.setEnabled(true)

        XCTAssertEqual(controller.registerCallCount, 1)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.requiresApproval)
        XCTAssertEqual(manager.errorMessage, MockLaunchAtLoginError.registrationFailed.localizedDescription)
    }

    func testSetDisabledUnregistersService() {
        let controller = MockLaunchAtLoginController(status: .enabled)
        let manager = LaunchAtLoginManager(controller: controller)

        manager.setEnabled(false)

        XCTAssertEqual(controller.unregisterCallCount, 1)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.requiresApproval)
        XCTAssertNil(manager.errorMessage)
    }
}

@MainActor
private final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(
        status: SMAppService.Status,
        registerError: Error? = nil,
        unregisterError: Error? = nil
    ) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }
}

private enum MockLaunchAtLoginError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Registration failed"
        }
    }
}
