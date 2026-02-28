//
//  ModelPreset.swift
//  ClaudeModelSwitcher
//
//  预设模型定义，老王精选的好东西
//

import Foundation

/// 模型预设，包含所有支持的模型信息
struct ModelPreset: Identifiable, Codable, Hashable {
    var id: String { modelId }
    let modelId: String           // 模型标识符
    let displayName: String       // 显示名称
    let platform: ModelPlatform   // 所属平台
    let description: String?      // 模型描述（可选）
    var isCustom: Bool = false    // 是否为用户自定义模型

    /// 截取模型名称的前15个字符用于菜单栏显示
    var shortName: String {
        String(displayName.prefix(15))
    }

    /// 判断两个模型是否相等
    static func == (lhs: ModelPreset, rhs: ModelPreset) -> Bool {
        lhs.modelId == rhs.modelId && lhs.platform == rhs.platform
    }

    /// 哈希值计算
    func hash(into hasher: inout Hasher) {
        hasher.combine(modelId)
        hasher.combine(platform)
    }
}

/// 预设模型列表管理
enum ModelPresets {
    /// Anthropic 官方模型
    static let anthropicModels: [ModelPreset] = [
        ModelPreset(
            modelId: "claude-opus-4-6",
            displayName: "Claude Opus 4.6",
            platform: .anthropic,
            description: "最新最强 Opus 4.6，顶级智能"
        ),
        ModelPreset(
            modelId: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            platform: .anthropic,
            description: "最新 Sonnet 4.6，性能均衡"
        ),
        ModelPreset(
            modelId: "claude-haiku-4-5",
            displayName: "Claude Haiku 4.5",
            platform: .anthropic,
            description: "最新 Haiku 4.5，快速响应"
        ),
        ModelPreset(
            modelId: "claude-3-5-sonnet-20241022",
            displayName: "Claude 3.5 Sonnet",
            platform: .anthropic,
            description: "经典 3.5 Sonnet"
        ),
    ]

    /// CC Club 中转模型
    static let ccClubModels: [ModelPreset] = [
        ModelPreset(
            modelId: "claude-opus-4-6",
            displayName: "Claude Opus 4.6 (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - 最新最强 Opus 4.6"
        ),
        ModelPreset(
            modelId: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6 (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - 最新 Sonnet 4.6"
        ),
        ModelPreset(
            modelId: "claude-sonnet-4-5-20250929",
            displayName: "Claude Sonnet 4.5 (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - Claude Sonnet 4.5"
        ),
        ModelPreset(
            modelId: "gpt-5.2",
            displayName: "GPT-5.2 (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - OpenAI GPT-5.2"
        ),
        ModelPreset(
            modelId: "o3",
            displayName: "OpenAI o3 (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - OpenAI o3 推理模型"
        ),
        ModelPreset(
            modelId: "gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro (CC Club)",
            platform: .ccclub,
            description: "CC Club 中转 - Google Gemini 2.5 Pro"
        ),
    ]

    /// OpenRouter 热门模型
    static let openRouterModels: [ModelPreset] = [
        ModelPreset(
            modelId: "openrouter/pony-alpha",
            displayName: "Pony Alpha",
            platform: .openrouter,
            description: "OpenRouter 小马模型"
        ),
        ModelPreset(
            modelId: "openrouter/quasar-alpha",
            displayName: "Quasar Alpha",
            platform: .openrouter,
            description: "OpenRouter 类星体模型"
        ),
        ModelPreset(
            modelId: "anthropic/claude-sonnet-4",
            displayName: "Claude Sonnet 4 (OR)",
            platform: .openrouter,
            description: "通过 OpenRouter 访问"
        ),
        ModelPreset(
            modelId: "anthropic/claude-3.5-sonnet",
            displayName: "Claude 3.5 Sonnet (OR)",
            platform: .openrouter,
            description: "通过 OpenRouter 访问"
        ),
        ModelPreset(
            modelId: "openai/gpt-4o",
            displayName: "GPT-4o",
            platform: .openrouter,
            description: "OpenAI GPT-4o"
        ),
        ModelPreset(
            modelId: "google/gemini-pro-1.5",
            displayName: "Gemini Pro 1.5",
            platform: .openrouter,
            description: "Google Gemini Pro"
        ),
    ]

    /// SiliconFlow 模型（DeepSeek 等）
    static let siliconFlowModels: [ModelPreset] = [
        ModelPreset(
            modelId: "deepseek-ai/DeepSeek-V3",
            displayName: "DeepSeek V3",
            platform: .siliconflow,
            description: "DeepSeek V3 通用模型"
        ),
        ModelPreset(
            modelId: "deepseek-ai/DeepSeek-R1",
            displayName: "DeepSeek R1",
            platform: .siliconflow,
            description: "DeepSeek R1 推理模型"
        ),
        ModelPreset(
            modelId: "Qwen/Qwen2.5-72B-Instruct",
            displayName: "Qwen 2.5 72B",
            platform: .siliconflow,
            description: "通义千问 72B"
        ),
    ]

    /// Volcano 豆包模型
    static let volcanoModels: [ModelPreset] = [
        ModelPreset(
            modelId: "doubao-pro-128k",
            displayName: "豆包 Pro 128K",
            platform: .volcano,
            description: "豆包 Pro 大上下文"
        ),
        ModelPreset(
            modelId: "doubao-pro-32k",
            displayName: "豆包 Pro 32K",
            platform: .volcano,
            description: "豆包 Pro 标准版"
        ),
        ModelPreset(
            modelId: "doubao-lite-32k",
            displayName: "豆包 Lite 32K",
            platform: .volcano,
            description: "豆包 Lite 轻量版"
        ),
    ]

    /// Zai 模型
    static let zaiModels: [ModelPreset] = [
        ModelPreset(
            modelId: "glm-4.7",
            displayName: "GLM-4.7",
            platform: .zai,
            description: "GLM 4.7"
        ),
        ModelPreset(
            modelId: "glm-4.6",
            displayName: "GLM-4.6",
            platform: .zai,
            description: "GLM 4.6"
        ),
        ModelPreset(
            modelId: "glm-4.5-air",
            displayName: "GLM-4.5 Air",
            platform: .zai,
            description: "GLM 轻量版"
        ),
    ]

    /// 智谱模型
    static let zhipuModels: [ModelPreset] = [
        ModelPreset(
            modelId: "glm-5",
            displayName: "GLM-5",
            platform: .zhipu,
            description: "智谱 GLM-5 最新版"
        ),
        ModelPreset(
            modelId: "glm-4.7",
            displayName: "GLM-4.7",
            platform: .zhipu,
            description: "智谱 GLM-4.7"
        ),
        ModelPreset(
            modelId: "glm-4-plus",
            displayName: "GLM-4 Plus",
            platform: .zhipu,
            description: "智谱 GLM-4 增强版"
        ),
        ModelPreset(
            modelId: "glm-4-flash",
            displayName: "GLM-4 Flash",
            platform: .zhipu,
            description: "智谱 GLM-4 快速版"
        ),
    ]

    // GPTProto 模型（Claude Code 代理服务），老王整理的
    static let gptProtoModels: [ModelPreset] = [
        ModelPreset(
            modelId: "claude-opus-4-6",
            displayName: "Claude Opus 4.6",
            platform: .gptproto,
            description: "最新最强 Opus 4.6"
        ),
        ModelPreset(
            modelId: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            platform: .gptproto,
            description: "最新 Sonnet 4.6"
        ),
        ModelPreset(
            modelId: "gpt-5.2",
            displayName: "GPT-5.2",
            platform: .gptproto,
            description: "OpenAI GPT-5.2"
        ),
        ModelPreset(
            modelId: "o3",
            displayName: "OpenAI o3",
            platform: .gptproto,
            description: "OpenAI o3 推理模型"
        ),
        ModelPreset(
            modelId: "gemini-2.5-pro",
            displayName: "Gemini 2.5 Pro",
            platform: .gptproto,
            description: "Google Gemini 2.5 Pro"
        ),
        ModelPreset(
            modelId: "qwen-turbo",
            displayName: "Qwen Turbo",
            platform: .gptproto,
            description: "阿里通义千问 Turbo"
        ),
    ]

    /// 获取所有预设模型（按平台分组）
    static var allPresets: [ModelPreset] {
        anthropicModels + ccClubModels + openRouterModels + siliconFlowModels + volcanoModels + zaiModels + zhipuModels + gptProtoModels
    }

    /// 获取指定平台的预设模型
    static func presets(for platform: ModelPlatform) -> [ModelPreset] {
        switch platform {
        case .anthropic:
            return anthropicModels
        case .ccclub:
            return ccClubModels
        case .openrouter:
            return openRouterModels
        case .siliconflow:
            return siliconFlowModels
        case .volcano:
            return volcanoModels
        case .zai:
            return zaiModels
        case .zhipu:
            return zhipuModels
        case .gptproto:
            return gptProtoModels
        }
    }

    /// 根据模型 ID 查找预设
    static func findPreset(by modelId: String) -> ModelPreset? {
        allPresets.first { $0.modelId == modelId }
    }
}
