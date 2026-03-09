import XCTest
@testable import NotchTerminal

final class CLICommandBrandingResolverTests: XCTestCase {
    func testRecognizesDirectWhitelistedCommands() {
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "codex").title, "codex")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "claude").title, "claude")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "opencode").title, "opencode")
    }

    func testRecognizesMultiWordAliases() {
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "claude code").title, "claude code")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "claud code --dangerously-skip-permissions").title, "claud code")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "gemini cli").title, "gemini cli")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "gh copilot suggest").title, "gh copilot")
    }

    func testNormalizationIgnoresAssignmentsAndKnownPrefixes() {
        XCTAssertEqual(
            CLICommandBrandingResolver.branding(for: "FOO=1 BAR=2 sudo env nohup time command codex").title,
            "codex"
        )
        XCTAssertEqual(
            CLICommandBrandingResolver.branding(for: "TEST_API_TOKEN=dummy /usr/local/bin/codex").title,
            "codex"
        )
    }

    func testAbsolutePathsNormalizeToExecutableName() {
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "/opt/homebrew/bin/claude").title, "claude")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "/usr/local/bin/gemini cli").title, "gemini cli")
        XCTAssertEqual(CLICommandBrandingResolver.branding(for: "/Users/testuser/bin/gh copilot").title, "gh copilot")
    }

    func testNonWhitelistedCommandsReturnNilTitle() {
        XCTAssertNil(CLICommandBrandingResolver.branding(for: "ls -la").title)
        XCTAssertNil(CLICommandBrandingResolver.branding(for: "swift build").title)
        XCTAssertNil(CLICommandBrandingResolver.branding(for: "python script.py").title)
    }
}
