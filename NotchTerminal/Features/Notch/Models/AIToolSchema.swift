import Foundation

// MARK: - API Request Models

public struct AIChatRequest: Codable {
    public let model: String
    public let messages: [AIChatMessage]
    public let tools: [AIToolSchema]?
    public let toolChoice: String? // "auto", "none" or specific tool
    public let maxTokens: Int?
    public let maxCompletionTokens: Int?
    
    // For OpenRouter reasoning feature
    public var reasoning: AIReasoningSchema?
    
    public init(
        model: String,
        messages: [AIChatMessage],
        tools: [AIToolSchema]? = nil,
        toolChoice: String? = nil,
        maxTokens: Int? = nil,
        maxCompletionTokens: Int? = nil,
        reasoning: AIReasoningSchema? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.maxTokens = maxTokens
        self.maxCompletionTokens = maxCompletionTokens
        self.reasoning = reasoning
    }
    
    enum CodingKeys: String, CodingKey {
        case model, messages, tools, toolChoice = "tool_choice", maxTokens = "max_tokens", maxCompletionTokens = "max_completion_tokens", reasoning
    }
}

public struct AIChatContentPart: Codable {
    public let type: String
    public let text: String?
    public let imageURL: AIImageURLContent?

    public init(type: String, text: String? = nil, imageURL: AIImageURLContent? = nil) {
        self.type = type
        self.text = text
        self.imageURL = imageURL
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

public struct AIImageURLContent: Codable {
    public let url: String
}

public enum AIMessageContent: Codable {
    case text(String)
    case parts([AIChatContentPart])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
            return
        }
        self = .parts(try container.decode([AIChatContentPart].self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

public extension AIMessageContent {
    var plainTextValue: String {
        switch self {
        case .text(let string):
            return string
        case .parts(let parts):
            return parts.compactMap(\.text).joined(separator: "\n")
        }
    }
}

public struct AIReasoningSchema: Codable {
    public let enabled: Bool
}

public struct AIChatMessage: Codable {
    public let role: String // "system", "user", "assistant", "tool"
    public let content: AIMessageContent? // Optional because tool_calls might not have content
    public let toolCalls: [AIToolCall]?
    public let toolCallId: String? // Used when replying as "tool"
    public let reasoningContent: String?
    
    public init(role: String, content: AIMessageContent? = nil, toolCalls: [AIToolCall]? = nil, toolCallId: String? = nil, reasoningContent: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.reasoningContent = reasoningContent
    }

    public init(role: String, text: String, toolCalls: [AIToolCall]? = nil, toolCallId: String? = nil, reasoningContent: String? = nil) {
        self.init(role: role, content: .text(text), toolCalls: toolCalls, toolCallId: toolCallId, reasoningContent: reasoningContent)
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content, toolCalls = "tool_calls", toolCallId = "tool_call_id", reasoningContent = "reasoning_content"
    }
}

// MARK: - Tool Schema Definitions

public struct AIToolSchema: Codable {
    public let type: String // "function"
    public let function: AIFunctionSchema
    
    public init(type: String = "function", function: AIFunctionSchema) {
        self.type = type
        self.function = function
    }
}

public struct AIFunctionSchema: Codable {
    public let name: String
    public let description: String
    public let parameters: AIFunctionParametersSchema
}

public struct AIFunctionParametersSchema: Codable {
    public let type: String // "object"
    public let properties: [String: AIPropertySchema]
    public let required: [String]
    
    public init(type: String = "object", properties: [String : AIPropertySchema], required: [String]) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public struct AIPropertySchema: Codable {
    public let type: String // "string", "integer", "boolean"
    public let description: String?
}

// MARK: - Tool Calling Responses

public struct AIChatResponse: Codable {
    public let id: String
    public let choices: [AIChoice]
}

public struct AIChoice: Codable {
    public let index: Int
    public let message: AIChatMessage
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message, finishReason = "finish_reason"
    }
}

public struct AIToolCall: Codable {
    public let id: String
    public let type: String // "function"
    public let function: AIToolCallFunction
}

public struct AIToolCallFunction: Codable {
    public let name: String
    public let arguments: String // JSON string
}

// MARK: - Default Tools

public extension AIToolSchema {
    static var runLocalCommandTool: AIToolSchema {
        AIToolSchema(
            type: "function",
            function: AIFunctionSchema(
                name: "run_local_command",
                description: "Silently executes a whitelisted macOS bash command. IMPORTANT: You CANNOT use shell operators like pipes (|), redirects (>), or chains (&&). Do NOT try to use `grep`, `head`, or `tail` to filter output; just run the simple base command (e.g., `ps aux`, `vm_stat`, `sysctl hw.memsize`). The system will automatically safely truncate the output if it's too long.",
                parameters: AIFunctionParametersSchema(
                    type: "object",
                    properties: [
                        "command": AIPropertySchema(type: "string", description: "The exact bash command to execute. Must not contain shell operators like |, >, <, or &.")
                    ],
                    required: ["command"]
                )
            )
        )
    }

    static var notchTerminalTool: AIToolSchema {
        AIToolSchema(
            type: "function",
            function: AIFunctionSchema(
                name: "notch_terminal",
                description: "Controls the internal NotchTerminal app terminal windows. Use this when the prompt mentions @notch-terminal.",
                parameters: AIFunctionParametersSchema(
                    type: "object",
                    properties: [
                        "action": AIPropertySchema(type: "string", description: "Supported actions: open_terminal, restore_all_windows, write_text"),
                        "text": AIPropertySchema(type: "string", description: "Text to write into the terminal when action is write_text."),
                        "submit": AIPropertySchema(type: "boolean", description: "If true, presses Enter after writing text.")
                    ],
                    required: ["action"]
                )
            )
        )
    }

    static var macAppTool: AIToolSchema {
        AIToolSchema(
            type: "function",
            function: AIFunctionSchema(
                name: "mac_app",
                description: "Opens or activates an installed macOS app that is connected to the current job. Use this for @app:bundle.identifier tokens instead of using the terminal.",
                parameters: AIFunctionParametersSchema(
                    type: "object",
                    properties: [
                        "action": AIPropertySchema(type: "string", description: "Supported actions: open_app, activate_app, type_text, press_key"),
                        "bundle_identifier": AIPropertySchema(type: "string", description: "Bundle identifier of the connected macOS app, for example com.apple.calculator"),
                        "text": AIPropertySchema(type: "string", description: "Text to type into the connected app when action is type_text."),
                        "key": AIPropertySchema(type: "string", description: "Special key to press when action is press_key. Examples: enter, return, escape, tab, delete, up, down, left, right.")
                    ],
                    required: ["action", "bundle_identifier"]
                )
            )
        )
    }

    static var captureAppWindowTool: AIToolSchema {
        AIToolSchema(
            type: "function",
            function: AIFunctionSchema(
                name: "capture_app_window",
                description: "Captures a screenshot of a connected macOS app window so the AI job can inspect the current UI. Requires Screen Recording permission.",
                parameters: AIFunctionParametersSchema(
                    type: "object",
                    properties: [
                        "bundle_identifier": AIPropertySchema(type: "string", description: "Bundle identifier of the connected macOS app to capture, for example com.apple.calculator")
                    ],
                    required: ["bundle_identifier"]
                )
            )
        )
    }
}
