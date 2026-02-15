//
//  SkillModel.swift
//  ClaudeModelSwitcher
//
//  技能数据模型定义
//

import Foundation

/// 同步目标工具
enum SyncTarget: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"
    case cursor = "Cursor"
    case antigravity = "Antigravity"

    var id: String { rawValue }

    /// 获取目标工具的 skills 目录路径
    var skillsDirectoryPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .claudeCode:
            return "\(home)/.claude/skills"
        case .cursor:
            return "\(home)/.cursor/skills"
        case .antigravity:
            return "\(home)/.gemini/skills"
        }
    }

    /// 获取指定技能在目标工具中的路径
    func skillPath(for skillName: String) -> String {
        return "\(skillsDirectoryPath)/\(skillName)"
    }
}

/// 同步状态
enum SyncStatus: String {
    case synced = "已同步"
    case notSynced = "未同步"
    case error = "错误"

    var color: String {
        switch self {
        case .synced: return "green"
        case .notSynced: return "gray"
        case .error: return "red"
        }
    }
}

/// 技能来源类型
enum SkillSourceType: String, Codable {
    case local = "local"
    case git = "git"
}

/// 技能数据模型
struct Skill: Identifiable, Hashable {
    let id: String
    var name: String
    var path: String
    var createdDate: Date
    var sourceType: SkillSourceType
    var sourceURL: String?
    var description: String?

    /// 文件夹名称（作为技能标识）
    var folderName: String {
        return URL(fileURLWithPath: path).lastPathComponent
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }
}

/// 技能文件树节点
struct SkillFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [SkillFile]?
    let fileSize: Int64?

    init(name: String, path: String, isDirectory: Bool, children: [SkillFile]? = nil, fileSize: Int64? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.fileSize = fileSize
    }
}

/// 技能搜索结果（来自 npx skills find）
struct SkillSearchResult: Identifiable {
    let id: String          // owner/repo@skill 格式
    let name: String        // 技能名称部分
    let owner: String       // 所有者/仓库
    let url: String         // skills.sh 链接
    
    /// 用于 npx skills add 的包名
    var packageName: String { id }
}

/// 技能更新信息（来自 npx skills check）
struct SkillUpdateInfo: Identifiable {
    let id: String
    let name: String
    let hasUpdate: Bool
}
