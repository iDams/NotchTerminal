import Foundation
import AppKit

struct CLICommandBranding {
    let title: String?
    let icon: NSImage?
}

enum CLICommandBrandingResolver {
    /// Whitelist of AI CLI tools that should change the window title.
    /// Only these commands will update the title — everything else is ignored.
    private static let aiCLITools: Set<String> = [
        // OpenAI
        "openai",
        // Anthropic
        "claude",
        "claude code",
        "claud code",
        // Google
        "gemini",
        "gemini cli",
        "gemini-cli",
        // Meta
        "llama",
        // Ollama
        "ollama",
        // GitHub Copilot
        "gh copilot",
        "github-copilot-cli",
        // OpenCode
        "opencode",
        // Aider
        "aider",
        // Cursor
        "cursor",
        // Continue
        "continue",
        // LM Studio
        "lms",
        // Hugging Face
        "huggingface-cli",
        // Replicate
        "replicate",
        // Mistral
        "mistral",
        // Groq
        "groq",
        // Perplexity
        "pplx",
        // Phind
        "phind",
        // LocalAI
        "local-ai",
        // LangChain
        "langchain",
        // MLX
        "mlx_lm",
        // Transformers
        "transformers-cli",
        // Open Interpreter
        "interpreter",
        // ShellGPT
        "sgpt",
        // AI Chat
        "ai",
        // Cody
        "cody",
    ]

    private static let iconByCommand: [String: String] = [
        "opencode": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/opencode-logo-dark.svg",
        "claude": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/claude-color.svg",
        "claude code": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/claude-color.svg",
        "claud code": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/claude-color.svg",
        "gemini": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/gemini-cli.svg",
        "gemini cli": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/gemini-cli.svg",
        "gemini-cli": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/gemini-cli.svg"
    ]

    /// Returns branding only for whitelisted AI CLI tools.
    /// Returns nil title for non-AI commands so the window keeps its default "NotchTerminal" title.
    static func branding(for command: String) -> CLICommandBranding {
        let normalized = normalize(command)

        guard aiCLITools.contains(normalized) else {
            return CLICommandBranding(title: nil, icon: nil)
        }

        let icon = loadIcon(for: normalized)
        return CLICommandBranding(title: normalized, icon: icon)
    }

    private static func normalize(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        while let first = tokens.first, first.contains("=") {
            tokens.removeFirst()
        }
        while let first = tokens.first, ["sudo", "env", "nohup", "time", "command"].contains(first) {
            tokens.removeFirst()
        }

        guard let raw = tokens.first else { return "" }
        let base = URL(fileURLWithPath: raw).lastPathComponent
        guard !base.isEmpty else { return "" }

        // Multi-word command aliases
        if (base == "claude" || base == "claud"),
           tokens.count > 1,
           tokens[1].lowercased() == "code" {
            return "\(base) code"
        }
        if base == "gemini",
           tokens.count > 1,
           tokens[1].lowercased() == "cli" {
            return "gemini cli"
        }
        if base == "gh",
           tokens.count > 1,
           tokens[1].lowercased() == "copilot" {
            return "gh copilot"
        }

        return base
    }

    private static func loadIcon(for normalizedCommand: String) -> NSImage? {
        // Try exact match first, then try first word (e.g. "gemini cli" -> "gemini")
        let iconPath = iconByCommand[normalizedCommand] ?? iconByCommand[String(normalizedCommand.split(separator: " ").first ?? "")]
        guard let iconPath else { return nil }
        guard FileManager.default.fileExists(atPath: iconPath) else { return nil }

        if let image = NSImage(contentsOfFile: iconPath) {
            return image
        }

        let fallback = NSWorkspace.shared.icon(forFile: iconPath)
        fallback.size = NSSize(width: 14, height: 14)
        return fallback
    }
}
