//
//  SkillManagerView.swift
//  ClaudeModelSwitcher
//
//  技能管理主视图 - 左侧边栏 + 右侧内容区域
//  老王加的 MCP 管理功能，别tm乱改
//

import SwiftUI

/// 侧边栏页面枚举
enum SkillManagerPage: String, CaseIterable, Identifiable {
    // 技能组
    case management = "技能管理"
    case install = "安装技能"
    // MCP 组
    case mcpManagement = "MCP 服务器"
    case mcpAdd = "添加 MCP"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .management: return "circle.fill"
        case .install: return "plus"
        case .mcpManagement: return "server.rack"
        case .mcpAdd: return "plus.circle"
        }
    }

    var systemImage: String {
        switch self {
        case .management: return "gearshape.fill"
        case .install: return "plus.circle.fill"
        case .mcpManagement: return "server.rack"
        case .mcpAdd: return "plus.circle"
        }
    }

    /// 是否是 MCP 相关页面
    var isMCP: Bool {
        switch self {
        case .management, .install: return false
        case .mcpManagement, .mcpAdd: return true
        }
    }
}

struct SkillManagerView: View {
    @State private var selectedPage: SkillManagerPage = .management
    @StateObject private var skillService = SkillService.shared
    @StateObject private var mcpService = MCPService.shared

    var body: some View {
        NavigationSplitView {
            // 左侧边栏
            sidebarContent
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            // 右侧内容区域
            switch selectedPage {
            case .management:
                SkillListView(skillService: skillService)
            case .install:
                InstallSkillView(skillService: skillService)
            case .mcpManagement:
                MCPListView(mcpService: mcpService)
            case .mcpAdd:
                AddMCPView(mcpService: mcpService)
            }
        }
        .frame(minWidth: 1000, minHeight: 800)
    }

    // MARK: - 侧边栏

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 应用标题
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                Text("SkillsManager")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // 技能组
            VStack(alignment: .leading, spacing: 4) {
                sectionHeader(title: "技能", icon: "folder.fill")
                    .padding(.horizontal, 12)

                ForEach(SkillManagerPage.allCases.filter { !$0.isMCP }) { page in
                    sidebarItem(page: page)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            // 分隔线
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // MCP 组
            VStack(alignment: .leading, spacing: 4) {
                sectionHeader(title: "MCP 服务器", icon: "server.rack")
                    .padding(.horizontal, 12)

                ForEach(SkillManagerPage.allCases.filter { $0.isMCP }) { page in
                    sidebarItem(page: page)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .listStyle(.sidebar)
    }

    // MARK: - 分组标题

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 侧边栏项

    private func sidebarItem(page: SkillManagerPage) -> some View {
        Button(action: {
            selectedPage = page
        }) {
            HStack(spacing: 10) {
                // 状态指示器或图标
                Group {
                    if page == .management {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    } else if page == .mcpManagement {
                        // MCP 服务器显示数量徽章
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: page.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 8, height: 8)
                        }
                    } else {
                        Image(systemName: page.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(page.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(selectedPage == page ? .primary : .secondary)

                Spacer()

                // MCP 服务器数量徽章
                if page == .mcpManagement && !mcpService.servers.isEmpty {
                    Text("\(mcpService.servers.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedPage == page ? Color.green.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SkillManagerView()
}
