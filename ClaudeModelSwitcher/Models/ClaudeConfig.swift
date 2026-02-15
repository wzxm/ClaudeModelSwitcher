//
//  ClaudeConfig.swift
//  ClaudeModelSwitcher
//
//  老王的模型配置数据结构，别tm乱改
//  简化版：直接用字典，只关心要改的三个字段
//

import Foundation

/// Claude Code 配置文件结构
/// 使用字典存储原始数据，只修改需要改的字段
struct ClaudeConfig {
    /// 原始 JSON 数据
    private var rawData: [String: Any]

    /// 获取当前使用的模型名称
    var currentModel: String {
        return (envDict?[EnvKeys.anthropicModel] as? String) ?? "未设置"
    }

    /// 获取当前 API 平台类型
    var currentPlatform: ModelPlatform {
        return ModelPlatform.detect(from: envDict?[EnvKeys.anthropicBaseUrl] as? String)
    }

    /// 获取当前的 API Key
    var currentApiKey: String {
        return (envDict?[EnvKeys.anthropicAuthToken] as? String) ?? ""
    }

    /// env 字典的快捷访问
    private var envDict: [String: Any]? {
        return rawData["env"] as? [String: Any]
    }

    /// Env 字段的键名
    struct EnvKeys {
        static let anthropicBaseUrl = "ANTHROPIC_BASE_URL"
        static let anthropicAuthToken = "ANTHROPIC_AUTH_TOKEN"
        static let anthropicModel = "ANTHROPIC_MODEL"
    }

    /// 从 JSON 数据解析
    init(from data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ClaudeConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 JSON 格式"])
        }
        self.rawData = dict
    }

    /// 更新模型配置，只改三个字段，其他全部保留
    mutating func updateModel(modelId: String, baseUrl: String?, authToken: String) {
        // 确保 env 字典存在
        if rawData["env"] == nil {
            rawData["env"] = [String: Any]()
        }

        // 获取 env 并更新三个字段
        var env = rawData["env"] as? [String: Any] ?? [String: Any]()
        env[EnvKeys.anthropicModel] = modelId
        env[EnvKeys.anthropicAuthToken] = authToken

        // baseUrl 为 nil 时移除（Anthropic 官方不需要）
        if let baseUrl = baseUrl {
            env[EnvKeys.anthropicBaseUrl] = baseUrl
        } else {
            env.removeValue(forKey: EnvKeys.anthropicBaseUrl)
        }

        rawData["env"] = env
    }

    /// 转换为 JSON 数据写回文件
    func toJsonData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: rawData, options: [.prettyPrinted, .sortedKeys])
    }
}

/// 模型平台类型 - 老王精选的6个平台
enum ModelPlatform: String, CaseIterable, Codable, Identifiable {
    case anthropic = "Anthropic"
    case openrouter = "OpenRouter"
    case siliconflow = "SiliconFlow"
    case volcano = "Volcano"
    case zai = "Zai"
    case zhipu = "智谱AI"
    case gptproto = "GPTProto"

    var id: String { rawValue }

    /// 各平台的 API 基础地址
    var baseUrl: String? {
        switch self {
        case .anthropic:
            return nil
        case .openrouter:
            return "https://openrouter.ai/api"
        case .siliconflow:
            return "https://api.siliconflow.cn/v1"
        case .volcano:
            return "https://ark.cn-beijing.volces.com/api/v3"
        case .zai:
            return "https://api.z.ai/api/anthropic"
        case .zhipu:
            return "https://open.bigmodel.cn/api/anthropic"
        case .gptproto:
            return "https://gptproto.com"
        }
    }

    /// 平台描述
    var description: String {
        switch self {
        case .anthropic:
            return "Anthropic 官方 API"
        case .openrouter:
            return "多模型聚合平台"
        case .siliconflow:
            return "DeepSeek 等国产模型"
        case .volcano:
            return "字节跳动豆包系列"
        case .zai:
            return "Z.ai GLM 系列模型"
        case .zhipu:
            return "智谱 GLM 系列模型"
        case .gptproto:
            return "GPT Proto 系列模型"
        }
    }

    /// 根据 baseUrl 判断当前平台
    static func detect(from url: String?) -> ModelPlatform {
        guard let url = url, !url.isEmpty else { return .anthropic }
        if url.contains("openrouter") { return .openrouter }
        if url.contains("siliconflow") { return .siliconflow }
        if url.contains("volces") { return .volcano }
        if url.contains("z.ai") { return .zai }
        if url.contains("bigmodel") { return .zhipu }
        if url.contains("gptproto") { return .gptproto }
        return .anthropic
    }
}
