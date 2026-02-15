//
//  MCPModel.swift
//  ClaudeModelSwitcher
//
//  MCP 服务器数据模型定义，别tm乱改
//

import Foundation

/// MCP 服务器类型
enum MCPServerType: String, Codable {
    case stdio = "stdio"    // 命令行类型（command + args）
    case http = "http"      // HTTP 类型
    case sse = "sse"        // SSE 类型

    var displayName: String {
        switch self {
        case .stdio: return "命令行"
        case .http: return "HTTP"
        case .sse: return "SSE"
        }
    }

    var icon: String {
        switch self {
        case .stdio: return "terminal.fill"
        case .http: return "globe"
        case .sse: return "antenna.radiowaves.left.and.right"
        }
    }
}

/// MCP 配置来源
enum MCPConfigSource: String {
    case claudeJson = "~/.claude.json"           // Claude Code 旧格式
    case claudeMcpServers = "~/.claude/mcp-servers.json"  // Claude Code 新格式
    case cursorMcp = "~/.cursor/mcp.json"        // Cursor 编辑器
    case geminiSettings = "~/.gemini/settings.json"  // Gemini
    case projectLocal = "项目级配置"              // 项目 .claude/settings.local.json
    case unknown = "未知来源"

    var displayName: String {
        switch self {
        case .claudeJson: return "Claude Code"
        case .claudeMcpServers: return "Claude (mcp-servers)"
        case .cursorMcp: return "Cursor"
        case .geminiSettings: return "Gemini"
        case .projectLocal: return "项目配置"
        case .unknown: return "未知"
        }
    }

    var icon: String {
        switch self {
        case .claudeJson, .claudeMcpServers: return "brain"
        case .cursorMcp: return "cursorarrow"
        case .geminiSettings: return "sparkles"
        case .projectLocal: return "folder.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// MCP 服务器配置
struct MCPServerConfig: Identifiable, Hashable {
    let id: String              // 服务器名称（唯一标识）
    var name: String
    var serverType: MCPServerType

    // 命令行类型字段
    var command: String?        // npx / node / python / uvx 等
    var args: [String]
    var env: [String: String]?

    // HTTP/SSE 类型字段
    var url: String?
    var headers: [String: String]?

    var isEnabled: Bool
    var createdAt: Date
    var source: MCPConfigSource  // 配置来源

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MCPServerConfig, rhs: MCPServerConfig) -> Bool {
        lhs.id == rhs.id
    }

    /// 获取显示用的命令描述
    var commandDisplay: String {
        switch serverType {
        case .stdio:
            if let cmd = command {
                let argsStr = args.isEmpty ? "" : " " + args.joined(separator: " ")
                return "\(cmd)\(argsStr)"
            }
            return "未知命令"
        case .http, .sse:
            return url ?? "未知地址"
        }
    }
}

/// MCP 服务器来源类型（用于模板）
enum MCPServerSource: String, Codable {
    case npm = "npm"            // npx 包
    case python = "python"      // Python 包（uvx/pip）
    case local = "local"        // 本地可执行文件
    case node = "node"          // Node.js 脚本
    case http = "http"          // HTTP 服务

    var displayName: String {
        switch self {
        case .npm: return "NPM"
        case .python: return "Python"
        case .local: return "本地"
        case .node: return "Node.js"
        case .http: return "HTTP"
        }
    }

    var icon: String {
        switch self {
        case .npm: return "cube.box"
        case .python: return "snake"
        case .local: return "folder"
        case .node: return "node"
        case .http: return "globe"
        }
    }
}

/// MCP 服务器运行状态
enum MCPServerStatus: String {
    case running = "运行中"
    case stopped = "已停止"
    case unknown = "未知"
    case error = "错误"

    var color: String {
        switch self {
        case .running: return "green"
        case .stopped: return "gray"
        case .unknown: return "orange"
        case .error: return "red"
        }
    }

    var icon: String {
        switch self {
        case .running: return "checkmark.circle.fill"
        case .stopped: return "pause.circle"
        case .unknown: return "questionmark.circle"
        case .error: return "xmark.circle.fill"
        }
    }
}

/// MCP 服务器预设模板
struct MCPServerTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let command: String
    let args: [String]
    var envTemplate: [String: String]?
    let category: String
    let source: MCPServerSource
    let requiredEnvVars: [String]  // 必需的环境变量列表

    /// 创建默认配置
    func createConfig(env: [String: String]? = nil, source: MCPConfigSource = .unknown) -> MCPServerConfig {
        return MCPServerConfig(
            id: id,
            name: name,
            serverType: .stdio,
            command: command,
            args: args,
            env: env ?? envTemplate,
            url: nil,
            headers: nil,
            isEnabled: true,
            createdAt: Date(),
            source: source
        )
    }
}

/// MCP 服务器预设模板列表
struct MCPTemplates {
    static let all: [MCPServerTemplate] = [
        // 文件系统类
        MCPServerTemplate(
            id: "filesystem",
            name: "Filesystem",
            description: "本地文件系统访问，支持读写文件和目录操作",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem"],
            category: "文件",
            source: .npm,
            requiredEnvVars: []
        ),

        // GitHub
        MCPServerTemplate(
            id: "github",
            name: "GitHub",
            description: "GitHub API 集成，支持仓库、Issues、PR 操作",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            envTemplate: ["GITHUB_TOKEN": ""],
            category: "API",
            source: .npm,
            requiredEnvVars: ["GITHUB_TOKEN"]
        ),

        // Git
        MCPServerTemplate(
            id: "git",
            name: "Git",
            description: "Git 仓库操作，支持 clone、commit、push 等",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-git"],
            category: "版本控制",
            source: .npm,
            requiredEnvVars: []
        ),

        // PostgreSQL
        MCPServerTemplate(
            id: "postgres",
            name: "PostgreSQL",
            description: "PostgreSQL 数据库访问",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres"],
            envTemplate: ["POSTGRES_CONNECTION_STRING": ""],
            category: "数据库",
            source: .npm,
            requiredEnvVars: ["POSTGRES_CONNECTION_STRING"]
        ),

        // SQLite
        MCPServerTemplate(
            id: "sqlite",
            name: "SQLite",
            description: "SQLite 数据库访问",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sqlite"],
            category: "数据库",
            source: .npm,
            requiredEnvVars: []
        ),

        // Slack
        MCPServerTemplate(
            id: "slack",
            name: "Slack",
            description: "Slack 工作区集成",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-slack"],
            envTemplate: ["SLACK_BOT_TOKEN": "", "SLACK_TEAM_ID": ""],
            category: "通讯",
            source: .npm,
            requiredEnvVars: ["SLACK_BOT_TOKEN"]
        ),

        // Brave Search
        MCPServerTemplate(
            id: "brave-search",
            name: "Brave Search",
            description: "Brave 搜索引擎集成",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            envTemplate: ["BRAVE_API_KEY": ""],
            category: "搜索",
            source: .npm,
            requiredEnvVars: ["BRAVE_API_KEY"]
        ),

        // Google Maps
        MCPServerTemplate(
            id: "google-maps",
            name: "Google Maps",
            description: "Google Maps API 集成",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-google-maps"],
            envTemplate: ["GOOGLE_MAPS_API_KEY": ""],
            category: "地图",
            source: .npm,
            requiredEnvVars: ["GOOGLE_MAPS_API_KEY"]
        ),

        // Puppeteer
        MCPServerTemplate(
            id: "puppeteer",
            name: "Puppeteer",
            description: "浏览器自动化，支持网页截图和操作",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-puppeteer"],
            category: "浏览器",
            source: .npm,
            requiredEnvVars: []
        ),

        // Sequential Thinking
        MCPServerTemplate(
            id: "sequential-thinking",
            name: "Sequential Thinking",
            description: "结构化思维链工具",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-sequential-thinking"],
            category: "工具",
            source: .npm,
            requiredEnvVars: []
        ),

        // Memory
        MCPServerTemplate(
            id: "memory",
            name: "Memory",
            description: "知识图谱内存存储",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"],
            category: "存储",
            source: .npm,
            requiredEnvVars: []
        ),

        // Fetch
        MCPServerTemplate(
            id: "fetch",
            name: "Fetch",
            description: "HTTP 请求工具，支持网页抓取",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-fetch"],
            category: "网络",
            source: .npm,
            requiredEnvVars: []
        )
    ]

    /// 按分类获取模板
    static func byCategory() -> [(category: String, templates: [MCPServerTemplate])] {
        let grouped = Dictionary(grouping: all) { $0.category }
        return grouped.map { (category: $0.key, templates: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.category < $1.category }
    }

    /// 根据 ID 获取模板
    static func byId(_ id: String) -> MCPServerTemplate? {
        return all.first { $0.id == id }
    }
}

/// Claude settings.json 中的 mcpServers 结构
struct MCPServerRawConfig: Codable {
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let type: String?
    let url: String?
    let headers: [String: String]?

    /// 转换为 MCPServerConfig
    func toConfig(id: String, isEnabled: Bool = true, source: MCPConfigSource = .unknown) -> MCPServerConfig {
        let serverType: MCPServerType
        if let t = type {
            serverType = t == "sse" ? .sse : .http
        } else {
            serverType = .stdio
        }

        return MCPServerConfig(
            id: id,
            name: id,
            serverType: serverType,
            command: command,
            args: args ?? [],
            env: env,
            url: url,
            headers: headers,
            isEnabled: isEnabled,
            createdAt: Date(),
            source: source
        )
    }
}
