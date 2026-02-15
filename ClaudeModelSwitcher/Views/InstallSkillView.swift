//
//  InstallSkillView.swift
//  ClaudeModelSwitcher
//
//  技能安装主视图 - 三个 Tab 页切换
//

import SwiftUI

/// 安装方式 Tab 枚举
enum InstallTab: String, CaseIterable, Identifiable {
    // case browse = "浏览技能" // 暂时禁用
    case local = "本地安装"
    case git = "Git 安装"

    var id: String { rawValue }

    var icon: String {
        switch self {
        // case .browse: return "globe"
        case .local: return "folder.badge.plus"
        case .git: return "arrow.down.circle"
        }
    }
}

struct InstallSkillView: View {
    @State private var selectedTab: InstallTab = .local // 默认为本地安装
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) private var dismiss

    // 安装状态
    @State private var isInstalling = false
    @State private var installMessage = ""
    @State private var installSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

//            Divider()

            // Tab 切换栏
            tabBarView

//            Divider()

            // 内容区域
            ScrollView {
                tabContentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            // 底部状态栏
            if isInstalling || !installMessage.isEmpty {
                statusBarView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 顶部标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("安装技能")
                    .font(.system(size: 18, weight: .semibold))
                Text("从本地文件夹或 Git 仓库安装技能")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Button(action: { dismiss() }) {
            //     Image(systemName: "xmark.circle.fill")
            //         .font(.system(size: 18))
            //         .foregroundStyle(.secondary)
            // }
            // .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab 切换栏

    private var tabBarView: some View {
        HStack(spacing: 10) {
            ForEach(InstallTab.allCases) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedTab == tab ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Tab 内容视图

    @ViewBuilder
    private var tabContentView: some View {
        switch selectedTab {
        // case .browse:
        //     BrowseSkillView(skillService: skillService)
        case .local:
            LocalInstallView(
                skillService: skillService,
                isInstalling: $isInstalling,
                installMessage: $installMessage,
                installSuccess: $installSuccess
            )
        case .git:
            GitInstallView(
                skillService: skillService,
                isInstalling: $isInstalling,
                installMessage: $installMessage,
                installSuccess: $installSuccess
            )
        }
    }

    // MARK: - 底部状态栏

    private var statusBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if isInstalling {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: installSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(installSuccess ? .green : .red)
                }

                Text(installMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                if !isInstalling && installSuccess {
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Tab 1: 浏览技能

struct BrowseSkillView: View {
    let skillService: SkillService

    @State private var searchQuery = ""
    @State private var searchResults: [SkillSearchResult] = []
    @State private var isSearching = false
    @State private var isInstalling: Set<String> = []
    @State private var message = ""
    @State private var messageIsError = false
    @State private var hasSearched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 搜索栏
            searchBarView

            // 内容区域
            if isSearching {
                loadingView
            } else if hasSearched && searchResults.isEmpty {
                emptyResultView
            } else if !searchResults.isEmpty {
                searchResultsView
            } else {
                placeholderView
            }

            Spacer()

            // 消息提示
            if !message.isEmpty {
                messageView
            }

        }
    }

    // MARK: - 搜索栏

    private var searchBarView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                TextField("搜索技能（如 react、python、node...）", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { performSearch() }

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        searchResults = []
                        hasSearched = false
                        message = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            Button(action: performSearch) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                    Text("搜索")
                        .font(.system(size: 13))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
    }

    // MARK: - 搜索结果列表

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { result in
                    skillResultCard(result)
                }
            }
        }
    }

    // MARK: - 单个技能卡片

    private func skillResultCard(_ result: SkillSearchResult) -> some View {
        HStack(spacing: 12) {
            // 技能图标
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)

            // 技能信息
            VStack(alignment: .leading, spacing: 3) {
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(result.owner)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !result.url.isEmpty {
                    Text(result.url)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 安装按钮
            Button(action: {
                installSkill(result)
            }) {
                if isInstalling.contains(result.id) {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 20, height: 20)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                        Text("安装")
                            .font(.system(size: 12))
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isInstalling.contains(result.id))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 占位视图

    private var placeholderView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("搜索 skills.sh 技能市场")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("输入关键词搜索开源技能，一键安装到本地")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("正在搜索...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 空结果

    private var emptyResultView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("未找到「\(searchQuery)」相关技能")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("尝试其他关键词")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 消息提示

    private var messageView: some View {
        HStack(spacing: 6) {
            Image(systemName: messageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(messageIsError ? .red : .green)
                .font(.system(size: 12))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(action: { message = "" }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(messageIsError ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
        )
    }

    // MARK: - 操作方法


    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearching = true
        hasSearched = true
        message = ""

        skillService.searchSkills(query: query) { success, results, errorMessage in
            isSearching = false
            searchResults = results
            if !success && !errorMessage.isEmpty {
                message = errorMessage
                messageIsError = true
            }
        }
    }

    private func installSkill(_ result: SkillSearchResult) {
        isInstalling.insert(result.id)
        message = ""

        skillService.addSkillFromRegistry(package: result.packageName) { success, msg in
            isInstalling.remove(result.id)
            message = msg
            messageIsError = !success
        }
    }
}

// MARK: - Tab 2: 本地安装

struct LocalInstallView: View {
    let skillService: SkillService
    @Binding var isInstalling: Bool
    @Binding var installMessage: String
    @Binding var installSuccess: Bool

    // 拖拽状态
    @State private var isDragging = false
    @State private var droppedPath: String = ""

    // 手动选择
    @State private var selectedPath: String = ""

    // 技能名称
    @State private var skillName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 拖拽区域
            VStack(alignment: .leading, spacing: 8) {
                Text("拖拽文件或文件夹到此处")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                dropZoneView
            }

            // 分隔线
            HStack {
                VStack { Divider() }
                Text("或手动选择")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                VStack { Divider() }
            }

            // 手动选择区域
            VStack(alignment: .leading, spacing: 8) {
                Text("选择技能目录或压缩包")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("选择文件路径...", text: pathBinding)
                        .customInputStyle()
                        .disabled(true)

                    Button("选择文件夹") {
                        selectFolder()
                    }
//                    .controlSize(.small)

                    Button("选择文件") {
                        selectFile()
                    }
//                    .controlSize(.small)
                }
            }

            // 技能名称输入
            VStack(alignment: .leading, spacing: 8) {
                Text("技能名称（可选，留空自动推断）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("输入技能名称...", text: $skillName)
                    .customInputStyle()
            }

            Spacer()

            // 安装按钮
            HStack {
                Spacer()
                Button(action: installFromLocal) {
                    HStack(spacing: 6) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("安装技能")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canInstall || isInstalling)
            }
        }
    }

    // MARK: - 路径绑定（优先使用拖拽路径）

    private var pathBinding: Binding<String> {
        Binding(
            get: { droppedPath.isEmpty ? selectedPath : droppedPath },
            set: { selectedPath = $0; droppedPath = "" }
        )
    }

    // MARK: - 是否可以安装

    private var canInstall: Bool {
        let path = droppedPath.isEmpty ? selectedPath : droppedPath
        return !path.isEmpty
    }

    // MARK: - 拖拽区域

    private var dropZoneView: some View {
        VStack(spacing: 12) {
            Image(systemName: isDragging ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 36))
                .foregroundStyle(isDragging ? .green : .secondary)

            Text(isDragging ? "松开以添加" : "支持文件夹和 .zip 文件")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundStyle(isDragging ? .green : .secondary.opacity(0.5))
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragging ? Color.green.opacity(0.1) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - 拖拽处理

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                droppedPath = url.path
            }
        }
    }

    // MARK: - 文件选择

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择技能目录"

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            droppedPath = ""
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "zip")!]
        panel.message = "选择技能压缩包 (.zip)"

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            droppedPath = ""
        }
    }

    // MARK: - 安装

    private func installFromLocal() {
        let path = droppedPath.isEmpty ? selectedPath : droppedPath
        let name = skillName.isEmpty ? nil : skillName

        isInstalling = true
        installMessage = "正在安装..."
        installSuccess = false

        skillService.installFromLocal(path: path, skillName: name) { success, message in
            DispatchQueue.main.async {
                isInstalling = false
                installMessage = message
                installSuccess = success

                if success {
                    // 清空输入
                    droppedPath = ""
                    selectedPath = ""
                    skillName = ""
                }
            }
        }
    }
}

// MARK: - Tab 3: Git 安装

struct GitInstallView: View {
    let skillService: SkillService
    @Binding var isInstalling: Bool
    @Binding var installMessage: String
    @Binding var installSuccess: Bool

    @State private var gitURL: String = ""
    @State private var skillName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Git URL 输入
            VStack(alignment: .leading, spacing: 8) {
                Text("Git 仓库地址")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("https://github.com/user/skill-repo.git", text: $gitURL)
                    .customInputStyle()

                Text("支持 GitHub、GitLab、Gitee 等 Git 仓库地址")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 技能名称输入
            VStack(alignment: .leading, spacing: 8) {
                Text("技能名称（可选，留空从仓库地址推断）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("输入技能名称...", text: $skillName)
                    .customInputStyle()
            }

            Spacer()

            // 安装按钮
            HStack {
                Spacer()
                Button(action: installFromGit) {
                    HStack(spacing: 6) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("克隆并安装")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canInstall || isInstalling)
            }
        }
    }

    // MARK: - 是否可以安装

    private var canInstall: Bool {
        !gitURL.isEmpty && gitURL.contains(".git")
    }

    // MARK: - 安装

    private func installFromGit() {
        let name = skillName.isEmpty ? nil : skillName

        isInstalling = true
        installMessage = "正在克隆仓库..."
        installSuccess = false

        skillService.installFromGit(url: gitURL, skillName: name) { success, message in
            DispatchQueue.main.async {
                isInstalling = false
                installMessage = message
                installSuccess = success

                if success {
                    // 清空输入
                    gitURL = ""
                    skillName = ""
                }
            }
        }
    }
}

#Preview {
    InstallSkillView(skillService: SkillService.shared)
}

// MARK: - View Extensions

extension View {
    func customInputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}
