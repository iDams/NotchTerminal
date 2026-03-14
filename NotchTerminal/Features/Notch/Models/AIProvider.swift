import Foundation

public enum AIProviderType: String, Codable, Equatable, CaseIterable {
    case openai
    case openrouter
    case gemini
    case anthropic
    case groq
    case deepseek
    case qwen
    case cerebras
    case lmstudio
    case ollama
    case custom

    public var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .gemini: return "Gemini"
        case .anthropic: return "Anthropic"
        case .groq: return "Groq"
        case .deepseek: return "DeepSeek"
        case .qwen: return "Qwen"
        case .cerebras: return "Cerebras"
        case .lmstudio: return "LM Studio"
        case .ollama: return "Ollama"
        case .custom: return "Custom"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .qwen: return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        case .cerebras: return "https://api.cerebras.ai/v1"
        case .lmstudio: return "http://localhost:1234/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return ""
        }
    }

    public var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openrouter/free"
        case .gemini: return "gemini-2.0-flash-lite"
        case .anthropic: return "claude-3-opus-20240229"
        case .groq: return "llama-3.3-70b-versatile"
        case .deepseek: return "deepseek-chat"
        case .qwen: return "qwen-flash"
        case .cerebras: return "llama-3.3-70b"
        case .lmstudio: return "llama-3.2-1b-instruct"
        case .ollama: return "llama3"
        case .custom: return ""
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .lmstudio, .ollama: return false
        default: return true
        }
    }

    public var defaultResponseTokenLimit: Int {
        switch self {
        case .deepseek, .gemini, .anthropic, .qwen:
            return 1200
        case .openai, .openrouter, .groq, .cerebras, .lmstudio, .ollama, .custom:
            return 800
        }
    }

    public var iconAssetName: String {
        switch self {
        case .openai: return "CLIChatGPT"
        case .gemini: return "CLIGemini"
        case .anthropic: return "CLIClaude"
        case .qwen: return "CLIQwen"
        case .groq: return "CLIGroq"
        case .deepseek: return "CLIDeepSeek"
        case .cerebras: return "CLICerebras"
        case .lmstudio: return "CLILMStudio"
        case .ollama: return "CLIOllama"
        case .openrouter: return "CLIOpenRouter"
        case .custom: return "CLICustom"
        }
    }
}

public struct AIProvider: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var type: AIProviderType = .openai
    public var baseURL: String = ""
    public var model: String = ""
    public var isEnabled: Bool = true
    public var createdAt: Double = Date().timeIntervalSince1970
    public var updatedAt: Double = Date().timeIntervalSince1970

    public var effectiveBaseURL: String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return type.defaultBaseURL
    }

    public var effectiveModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? type.defaultModel : trimmed
    }

    public init() {
        self.name = AIProviderType.openai.displayName
        self.baseURL = AIProviderType.openai.defaultBaseURL
        self.model = AIProviderType.openai.defaultModel
    }

    public init(type: AIProviderType, name: String? = nil) {
        self.type = type
        self.name = name ?? type.displayName
        self.baseURL = type.defaultBaseURL
        self.model = type.defaultModel
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case baseURL
        case model
        case isEnabled
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try container.decodeIfPresent(AIProviderType.self, forKey: .type) ?? .openai
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? Date().timeIntervalSince1970
        updatedAt = try container.decodeIfPresent(Double.self, forKey: .updatedAt) ?? Date().timeIntervalSince1970
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(model, forKey: .model)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public static func == (lhs: AIProvider, rhs: AIProvider) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.baseURL == rhs.baseURL &&
        lhs.model == rhs.model &&
        lhs.isEnabled == rhs.isEnabled
    }
}

public struct AIProviderList: Codable, RawRepresentable {
    public var providers: [AIProvider]

    public init(providers: [AIProvider] = []) {
        self.providers = providers
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([AIProvider].self, from: data) else {
            return nil
        }
        self.providers = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(providers),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
    }
}
