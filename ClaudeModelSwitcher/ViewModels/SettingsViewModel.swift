//
//  SettingsViewModel.swift
//  ClaudeModelSwitcher
//
//  设置窗口的业务逻辑，老王整理得清清楚楚
//

import Foundation
import Combine
import SwiftUI

/// 设置窗口视图模型
class SettingsViewModel: ObservableObject {
    // 各平台 API Key
    @Published var anthropicApiKey: String = ""
    @Published var ccClubApiKey: String = ""
    @Published var openRouterApiKey: String = ""
    @Published var siliconFlowApiKey: String = ""
    @Published var volcanoApiKey: String = ""
    @Published var zaiApiKey: String = ""
    @Published var zhipuApiKey: String = ""
    @Published var gptProtoApiKey: String = ""  // GPT Proto API Key，老王加的

    @Published var launchAtLogin: Bool = false
    @Published var theme: AppTheme = .system  // 主题设置，老王加的
    @Published var customModels: [ModelPreset] = []

    @Published var showingAddModelSheet: Bool = false
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""

    // Toast 提示状态
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    private let appConfig = AppConfig.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSettings()

        // 监听主题变化，即时生效，老王专门加的
        $theme
            .dropFirst()  // 跳过初始值
            .sink { [weak self] newTheme in
                self?.appConfig.theme = newTheme
            }
            .store(in: &cancellables)

        // 监听开机自启动变化，即时生效
        $launchAtLogin
            .dropFirst()
            .sink { [weak self] newValue in
                self?.appConfig.launchAtLogin = newValue
            }
            .store(in: &cancellables)
    }

    /// 加载设置
    func loadSettings() {
        anthropicApiKey = appConfig.anthropicApiKey
        ccClubApiKey = appConfig.ccClubApiKey
        openRouterApiKey = appConfig.openRouterApiKey
        siliconFlowApiKey = appConfig.siliconFlowApiKey
        volcanoApiKey = appConfig.volcanoApiKey
        zaiApiKey = appConfig.zaiApiKey
        zhipuApiKey = appConfig.zhipuApiKey
        gptProtoApiKey = appConfig.gptProtoApiKey
        launchAtLogin = appConfig.launchAtLogin
        theme = appConfig.theme
        customModels = appConfig.customModels
    }

    /// 保存设置
    func saveSettings() {
        appConfig.anthropicApiKey = anthropicApiKey
        appConfig.ccClubApiKey = ccClubApiKey
        appConfig.openRouterApiKey = openRouterApiKey
        appConfig.siliconFlowApiKey = siliconFlowApiKey
        appConfig.volcanoApiKey = volcanoApiKey
        appConfig.zaiApiKey = zaiApiKey
        appConfig.zhipuApiKey = zhipuApiKey
        appConfig.gptProtoApiKey = gptProtoApiKey
        appConfig.launchAtLogin = launchAtLogin
        appConfig.theme = theme  // 保存主题设置

        // 保存成功反馈，自动消失的toast，不用用户点SB的"好的"
        toastMessage = "配置已保存"
        showToast = true
    }

    /// 显示Toast提示
    func showSuccessToast(_ message: String) {
        toastMessage = message
        showToast = true
    }

    /// 获取指定平台的 API Key Binding
    func apiKeyBinding(for platform: ModelPlatform) -> Binding<String> {
        switch platform {
        case .anthropic:
            return Binding(
                get: { self.anthropicApiKey },
                set: { self.anthropicApiKey = $0 }
            )
        case .ccclub:
            return Binding(
                get: { self.ccClubApiKey },
                set: { self.ccClubApiKey = $0 }
            )
        case .openrouter:
            return Binding(
                get: { self.openRouterApiKey },
                set: { self.openRouterApiKey = $0 }
            )
        case .siliconflow:
            return Binding(
                get: { self.siliconFlowApiKey },
                set: { self.siliconFlowApiKey = $0 }
            )
        case .volcano:
            return Binding(
                get: { self.volcanoApiKey },
                set: { self.volcanoApiKey = $0 }
            )
        case .zai:
            return Binding(
                get: { self.zaiApiKey },
                set: { self.zaiApiKey = $0 }
            )
        case .zhipu:
            return Binding(
                get: { self.zhipuApiKey },
                set: { self.zhipuApiKey = $0 }
            )
        case .gptproto:
            return Binding(
                get: { self.gptProtoApiKey },
                set: { self.gptProtoApiKey = $0 }
            )
        }
    }

    /// 添加自定义模型
    func addCustomModel(modelId: String, displayName: String, platform: ModelPlatform, description: String?) {
        let newModel = ModelPreset(
            modelId: modelId,
            displayName: displayName,
            platform: platform,
            description: description,
            isCustom: true
        )
        appConfig.addCustomModel(newModel)
        customModels = appConfig.customModels

        // 发送通知刷新菜单栏
        NotificationCenter.default.post(name: .customModelsDidChange, object: nil)

        // 显示添加成功提示
        toastMessage = "模型 \"\(displayName)\" 已添加"
        showToast = true
    }

    /// 删除自定义模型
    func deleteCustomModel(_ model: ModelPreset) {
        appConfig.removeCustomModel(model)
        customModels = appConfig.customModels

        // 发送通知刷新菜单栏
        NotificationCenter.default.post(name: .customModelsDidChange, object: nil)

        // 显示删除成功提示
        toastMessage = "模型 \"\(model.displayName)\" 已删除"
        showToast = true
    }

    /// 更新自定义模型
    func updateCustomModel(_ originalModel: ModelPreset, newModelId: String, newDisplayName: String, newPlatform: ModelPlatform, newDescription: String?) {
        // 先删除旧的
        appConfig.removeCustomModel(originalModel)

        // 创建新的
        let updatedModel = ModelPreset(
            modelId: newModelId,
            displayName: newDisplayName.isEmpty ? newModelId : newDisplayName,
            platform: newPlatform,
            description: newDescription?.isEmpty == true ? nil : newDescription,
            isCustom: true
        )

        // 添加新的
        appConfig.addCustomModel(updatedModel)
        customModels = appConfig.customModels

        // 发送通知刷新菜单栏
        NotificationCenter.default.post(name: .customModelsDidChange, object: nil)

        // 显示更新成功提示
        toastMessage = "模型 \"\(newDisplayName)\" 已更新"
        showToast = true
    }

    /// 获取当前状态信息
    var currentStatusText: String {
        let config = ConfigService.shared.currentConfig
        let model = config?.currentModel ?? "未设置"
        let platform = config?.currentPlatform.rawValue ?? "未知"
        return "当前模型: \(model) (\(platform))"
    }

    /// 验证 API Key 格式
    func validateApiKey(_ key: String, for platform: ModelPlatform) -> Bool {
        guard !key.isEmpty else { return false }

        switch platform {
        case .anthropic:
            return key.hasPrefix("sk-ant-")
        case .ccclub:
            return key.hasPrefix("cr_") || key.hasPrefix("sk-ant-")
        case .openrouter:
            return key.hasPrefix("sk-or-")
        case .siliconflow:
            return key.count > 10 // SiliconFlow 的 key 格式不固定
        case .gptproto:
            return key.count > 10
        case .volcano, .zai, .zhipu:
            return key.count > 10
        }
    }
}

/// 设置页面枚举 - 侧边栏导航
enum SettingsPage: Hashable, Identifiable, CaseIterable {
    case anthropic
    case ccclub
    case openrouter
    case siliconflow
    case volcano
    case zai
    case zhipu
    case gptproto  // GPT Proto，老王加的
    case custom
    case general
    case about

    var id: Self { self }

    /// 关联的平台（如果是平台页面）
    var platform: ModelPlatform? {
        switch self {
        case .anthropic: return .anthropic
        case .ccclub: return .ccclub
        case .openrouter: return .openrouter
        case .siliconflow: return .siliconflow
        case .volcano: return .volcano
        case .zai: return .zai
        case .zhipu: return .zhipu
        case .gptproto: return .gptproto
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .anthropic: return "Claude 官方"
        case .ccclub: return "CC Club"
        case .openrouter: return "OpenRouter"
        case .siliconflow: return "SiliconFlow"
        case .volcano: return "火山引擎"
        case .zai: return "Z.ai"
        case .zhipu: return "智谱AI"
        case .gptproto: return "GPT Proto"
        case .custom: return "自定义模型"
        case .general: return "通用设置"
        case .about: return "关于"
        }
    }

    var subtitle: String? {
        switch self {
        case .anthropic: return "Anthropic 官方 API"
        case .ccclub: return "Claude Code Club 中转服务"
        case .openrouter: return "多模型聚合平台"
        case .siliconflow: return "DeepSeek 等国产模型"
        case .volcano: return "字节跳动豆包系列"
        case .zai: return "Z.ai GLM 系列模型"
        case .zhipu: return "智谱 GLM 系列模型"
        case .gptproto: return "Claude Code 代理服务"
        case .custom: return "管理自定义模型配置"
        default: return nil
        }
    }

    var icon: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .ccclub: return "link.badge.plus"
        case .openrouter: return "arrow.triangle.branch"
        case .siliconflow: return "cpu"
        case .volcano: return "flame"
        case .zai: return "star.circle"
        case .zhipu: return "bubble.left.and.bubble.right"
        case .gptproto: return "bolt.horizontal.circle"
        case .custom: return "list.bullet.rectangle"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }

    var color: Color? {
        switch self {
        case .anthropic: return .orange
        case .ccclub: return .mint
        case .openrouter: return .blue
        case .siliconflow: return .purple
        case .volcano: return .red
        case .zai: return .cyan
        case .zhipu: return .teal
        case .gptproto: return .indigo
        case .custom: return .green
        default: return nil
        }
    }
}

// MARK: - 通知名称定义
extension Notification.Name {
    /// 自定义模型列表变化通知
    static let customModelsDidChange = Notification.Name("customModelsDidChange")
}
