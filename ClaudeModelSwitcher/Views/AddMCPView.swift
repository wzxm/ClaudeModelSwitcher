//
//  AddMCPView.swift
//  ClaudeModelSwitcher
//
//  添加 MCP 服务器视图 - 预设模板 / 手动配置
//  老王的代码，别tm乱改
//

import SwiftUI

/// 添加方式 Tab 枚举
enum AddMCPTab: String, CaseIterable, Identifiable {
    case template = "预设模板"
    case manual = "手动配置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .template: return "cube.box"
        case .manual: return "pencil.and.list.clipboard"
        }
    }
}

struct AddMCPView: View {
    @ObservedObject var mcpService: MCPService
    @State private var selectedTab: AddMCPTab = .template

    // 安装状态
    @State private var isAdding = false
    @State private var addMessage = ""
    @State private var addSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // Tab 切换栏
            tabBarView

            // 内容区域
            ScrollView {
                tabContentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            // 底部状态栏
            if isAdding || !addMessage.isEmpty {
                statusBarView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 顶部标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("添加 MCP 服务器")
                    .font(.system(size: 18, weight: .semibold))
                Text("从预设模板选择或手动配置 MCP 服务器")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab 切换栏

    private var tabBarView: some View {
        HStack(spacing: 10) {
            ForEach(AddMCPTab.allCases) { tab in
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
        case .template:
            TemplateMCPView(
                mcpService: mcpService,
                isAdding: $isAdding,
                addMessage: $addMessage,
                addSuccess: $addSuccess
            )
        case .manual:
            ManualMCPView(
                mcpService: mcpService,
                isAdding: $isAdding,
                addMessage: $addMessage,
                addSuccess: $addSuccess
            )
        }
    }

    // MARK: - 底部状态栏

    private var statusBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if isAdding {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: addSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(addSuccess ? .green : .red)
                }

                Text(addMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                if !isAdding && addSuccess {
                    Button("完成") {
                        addMessage = ""
                        addSuccess = false
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

// MARK: - Tab 1: 预设模板

struct TemplateMCPView: View {
    @ObservedObject var mcpService: MCPService
    @Binding var isAdding: Bool
    @Binding var addMessage: String
    @Binding var addSuccess: Bool

    @State private var searchText = ""
    @State private var selectedTemplate: MCPServerTemplate?
    @State private var showingEnvSheet = false
    @State private var envValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 搜索栏
            searchBarView

            // 分类列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(filteredCategories, id: \.category) { category in
                        templateCategorySection(category)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $selectedTemplate) { template in
            envConfigSheet(template: template)
        }
    }

    // MARK: - 过滤后的分类

    private var filteredCategories: [(category: String, templates: [MCPServerTemplate])] {
        let categories = mcpService.getTemplatesByCategory()
        if searchText.isEmpty {
            return categories
        }
        return categories.compactMap { category in
            let filtered = category.templates.filter { template in
                template.name.lowercased().contains(searchText.lowercased()) ||
                template.description.lowercased().contains(searchText.lowercased()) ||
                template.category.lowercased().contains(searchText.lowercased())
            }
            return filtered.isEmpty ? nil : (category: category.category, templates: filtered)
        }
    }

    // MARK: - 搜索栏

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("搜索模板...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - 分类区块

    private func templateCategorySection(_ category: (category: String, templates: [MCPServerTemplate])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.category)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(category.templates) { template in
                    templateCard(template)
                }
            }
        }
    }

    // MARK: - 模板卡片

    private func templateCard(_ template: MCPServerTemplate) -> some View {
        Button(action: {
            selectedTemplate = template
            // 初始化环境变量
            envValues = template.envTemplate ?? [:]
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: template.source.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                        .frame(width: 24, height: 24)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)

                    Text(template.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    if !template.requiredEnvVars.isEmpty {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }

                Text(template.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(template.source.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                        .foregroundStyle(.secondary)

                    if !template.requiredEnvVars.isEmpty {
                        Text("需配置")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 环境变量配置 Sheet

    private func envConfigSheet(template: MCPServerTemplate) -> some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("配置 \(template.name)")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { selectedTemplate = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // 配置表单
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 服务器名称
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务器名称")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField(template.name, text: Binding(
                            get: { envValues["_serverName"] ?? template.id },
                            set: { envValues["_serverName"] = $0 }
                        ))
                        .customInputStyle()
                    }

                    // 命令预览
                    VStack(alignment: .leading, spacing: 6) {
                        Text("命令")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(template.command) \(template.args.joined(separator: " "))")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                    }

                    // 环境变量
                    if !template.requiredEnvVars.isEmpty || template.envTemplate != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("环境变量")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            ForEach(Array((template.envTemplate ?? [:]).keys.sorted()), id: \.self) { key in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Text(key)
                                            .font(.system(size: 11, design: .monospaced))
                                        if template.requiredEnvVars.contains(key) {
                                            Text("*")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    SecureField("输入值...", text: Binding(
                                        get: { envValues[key] ?? "" },
                                        set: { envValues[key] = $0 }
                                    ))
                                    .customInputStyle()
                                }
                            }
                        }
                    }

                    Text("带 * 的为必填项")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") {
                    selectedTemplate = nil
                }
                .controlSize(.regular)

                Button(action: addFromTemplate) {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("添加服务器")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isAdding)
            }
            .padding(16)
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - 从模板添加

    private func addFromTemplate() {
        guard let template = selectedTemplate else { return }

        // 检查必填环境变量
        for required in template.requiredEnvVars {
            if envValues[required]?.isEmpty ?? true {
                addMessage = "请填写必填项: \(required)"
                addSuccess = false
                return
            }
        }

        isAdding = true
        addMessage = ""

        // 创建配置
        var config = template.createConfig(env: envValues.filter { $0.key != "_serverName" }, source: .claudeJson)

        // 使用自定义名称
        if let customName = envValues["_serverName"], !customName.isEmpty {
            config = MCPServerConfig(
                id: customName,
                name: customName,
                serverType: config.serverType,
                command: config.command,
                args: config.args,
                env: config.env,
                url: config.url,
                headers: config.headers,
                isEnabled: config.isEnabled,
                createdAt: config.createdAt,
                source: .claudeJson
            )
        }

        mcpService.addServer(config) { success, message in
            isAdding = false
            addMessage = message
            addSuccess = success
            if success {
                selectedTemplate = nil
                envValues = [:]
            }
        }
    }
}

// MARK: - Tab 2: 手动配置

struct ManualMCPView: View {
    @ObservedObject var mcpService: MCPService
    @Binding var isAdding: Bool
    @Binding var addMessage: String
    @Binding var addSuccess: Bool

    @State private var serverName = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envVars: [(key: String, value: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 服务器名称
            VStack(alignment: .leading, spacing: 8) {
                Text("服务器名称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("例如: my-mcp-server", text: $serverName)
                    .customInputStyle()

                Text("唯一标识符，用于区分不同的 MCP 服务器")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 命令
            VStack(alignment: .leading, spacing: 8) {
                Text("命令")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("例如: npx", text: $command)
                    .customInputStyle()

                Text("可执行命令，如 npx、node、python、uvx 等")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 参数
            VStack(alignment: .leading, spacing: 8) {
                Text("参数（空格分隔）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("例如: -y @modelcontextprotocol/server-filesystem", text: $args)
                    .customInputStyle()

                Text("命令行参数，多个参数用空格分隔")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 环境变量
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("环境变量（可选）")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: addEnvVar) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }

                if envVars.isEmpty {
                    Text("点击 + 添加环境变量")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(envVars.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            TextField("KEY", text: $envVars[index].key)
                                .customInputStyle()
                                .frame(width: 150)

                            Text("=")
                                .foregroundStyle(.tertiary)

                            TextField("VALUE", text: $envVars[index].value)
                                .customInputStyle()

                            Button(action: { envVars.remove(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            // 添加按钮
            HStack {
                Spacer()
                Button(action: addManualServer) {
                    HStack(spacing: 6) {
                        if isAdding {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("添加服务器")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd || isAdding)
            }
        }
    }

    // MARK: - 是否可以添加

    private var canAdd: Bool {
        !serverName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - 添加环境变量行

    private func addEnvVar() {
        envVars.append((key: "", value: ""))
    }

    // MARK: - 手动添加服务器

    private func addManualServer() {
        let name = serverName.trimmingCharacters(in: .whitespaces)
        let cmd = command.trimmingCharacters(in: .whitespaces)
        let argsList = args.trimmingCharacters(in: .whitespaces).isEmpty ? [] :
            args.split(separator: " ").map { String($0) }

        // 构建环境变量字典
        var env: [String: String] = [:]
        for (key, value) in envVars {
            if !key.isEmpty {
                env[key] = value
            }
        }

        let config = MCPServerConfig(
            id: name,
            name: name,
            serverType: .stdio,
            command: cmd,
            args: argsList,
            env: env.isEmpty ? nil : env,
            url: nil,
            headers: nil,
            isEnabled: true,
            createdAt: Date(),
            source: .claudeJson
        )

        isAdding = true
        addMessage = ""

        mcpService.addServer(config) { success, message in
            isAdding = false
            addMessage = message
            addSuccess = success
            if success {
                // 清空表单
                serverName = ""
                command = ""
                args = ""
                envVars = []
            }
        }
    }
}

#Preview {
    AddMCPView(mcpService: MCPService.shared)
        .frame(width: 800, height: 600)
}
