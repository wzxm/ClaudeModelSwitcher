//
//  AppConfig.swift
//  ClaudeModelSwitcher
//
//  应用自身的配置，存 UserDefaults 里
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

    @Published var anthropicApiKey: String {
        didSet {
            defaults.set(anthropicApiKey, forKey: Keys.anthropicApiKey)
        }
    }

    @Published var openRouterApiKey: String {
        didSet {
            defaults.set(openRouterApiKey, forKey: Keys.openRouterApiKey)
        }
    }

    @Published var siliconFlowApiKey: String {
        didSet {
            defaults.set(siliconFlowApiKey, forKey: Keys.siliconFlowApiKey)
        }
    }

    @Published var volcanoApiKey: String {
        didSet {
            defaults.set(volcanoApiKey, forKey: Keys.volcanoApiKey)
        }
    }

    @Published var zaiApiKey: String {
        didSet {
            defaults.set(zaiApiKey, forKey: Keys.zaiApiKey)
        }
    }

    @Published var zhipuApiKey: String {
        didSet {
            defaults.set(zhipuApiKey, forKey: Keys.zhipuApiKey)
        }
    }

    /// GPT Proto API Key，老王加的
    @Published var gptProtoApiKey: String {
        didSet {
            defaults.set(gptProtoApiKey, forKey: Keys.gptProtoApiKey)
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
        // 从 UserDefaults 读取配置
        self.anthropicApiKey = defaults.string(forKey: Keys.anthropicApiKey) ?? ""
        self.openRouterApiKey = defaults.string(forKey: Keys.openRouterApiKey) ?? ""
        self.siliconFlowApiKey = defaults.string(forKey: Keys.siliconFlowApiKey) ?? ""
        self.volcanoApiKey = defaults.string(forKey: Keys.volcanoApiKey) ?? ""
        self.zaiApiKey = defaults.string(forKey: Keys.zaiApiKey) ?? ""
        self.zhipuApiKey = defaults.string(forKey: Keys.zhipuApiKey) ?? ""
        self.gptProtoApiKey = defaults.string(forKey: Keys.gptProtoApiKey) ?? ""
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
