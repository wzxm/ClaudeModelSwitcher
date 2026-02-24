//
//  AppConfig.swift
//  ClaudeModelSwitcher
//
//  应用自身的配置
//  API Key 存 Keychain（安全！），其他配置存 UserDefaults
//

import Foundation
import ServiceManagement
import AppKit

/// 应用主题模式，老王觉得这个设计挺简洁的
enum AppTheme: String, CaseIterable {
    case system = "system"  // 跟随系统（默认）
    case light = "light"    // 浅色模式
    case dark = "dark"      // 深色模式

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

/// 应用配置管理
/// 艹，这个是应用自己的配置，别和 Claude 的配置搞混了
class AppConfig: ObservableObject {
    static let shared = AppConfig()

    private let defaults = UserDefaults.standard

    // MARK: - 存储键
    private enum Keys {
        static let anthropicApiKey = "anthropicApiKey"
        static let openRouterApiKey = "openRouterApiKey"
        static let siliconFlowApiKey = "siliconFlowApiKey"
        static let volcanoApiKey = "volcanoApiKey"
        static let zaiApiKey = "zaiApiKey"
        static let zhipuApiKey = "zhipuApiKey"
        static let gptProtoApiKey = "gptProtoApiKey"  // GPT Proto API Key，老王加的
        static let recentModels = "recentModels"
        static let launchAtLogin = "launchAtLogin"
        static let customModels = "customModels"
        static let theme = "appTheme"  // 主题设置，老王加的
    }

    // MARK: - Published 属性

    // 艹，API Key 全部改用 Keychain 存储，不再明文存 UserDefaults！
    // 老王被安全审计吓到了，必须改！

    /// 标记是否已完成 Keychain 迁移
    @Published var keychainMigrationCompleted: Bool {
        didSet {
            defaults.set(keychainMigrationCompleted, forKey: "keychainMigrationCompleted")
        }
    }

    @Published var anthropicApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.anthropicApiKey, value: anthropicApiKey)
        }
    }

    @Published var openRouterApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.openRouterApiKey, value: openRouterApiKey)
        }
    }

    @Published var siliconFlowApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.siliconFlowApiKey, value: siliconFlowApiKey)
        }
    }

    @Published var volcanoApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.volcanoApiKey, value: volcanoApiKey)
        }
    }

    @Published var zaiApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.zaiApiKey, value: zaiApiKey)
        }
    }

    @Published var zhipuApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.zhipuApiKey, value: zhipuApiKey)
        }
    }

    /// GPT Proto API Key，老王加的
    @Published var gptProtoApiKey: String {
        didSet {
            KeychainService.shared.saveOrUpdate(key: Keys.gptProtoApiKey, value: gptProtoApiKey)
        }
    }

    @Published var recentModels: [String] {
        didSet {
            defaults.set(recentModels, forKey: Keys.recentModels)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    /// 应用主题，老王专门加的主题切换功能
    @Published var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            applyTheme()
        }
    }

    @Published var customModels: [ModelPreset] {
        didSet {
            if let data = try? JSONEncoder().encode(customModels) {
                defaults.set(data, forKey: Keys.customModels)
            }
        }
    }

    // MARK: - 初始化

    private init() {
        // 先初始化所有存储属性，艹，Swift 这规则真SB
        self.keychainMigrationCompleted = defaults.bool(forKey: "keychainMigrationCompleted")

        // 从 Keychain 读取 API Key（安全！）
        self.anthropicApiKey = KeychainService.shared.safeRead(key: Keys.anthropicApiKey)
        self.openRouterApiKey = KeychainService.shared.safeRead(key: Keys.openRouterApiKey)
        self.siliconFlowApiKey = KeychainService.shared.safeRead(key: Keys.siliconFlowApiKey)
        self.volcanoApiKey = KeychainService.shared.safeRead(key: Keys.volcanoApiKey)
        self.zaiApiKey = KeychainService.shared.safeRead(key: Keys.zaiApiKey)
        self.zhipuApiKey = KeychainService.shared.safeRead(key: Keys.zhipuApiKey)
        self.gptProtoApiKey = KeychainService.shared.safeRead(key: Keys.gptProtoApiKey)

        // 其他配置从 UserDefaults 读取
        self.recentModels = defaults.stringArray(forKey: Keys.recentModels) ?? []
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // 读取主题设置，默认跟随系统
        self.theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system

        // 读取自定义模型
        if let data = defaults.data(forKey: Keys.customModels),
           let models = try? JSONDecoder().decode([ModelPreset].self, from: data) {
            self.customModels = models
        } else {
            self.customModels = []
        }

        // 所有属性初始化完成后，再执行迁移逻辑
        if !keychainMigrationCompleted {
            migrateApiKeysToKeychain()
        }
    }

    // MARK: - API Key 迁移

    /// 迁移旧的明文 API Key 到 Keychain，迁移后立即删除明文记录
    /// 老王专门加的，安全第一！
    private func migrateApiKeysToKeychain() {
        let apiKeys = [
            Keys.anthropicApiKey,
            Keys.openRouterApiKey,
            Keys.siliconFlowApiKey,
            Keys.volcanoApiKey,
            Keys.zaiApiKey,
            Keys.zhipuApiKey,
            Keys.gptProtoApiKey
        ]

        for key in apiKeys {
            // 检查 UserDefaults 中是否有旧的明文 Key
            if let oldValue = defaults.string(forKey: key), !oldValue.isEmpty {
                // 迁移到 Keychain
                KeychainService.shared.saveOrUpdate(key: key, value: oldValue)
                // 立即删除 UserDefaults 中的明文记录，不留备份！
                defaults.removeObject(forKey: key)
                print("已迁移 API Key [\(key)] 到 Keychain，明文记录已删除")
            }
        }

        // 标记迁移完成
        keychainMigrationCompleted = true
        print("API Key 迁移完成，以后都走 Keychain 了")
    }

    // MARK: - 方法

    /// 获取指定平台的 API Key
    func apiKey(for platform: ModelPlatform) -> String {
        switch platform {
        case .anthropic:
            return anthropicApiKey
        case .openrouter:
            return openRouterApiKey
        case .siliconflow:
            return siliconFlowApiKey
        case .volcano:
            return volcanoApiKey
        case .zai:
            return zaiApiKey
        case .zhipu:
            return zhipuApiKey
        case .gptproto:
            return gptProtoApiKey
        }
    }

    /// 设置指定平台的 API Key
    func setApiKey(_ key: String, for platform: ModelPlatform) {
        switch platform {
        case .anthropic:
            anthropicApiKey = key
        case .openrouter:
            openRouterApiKey = key
        case .siliconflow:
            siliconFlowApiKey = key
        case .volcano:
            volcanoApiKey = key
        case .zai:
            zaiApiKey = key
        case .zhipu:
            zhipuApiKey = key
        case .gptproto:
            gptProtoApiKey = key
        }
    }

    /// 添加最近使用的模型
    func addRecentModel(_ modelId: String) {
        // 先移除旧的
        recentModels.removeAll { $0 == modelId }
        // 插入到最前面
        recentModels.insert(modelId, at: 0)
        // 只保留最近 5 个
        if recentModels.count > 5 {
            recentModels = Array(recentModels.prefix(5))
        }
    }

    /// 更新开机自启动设置
    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            // macOS 13+ 使用新的 SMAppService API
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        } else {
            // 旧版本使用 SMLoginItemSetEnabled
            SMLoginItemSetEnabled("com.laowang.ClaudeModelSwitcher" as CFString, launchAtLogin)
        }
    }

    /// 应用主题设置，老王觉得这个实现挺干净的
    func applyTheme() {
        DispatchQueue.main.async {
            switch self.theme {
            case .system:
                NSApplication.shared.appearance = nil
            case .light:
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    /// 添加自定义模型
    func addCustomModel(_ model: ModelPreset) {
        var newModel = model
        newModel.isCustom = true
        customModels.append(newModel)
    }

    /// 删除自定义模型
    func removeCustomModel(_ model: ModelPreset) {
        customModels.removeAll { $0.id == model.id }
    }
}
