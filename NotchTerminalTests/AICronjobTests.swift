import XCTest
@testable import NotchTerminal

final class AICronjobTests: XCTestCase {
    func testHasExpiredReturnsFalseWhenAutoDisableIsOff() {
        var job = AICronjob()
        job.autoDisable = false
        job.activationDate = Date().addingTimeInterval(-(60 * 60 * 24 * 10)).timeIntervalSince1970

        XCTAssertFalse(job.hasExpired)
    }

    func testHasExpiredReturnsTrueAfterThreeDaysWhenAutoDisableIsOn() {
        var job = AICronjob()
        job.autoDisable = true
        job.activationDate = Date().addingTimeInterval(-(60 * 60 * 24 * 4)).timeIntervalSince1970

        XCTAssertTrue(job.hasExpired)
    }

    func testArrayRawRepresentableRoundTripsCronjobs() {
        var appJob = AICronjob()
        appJob.name = "Daily Summary"
        appJob.prompt = "Summarize build health"
        appJob.mode = .app
        appJob.interval = 300
        appJob.isEnabled = true

        var machineJob = AICronjob()
        machineJob.name = "Nightly Agent"
        machineJob.mode = .machine
        machineJob.cronExpression = "15 2 * * *"
        machineJob.isEnabled = true

        let jobs = [appJob, machineJob]
        let encoded = jobs.rawValue

        XCTAssertEqual([AICronjob](rawValue: encoded), jobs)
    }

    func testArrayRawRepresentableRejectsInvalidJSON() {
        XCTAssertNil([AICronjob](rawValue: "not-json"))
    }

    func testConnectedAppsRoundTripAndNormalizeDuplicates() {
        var job = AICronjob()
        job.connectedApps = [.notchTerminal, .notchTerminal]

        XCTAssertEqual(job.normalizedConnectedApps, [.notchTerminal])

        let jobs = [job]
        let encoded = jobs.rawValue
        let decoded = [AICronjob](rawValue: encoded)

        XCTAssertEqual(decoded?.first?.connectedApps, [.notchTerminal])
    }

    func testConnectedAppPromptTokenIsStable() {
        XCTAssertEqual(AICronjobConnectedApp.notchTerminal.promptToken, "@notch-terminal")
    }

    func testInstalledAppsRoundTripAndNormalizeDuplicates() {
        var job = AICronjob()
        let safari = AICronjobInstalledApp(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            appPath: "/Applications/Safari.app"
        )

        job.installedApps = [safari, safari]

        XCTAssertEqual(job.normalizedInstalledApps, [safari])

        let jobs = [job]
        let encoded = jobs.rawValue
        let decoded = [AICronjob](rawValue: encoded)

        XCTAssertEqual(decoded?.first?.installedApps, [safari])
        XCTAssertEqual(decoded?.first?.installedApps.first?.promptToken, "@app:com.apple.Safari")
    }
}
