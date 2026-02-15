//
//  ConfigService.swift
//  ClaudeModelSwitcher
//
//  配置文件读写服务，老王的核心代码，别tm乱动
//  简化版：只改三个字段，其他全部保留
//

import Foundation
import Combine

/// 配置服务错误类型
enum ConfigServiceError: LocalizedError {
    case fileNotFound
    case readError(Error)
    case writeError(Error)
    case decodeError(Error)
    case encodeError(Error)
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "配置文件不存在"
        case .readError(let error):
            return "读取配置文件失败：\(error.localizedDescription)"
        case .writeError(let error):
            return "写入配置文件失败：\(error.localizedDescription)"
        case .decodeError(let error):
            return "解析配置文件失败：\(error.localizedDescription)"
        case .encodeError(let error):
            return "生成配置数据失败：\(error.localizedDescription)"
        case .apiKeyMissing:
            return "API Key 未设置"
        }
    }
}

/// 配置服务 - 负责 Claude Code 配置文件的读写
class ConfigService: ObservableObject {
    static let shared = ConfigService()

    /// 配置文件路径
    let configFileURL: URL

    /// 当前配置
    @Published private(set) var currentConfig: ClaudeConfig?

    /// 当前使用的模型（用于菜单栏显示）
    @Published var currentModelName: String = "加载中..."

    /// 文件监听器
    private var fileWatcher: DispatchSourceFileSystemObject?

    // MARK: - 初始化

    private init() {
        self.configFileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")

        loadConfig()
        setupFileWatcher()
    }

    // MARK: - 公开方法

    /// 读取配置文件
    func loadConfig() {
        do {
            currentConfig = try readConfig()
            updateCurrentModelName()
        } catch {
            print("⚠️ 加载配置失败: \(error.localizedDescription)")
            // 创建空配置
            if let emptyData = "{}".data(using: .utf8) {
                currentConfig = try? ClaudeConfig(from: emptyData)
            }
            currentModelName = "未设置"
        }
    }

    /// 切换模型 - 只改三个字段
    func switchModel(to model: ModelPreset, apiKey: String? = nil) throws {
        let key = apiKey ?? AppConfig.shared.apiKey(for: model.platform)
        guard !key.isEmpty else {
            throw ConfigServiceError.apiKeyMissing
        }

        // 读取当前配置
        var config = try readConfig()

        // 只更新三个字段
        config.updateModel(
            modelId: model.modelId,
            baseUrl: model.platform.baseUrl,
            authToken: key
        )

        // 写回文件
        try writeConfig(config)

        currentConfig = config
        currentModelName = model.displayName
        AppConfig.shared.addRecentModel(model.modelId)
    }

    /// 仅切换模型（保持当前平台的 API Key）
    func quickSwitchModel(to modelId: String) throws {
        if let preset = ModelPresets.findPreset(by: modelId) {
            try switchModel(to: preset)
            return
        }

        if let customModel = AppConfig.shared.customModels.first(where: { $0.modelId == modelId }) {
            try switchModel(to: customModel)
            return
        }

        guard let config = currentConfig else { return }
        let platform = config.currentPlatform

        let unknownModel = ModelPreset(
            modelId: modelId,
            displayName: modelId,
            platform: platform,
            description: nil,
            isCustom: true
        )
        try switchModel(to: unknownModel)
    }

    // MARK: - 私有方法

    private func readConfig() throws -> ClaudeConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            throw ConfigServiceError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            return try ClaudeConfig(from: data)
        } catch let error as ConfigServiceError {
            throw error
        } catch {
            throw ConfigServiceError.readError(error)
        }
    }

    private func writeConfig(_ config: ClaudeConfig) throws {
        do {
            let data = try config.toJsonData()

            let claudeDir = configFileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: claudeDir.path) {
                try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            }

            try data.write(to: configFileURL, options: .atomic)
        } catch {
            throw ConfigServiceError.writeError(error)
        }
    }

    private func updateCurrentModelName() {
        guard let config = currentConfig else {
            currentModelName = "未设置"
            return
        }

        let modelId = config.currentModel
        if modelId != "未设置" {
            if let preset = ModelPresets.findPreset(by: modelId) {
                currentModelName = preset.displayName
            } else {
                currentModelName = modelId.components(separatedBy: "/").last ?? modelId
            }
        } else {
            currentModelName = "未设置"
        }
    }

    private func setupFileWatcher() {
        let descriptor = open(configFileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .extend],
            queue: DispatchQueue.global()
        )

        fileWatcher?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.loadConfig()
            }
        }

        fileWatcher?.setCancelHandler {
            close(descriptor)
        }

        fileWatcher?.resume()
    }

    deinit {
        fileWatcher?.cancel()
    }
}
