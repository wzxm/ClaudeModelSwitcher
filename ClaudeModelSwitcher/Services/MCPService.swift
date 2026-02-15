//
//  MCPService.swift
//  ClaudeModelSwitcher
//
//  MCP 配置管理核心服务，扫描、添加、删除、启用禁用 MCP 服务器
//  老王的代码，别tm乱改
//

import Foundation
import Combine

class MCPService: ObservableObject {
    static let shared = MCPService()

    /// 多个 MCP 配置文件路径
    private let configPaths: [(path: String, source: MCPConfigSource)] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            ("\(home)/.claude.json", .claudeJson),
            ("\(home)/.claude/mcp-servers.json", .claudeMcpServers),
            ("\(home)/.cursor/mcp.json", .cursorMcp),
            ("\(home)/.gemini/settings.json", .geminiSettings),
        ]
    }()

    /// 主配置文件路径（用于写入）
    private let primarySettingsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude.json"
    }()

    @Published var servers: [MCPServerConfig] = []
    @Published var serverStatuses: [String: MCPServerStatus] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let fileManager = FileManager.default
    private let operationQueue = DispatchQueue(label: "com.clademodelswitcher.mcp", qos: .userInitiated)

    private init() {
        scanServers()
    }

    // MARK: - 扫描 MCP 服务器

    /// 扫描所有配置文件中的 mcpServers 配置
    func scanServers() {
        isLoading = true
        errorMessage = nil

        operationQueue.async { [weak self] in
            guard let self = self else { return }

            var foundServers: [MCPServerConfig] = []
            var seenIds = Set<String>()  // 防止重复

            // 遍历所有配置源
            for (path, source) in self.configPaths {
                if let data = self.fileManager.contents(atPath: path),
                   let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mcpServers = settings["mcpServers"] as? [String: Any] {

                    // 获取启用/禁用列表（仅 claude.json 有这些字段）
                    let enabledList = settings["enabledMcpjsonServers"] as? [String] ?? []
                    let disabledList = settings["disabledMcpjsonServers"] as? [String] ?? []

                    for (name, config) in mcpServers {
                        // 跳过已存在的（优先保留第一次出现的）
                        if seenIds.contains(name) { continue }
                        seenIds.insert(name)

                        if let serverConfig = config as? [String: Any] {
                            // 判断是否启用
                            let isEnabled = !disabledList.contains(name) &&
                                           (enabledList.contains(name) || enabledList.isEmpty)

                            // 解析服务器配置
                            if let server = self.parseServerConfig(
                                id: name,
                                config: serverConfig,
                                isEnabled: isEnabled,
                                source: source
                            ) {
                                foundServers.append(server)
                            }
                        }
                    }
                }
            }

            // 按来源和名称排序
            let sortedServers = foundServers.sorted { lhs, rhs in
                if lhs.source != rhs.source {
                    return lhs.source.displayName < rhs.source.displayName
                }
                return lhs.name.lowercased() < rhs.name.lowercased()
            }

            DispatchQueue.main.async {
                self.servers = sortedServers
                self.isLoading = false
                // 异步检查服务器状态
                self.checkAllServerStatuses()
            }
        }
    }

    /// 解析单个服务器配置
    private func parseServerConfig(
        id: String,
        config: [String: Any],
        isEnabled: Bool,
        source: MCPConfigSource
    ) -> MCPServerConfig? {
        // 命令行类型（stdio）
        if let command = config["command"] as? String {
            let args = config["args"] as? [String] ?? []
            let env = config["env"] as? [String: String]

            return MCPServerConfig(
                id: id,
                name: id,
                serverType: .stdio,
                command: command,
                args: args,
                env: env,
                url: nil,
                headers: nil,
                isEnabled: isEnabled,
                createdAt: Date(),
                source: source
            )
        }

        // HTTP/SSE 类型
        if let type = config["type"] as? String,
           let url = config["url"] as? String {
            let serverType: MCPServerType = type == "sse" ? .sse : .http
            let headers = config["headers"] as? [String: String]

            return MCPServerConfig(
                id: id,
                name: id,
                serverType: serverType,
                command: nil,
                args: [],
                env: nil,
                url: url,
                headers: headers,
                isEnabled: isEnabled,
                createdAt: Date(),
                source: source
            )
        }

        return nil
    }

    /// 刷新服务器列表
    func refreshServers() {
        scanServers()
    }

    // MARK: - 添加 MCP 服务器

    /// 添加新的 MCP 服务器配置
    func addServer(_ server: MCPServerConfig, completion: @escaping (Bool, String) -> Void) {
        operationQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            // 检查是否已存在
            if self.servers.contains(where: { $0.id == server.id }) {
                DispatchQueue.main.async { completion(false, "服务器「\(server.id)」已存在") }
                return
            }

            // 读取现有配置
            var settings = self.readSettingsDict()

            // 添加到 mcpServers
            var mcpServers = settings["mcpServers"] as? [String: Any] ?? [:]
            mcpServers[server.id] = self.serverToDict(server)
            settings["mcpServers"] = mcpServers

            // 添加到启用列表
            var enabledList = settings["enabledMcpjsonServers"] as? [String] ?? []
            if !enabledList.contains(server.id) {
                enabledList.append(server.id)
            }
            settings["enabledMcpjsonServers"] = enabledList

            // 从禁用列表移除（如果在的话）
            var disabledList = settings["disabledMcpjsonServers"] as? [String] ?? []
            disabledList.removeAll { $0 == server.id }
            settings["disabledMcpjsonServers"] = disabledList

            // 写回文件
            let success = self.writeSettingsDict(settings)

            DispatchQueue.main.async {
                if success {
                    self.scanServers()
                    completion(true, "服务器「\(server.name)」添加成功")
                } else {
                    completion(false, "写入配置文件失败")
                }
            }
        }
    }

    // MARK: - 删除 MCP 服务器

    /// 删除 MCP 服务器配置
    func deleteServer(_ server: MCPServerConfig, completion: @escaping (Bool, String) -> Void) {
        operationQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            var settings = self.readSettingsDict()

            // 从 mcpServers 移除
            var mcpServers = settings["mcpServers"] as? [String: Any] ?? [:]
            mcpServers.removeValue(forKey: server.id)
            settings["mcpServers"] = mcpServers

            // 从启用列表移除
            var enabledList = settings["enabledMcpjsonServers"] as? [String] ?? []
            enabledList.removeAll { $0 == server.id }
            settings["enabledMcpjsonServers"] = enabledList

            // 从禁用列表移除
            var disabledList = settings["disabledMcpjsonServers"] as? [String] ?? []
            disabledList.removeAll { $0 == server.id }
            settings["disabledMcpjsonServers"] = disabledList

            // 写回文件
            let success = self.writeSettingsDict(settings)

            DispatchQueue.main.async {
                if success {
                    self.scanServers()
                    completion(true, "服务器「\(server.name)」已删除")
                } else {
                    completion(false, "写入配置文件失败")
                }
            }
        }
    }

    // MARK: - 启用/禁用 MCP 服务器

    /// 切换 MCP 服务器启用状态
    func toggleServer(_ server: MCPServerConfig, completion: @escaping (Bool, String) -> Void) {
        operationQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            var settings = self.readSettingsDict()

            var enabledList = settings["enabledMcpjsonServers"] as? [String] ?? []
            var disabledList = settings["disabledMcpjsonServers"] as? [String] ?? []

            let newEnabled = !server.isEnabled

            if newEnabled {
                // 启用：添加到启用列表，从禁用列表移除
                if !enabledList.contains(server.id) {
                    enabledList.append(server.id)
                }
                disabledList.removeAll { $0 == server.id }
            } else {
                // 禁用：从启用列表移除，添加到禁用列表
                enabledList.removeAll { $0 == server.id }
                if !disabledList.contains(server.id) {
                    disabledList.append(server.id)
                }
            }

            settings["enabledMcpjsonServers"] = enabledList
            settings["disabledMcpjsonServers"] = disabledList

            // 写回文件
            let success = self.writeSettingsDict(settings)

            DispatchQueue.main.async {
                if success {
                    self.scanServers()
                    completion(true, newEnabled ? "已启用" : "已禁用")
                } else {
                    completion(false, "写入配置文件失败")
                }
            }
        }
    }

    // MARK: - 更新 MCP 服务器

    /// 更新 MCP 服务器配置
    func updateServer(_ server: MCPServerConfig, completion: @escaping (Bool, String) -> Void) {
        operationQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            var settings = self.readSettingsDict()

            // 更新 mcpServers 中的配置
            var mcpServers = settings["mcpServers"] as? [String: Any] ?? [:]
            mcpServers[server.id] = self.serverToDict(server)
            settings["mcpServers"] = mcpServers

            // 写回文件
            let success = self.writeSettingsDict(settings)

            DispatchQueue.main.async {
                if success {
                    self.scanServers()
                    completion(true, "服务器「\(server.name)」已更新")
                } else {
                    completion(false, "写入配置文件失败")
                }
            }
        }
    }

    // MARK: - 服务器状态检测

    /// 检测单个服务器运行状态
    func checkServerStatus(_ server: MCPServerConfig) -> MCPServerStatus {
        // HTTP/SSE 类型的服务器无法通过进程检测，返回未知
        guard server.serverType == .stdio, let command = server.command else {
            return .unknown
        }

        // 根据命令类型检测进程
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")

        // 构建匹配模式
        var pattern = command
        if let firstArg = server.args.first {
            pattern = firstArg.contains("@modelcontextprotocol") ? firstArg : command
        }

        process.arguments = ["-f", pattern ?? ""]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? .running : .stopped
        } catch {
            return .unknown
        }
    }

    /// 检测所有服务器状态
    func checkAllServerStatuses() {
        operationQueue.async { [weak self] in
            guard let self = self else { return }

            var statuses: [String: MCPServerStatus] = [:]
            for server in self.servers {
                statuses[server.id] = self.checkServerStatus(server)
            }

            DispatchQueue.main.async {
                self.serverStatuses = statuses
            }
        }
    }

    // MARK: - 获取模板

    /// 获取所有预设模板
    func getTemplates() -> [MCPServerTemplate] {
        return MCPTemplates.all
    }

    /// 按分类获取模板
    func getTemplatesByCategory() -> [(category: String, templates: [MCPServerTemplate])] {
        return MCPTemplates.byCategory()
    }

    // MARK: - 文件读写辅助方法

    /// 读取主配置文件
    private func readSettingsFile() -> Data? {
        guard fileManager.fileExists(atPath: primarySettingsPath) else {
            return nil
        }
        return fileManager.contents(atPath: primarySettingsPath)
    }

    /// 读取主配置文件为字典
    private func readSettingsDict() -> [String: Any] {
        guard let data = readSettingsFile(),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// 写入主配置文件
    private func writeSettingsDict(_ settings: [String: Any]) -> Bool {
        do {
            // 确保目录存在
            let dirPath = (primarySettingsPath as NSString).deletingLastPathComponent
            if !fileManager.fileExists(atPath: dirPath) {
                try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            }

            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: primarySettingsPath))
            return true
        } catch {
            print("写入 settings.json 失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 将服务器配置转换为字典
    private func serverToDict(_ server: MCPServerConfig) -> [String: Any] {
        var dict: [String: Any] = [:]

        switch server.serverType {
        case .stdio:
            // 命令行类型
            if let command = server.command {
                dict["command"] = command
            }
            if !server.args.isEmpty {
                dict["args"] = server.args
            }
            if let env = server.env, !env.isEmpty {
                dict["env"] = env
            }
        case .http, .sse:
            // HTTP/SSE 类型
            dict["type"] = server.serverType.rawValue
            if let url = server.url {
                dict["url"] = url
            }
            if let headers = server.headers, !headers.isEmpty {
                dict["headers"] = headers
            }
        }

        return dict
    }
}
