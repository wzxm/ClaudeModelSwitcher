//
//  SkillListView.swift
//  ClaudeModelSwitcher
//
//  技能列表视图 - 搜索、展开/收起、同步操作
//

import SwiftUI

struct SkillListView: View {
    @ObservedObject var skillService: SkillService
    @State private var searchText = ""
    @State private var showingDetailSkill: Skill? = nil
    @State private var showDeleteConfirm = false
    @State private var skillToDelete: Skill? = nil


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题
            headerView

            Divider()

            // 搜索栏
            searchBarView
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // 技能列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(skillService.skills) { skill in
                        // 只有搜索匹配的才显示
                        if matchesSearch(skill) {
                            SkillCardView(
                                skill: skill,
                                skillService: skillService,
                                onShowDetail: { showingDetailSkill = skill },
                                onDelete: {
                                    skillToDelete = skill
                                    showDeleteConfirm = true
                                }
                            )
                            .id(skill.id) // 确保 id 稳定
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $showingDetailSkill) { skill in
            SkillDetailView(skill: skill, skillService: skillService)
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let skill = skillToDelete {
                    _ = skillService.deleteSkill(skill)
                }
            }
        } message: {
            Text("确定要删除技能「\(skillToDelete?.name ?? "")」吗？此操作不可恢复。")
        }
    }

    // MARK: - 顶部标题

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("技能管理")
                    .font(.system(size: 22, weight: .bold))
                Text("管理已安装的 \(skillService.skills.count) 个技能")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                skillService.refreshSkills()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .rotationEffect(.degrees(skillService.isLoading ? 360 : 0))
                    .animation(skillService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: skillService.isLoading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(skillService.isLoading ? .blue : .secondary)
            .help("刷新技能列表")
            .disabled(skillService.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - 搜索栏

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("搜索技能名称、来源...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - 搜索匹配

    private func matchesSearch(_ skill: Skill) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return skill.name.lowercased().contains(query) ||
               (skill.sourceURL?.lowercased().contains(query) ?? false) ||
               (skill.description?.lowercased().contains(query) ?? false)
    }
}

// MARK: - 独立的技能卡片视图

struct SkillCardView: View {
    let skill: Skill
    let skillService: SkillService
    let onShowDetail: () -> Void
    let onDelete: () -> Void

    // 自己管理展开状态，不影响父视图
    @State private var isExpanded = false

    // 缓存同步状态，避免每次渲染都查询
    @State private var syncStatuses: [SyncTarget: SyncStatus] = [:]

    // 防止 onAppear 重复加载
    @State private var hasLoadedStatuses = false

    // 更新状态
    @State private var isUpdating = false
    @State private var updateMessage = ""
    @State private var updateSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // 卡片主行
            HStack(spacing: 12) {
                // 技能图标
                skillIcon

                // 技能信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 14, weight: .medium))
                    Text("创建于 \(formattedDate(skill.createdDate))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // 操作按钮组
                HStack(spacing: 4) {
                    actionButton(icon: "doc.text.magnifyingglass", help: "查看文件详情", action: onShowDetail)
                    actionButton(icon: "folder", help: "在 Finder 中打开") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: skill.path)
                    }

                    // 更新按钮（仅 git 来源技能显示）
                    if skill.sourceType == .git {
                        Button(action: updateSkill) {
                            if isUpdating {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isUpdating ? Color.secondary : Color.blue)
                        .help("更新技能")
                        .disabled(isUpdating)
                    }

                    actionButton(icon: "trash", help: "删除技能", action: onDelete)

                    // 展开/收起
                    Button(action: { toggleExpanded() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpanded()
            }

            // 展开的详情区域
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                expandedDetailView
                    .padding(16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            if !hasLoadedStatuses {
                loadSyncStatuses()
                hasLoadedStatuses = true
            }
        }
    }

    // MARK: - 技能图标

    private var skillIcon: some View {
        Group {
            if skill.sourceType == .git || skill.sourceURL != nil {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 操作按钮

    private func actionButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }

    // MARK: - 展开/收起

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
        // 展开时重新加载同步状态
        if isExpanded {
            loadSyncStatuses()
        }
    }

    // MARK: - 加载同步状态（异步，避免阻塞 UI）

    private func loadSyncStatuses() {
        let currentSkill = skill
        let service = skillService
        DispatchQueue.global(qos: .userInitiated).async {
            var statuses: [SyncTarget: SyncStatus] = [:]
            for target in SyncTarget.allCases {
                // 直接从缓存读取，不触发异步刷新
                if let cached = service.syncStatusCache[currentSkill.id]?[target] {
                    statuses[target] = cached
                } else if target == .claudeCode {
                    statuses[target] = .synced
                } else {
                    // 直接检查文件是否存在，避免通过 @Published 触发全局重渲染
                    let targetPath = target.skillPath(for: currentSkill.folderName)
                    statuses[target] = FileManager.default.fileExists(atPath: targetPath) ? .synced : .notSynced
                }
            }
            DispatchQueue.main.async {
                self.syncStatuses = statuses
            }
        }
    }

    // MARK: - 展开详情

    private var expandedDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 基本信息
            VStack(alignment: .leading, spacing: 8) {
                Text("基本信息")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    infoItem(title: "中央路径", value: skill.path)
                    infoItem(title: "来源类型", value: skill.sourceType.rawValue)
                    if let url = skill.sourceURL {
                        infoItem(title: "来源地址", value: url)
                    }
                    infoItem(title: "状态", value: "ok", isStatus: true)
                }
            }

            // 描述
            if let desc = skill.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("描述")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }

            // 同步到工具
            VStack(alignment: .leading, spacing: 8) {
                Text("同步到工具")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(SyncTarget.allCases) { target in
                        syncTargetButton(target: target)
                    }
                }
            }
        }
    }

    // MARK: - 信息项

    private func infoItem(title: String, value: String, isStatus: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            if isStatus {
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            } else {
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - 同步按钮

    private func syncTargetButton(target: SyncTarget) -> some View {
        let status = syncStatuses[target] ?? .notSynced
        let isSynced = status == .synced

        return HStack(spacing: 6) {
            Text(target.rawValue)
                .font(.system(size: 12))

            Button(action: {
                skillService.syncSkill(skill, to: target)
                // 同步后更新缓存
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
                    let newStatus = skillService.getSyncStatus(skill, for: target)
                    DispatchQueue.main.async {
                        self.syncStatuses[target] = newStatus
                    }
                }
            }) {
                Text(isSynced ? "已同步" : "同步")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isSynced ? Color.green.opacity(0.2) : Color.green.opacity(0.8))
                    .foregroundStyle(isSynced ? .green : .white)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .disabled(isSynced)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 辅助方法

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // MARK: - 更新技能（git pull）

    private func updateSkill() {
        isUpdating = true
        updateMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", skill.path, "pull"]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    isUpdating = false
                    if process.terminationStatus == 0 {
                        updateSuccess = true
                        // 判断是否有更新
                        if output.contains("Already up to date") || output.contains("已经是最新") {
                            updateMessage = "已是最新版本"
                        } else {
                            updateMessage = "更新成功"
                            skillService.refreshSkills()
                        }
                    } else {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errOutput = String(data: errData, encoding: .utf8) ?? "未知错误"
                        updateSuccess = false
                        updateMessage = "更新失败: \(errOutput)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isUpdating = false
                    updateSuccess = false
                    updateMessage = "执行 git pull 失败"
                }
            }
        }
    }
}
