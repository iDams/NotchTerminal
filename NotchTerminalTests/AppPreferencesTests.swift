import XCTest
@testable import NotchTerminal

final class AppPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsMatchExpectedValues() {
        XCTAssertEqual(AppPreferences.Defaults.notchDockingSensitivity, 80)
        XCTAssertEqual(AppPreferences.Defaults.autoOpenOnHoverDelay, 0.5)
        XCTAssertEqual(AppPreferences.Defaults.terminalDefaultWidth, 740)
        XCTAssertEqual(AppPreferences.Defaults.terminalDefaultHeight, 480)
        XCTAssertEqual(AppPreferences.Defaults.closeActionMode, "terminateProcessAndClose")
        XCTAssertTrue(AppPreferences.Defaults.autoOpenOnHover)
        XCTAssertTrue(AppPreferences.Defaults.hapticFeedback)
        XCTAssertFalse(AppPreferences.Defaults.showDockIcon)
    }

    func testSetNotchEnabledTracksDisabledDisplayIDs() {
        let firstDisplay: CGDirectDisplayID = 111
        let secondDisplay: CGDirectDisplayID = 222

        XCTAssertTrue(AppPreferences.isNotchEnabled(for: firstDisplay, in: defaults))
        XCTAssertTrue(AppPreferences.isNotchEnabled(for: secondDisplay, in: defaults))

        AppPreferences.setNotchEnabled(false, for: firstDisplay, in: defaults)
        AppPreferences.setNotchEnabled(false, for: secondDisplay, in: defaults)

        XCTAssertFalse(AppPreferences.isNotchEnabled(for: firstDisplay, in: defaults))
        XCTAssertFalse(AppPreferences.isNotchEnabled(for: secondDisplay, in: defaults))
        XCTAssertEqual(AppPreferences.disabledNotchDisplayIDs(in: defaults), [firstDisplay, secondDisplay])

        AppPreferences.setNotchEnabled(true, for: firstDisplay, in: defaults)

        XCTAssertTrue(AppPreferences.isNotchEnabled(for: firstDisplay, in: defaults))
        XCTAssertFalse(AppPreferences.isNotchEnabled(for: secondDisplay, in: defaults))
        XCTAssertEqual(AppPreferences.disabledNotchDisplayIDs(in: defaults), [secondDisplay])
    }

    func testPerDisplayDoublePreferencesRoundTripAndRemoveZeroValues() {
        let displayID: CGDirectDisplayID = 333

        XCTAssertEqual(AppPreferences.notchOffsetX(for: displayID, in: defaults), 0)
        XCTAssertEqual(AppPreferences.notchOffsetY(for: displayID, in: defaults), 0)
        XCTAssertEqual(AppPreferences.notchWidthAdjustment(for: displayID, in: defaults), 0)

        AppPreferences.setNotchOffsetX(18.5, for: displayID, in: defaults)
        AppPreferences.setNotchOffsetY(-7.25, for: displayID, in: defaults)
        AppPreferences.setNotchWidthAdjustment(14, for: displayID, in: defaults)

        XCTAssertEqual(AppPreferences.notchOffsetX(for: displayID, in: defaults), 18.5)
        XCTAssertEqual(AppPreferences.notchOffsetY(for: displayID, in: defaults), -7.25)
        XCTAssertEqual(AppPreferences.notchWidthAdjustment(for: displayID, in: defaults), 14)

        AppPreferences.setNotchOffsetX(0, for: displayID, in: defaults)
        AppPreferences.setNotchOffsetY(0.00001, for: displayID, in: defaults)
        AppPreferences.setNotchWidthAdjustment(0, for: displayID, in: defaults)

        XCTAssertEqual(AppPreferences.notchOffsetX(for: displayID, in: defaults), 0)
        XCTAssertEqual(AppPreferences.notchOffsetY(for: displayID, in: defaults), 0)
        XCTAssertEqual(AppPreferences.notchWidthAdjustment(for: displayID, in: defaults), 0)
        XCTAssertEqual(defaults.dictionary(forKey: AppPreferences.Keys.notchDisplayOffsetX)?.count ?? 0, 0)
        XCTAssertEqual(defaults.dictionary(forKey: AppPreferences.Keys.notchDisplayOffsetY)?.count ?? 0, 0)
        XCTAssertEqual(defaults.dictionary(forKey: AppPreferences.Keys.notchDisplayWidthAdjustment)?.count ?? 0, 0)
    }

    func testAuroraOverrideUsesFallbackUntilCustomOverrideEnabled() {
        let displayID: CGDirectDisplayID = 444

        AppPreferences.setAuroraBackgroundEnabled(true, for: displayID, in: defaults)
        AppPreferences.setAuroraTheme("sunset", for: displayID, in: defaults)

        XCTAssertFalse(AppPreferences.hasCustomAuroraOverride(for: displayID, in: defaults))
        XCTAssertFalse(AppPreferences.auroraBackgroundEnabled(for: displayID, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: displayID, fallback: "default", in: defaults), "default")

        AppPreferences.setCustomAuroraOverrideEnabled(true, for: displayID, in: defaults)

        XCTAssertTrue(AppPreferences.hasCustomAuroraOverride(for: displayID, in: defaults))
        XCTAssertTrue(AppPreferences.auroraBackgroundEnabled(for: displayID, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: displayID, fallback: "default", in: defaults), "sunset")
    }

    func testDisablingAuroraOverrideClearsPerDisplayBoolAndStringValues() {
        let displayID: CGDirectDisplayID = 555

        AppPreferences.setCustomAuroraOverrideEnabled(true, for: displayID, in: defaults)
        AppPreferences.setAuroraBackgroundEnabled(true, for: displayID, in: defaults)
        AppPreferences.setAuroraTheme("aurora-night", for: displayID, in: defaults)

        XCTAssertTrue(AppPreferences.auroraBackgroundEnabled(for: displayID, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: displayID, fallback: "fallback", in: defaults), "aurora-night")

        AppPreferences.setCustomAuroraOverrideEnabled(false, for: displayID, in: defaults)

        XCTAssertFalse(AppPreferences.hasCustomAuroraOverride(for: displayID, in: defaults))
        XCTAssertFalse(AppPreferences.auroraBackgroundEnabled(for: displayID, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: displayID, fallback: "fallback", in: defaults), "fallback")
        XCTAssertNil(defaults.dictionary(forKey: AppPreferences.Keys.auroraDisplayEnabledMap)?[String(displayID)])
        XCTAssertNil(defaults.dictionary(forKey: AppPreferences.Keys.auroraDisplayThemeMap)?[String(displayID)])
    }

    func testDisabledDisplayIDsPersistAsSortedStableList() {
        let displayA: CGDirectDisplayID = 30
        let displayB: CGDirectDisplayID = 10
        let displayC: CGDirectDisplayID = 20

        AppPreferences.setNotchEnabled(false, for: displayA, in: defaults)
        AppPreferences.setNotchEnabled(false, for: displayB, in: defaults)
        AppPreferences.setNotchEnabled(false, for: displayC, in: defaults)

        XCTAssertEqual(
            defaults.string(forKey: AppPreferences.Keys.disabledNotchDisplayIDs),
            "10,20,30"
        )
    }

    func testAuroraOverrideIsScopedPerDisplay() {
        let first: CGDirectDisplayID = 601
        let second: CGDirectDisplayID = 602

        AppPreferences.setCustomAuroraOverrideEnabled(true, for: first, in: defaults)
        AppPreferences.setAuroraBackgroundEnabled(true, for: first, in: defaults)
        AppPreferences.setAuroraTheme("sunset", for: first, in: defaults)

        XCTAssertTrue(AppPreferences.auroraBackgroundEnabled(for: first, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: first, fallback: "classic", in: defaults), "sunset")

        XCTAssertFalse(AppPreferences.hasCustomAuroraOverride(for: second, in: defaults))
        XCTAssertFalse(AppPreferences.auroraBackgroundEnabled(for: second, fallback: false, in: defaults))
        XCTAssertEqual(AppPreferences.auroraTheme(for: second, fallback: "classic", in: defaults), "classic")
    }
}
