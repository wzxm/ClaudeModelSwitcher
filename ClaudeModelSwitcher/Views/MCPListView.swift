//
//  MCPListView.swift
//  ClaudeModelSwitcher
//
//  MCP 服务器列表视图 - 搜索、展开/收起、状态刷新
//  老王的代码，别tm乱改
//

import SwiftUI

struct MCPListView: View {
    @ObservedObject var mcpService: MCPService
    @State private var searchText = ""
    @State private var showingDetailServer: MCPServerConfig? = nil
    @State private var showDeleteConfirm = false
    @State private var serverToDelete: MCPServerConfig? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题
            headerView

            Divider()

            // 搜索栏
            searchBarView
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // 服务器列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredServers.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredServers) { server in
                            MCPCardView(
                                server: server,
                                status: mcpService.serverStatuses[server.id] ?? .unknown,
                                mcpService: mcpService,
                                onShowDetail: { showingDetailServer = server },
                                onDelete: {
                                    serverToDelete = server
                                    showDeleteConfirm = true
                                }
                            )
                            .id(server.id)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $showingDetailServer) { server in
            MCPDetailView(server: server, mcpService: mcpService)
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let server = serverToDelete {
                    mcpService.deleteServer(server) { _, _ in }
                }
            }
        } message: {
            Text("确定要删除 MCP 服务器「\(serverToDelete?.name ?? "")」吗？")
        }
    }

    // MARK: - 过滤后的服务器列表

    private var filteredServers: [MCPServerConfig] {
        guard !searchText.isEmpty else { return mcpService.servers }
        let query = searchText.lowercased()
        return mcpService.servers.filter { server in
            server.name.lowercased().contains(query) ||
            server.commandDisplay.lowercased().contains(query) ||
            server.args.joined(separator: " ").lowercased().contains(query) ||
            (server.url?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - 顶部标题

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MCP 服务器")
                    .font(.system(size: 22, weight: .bold))
                Text("管理已配置的 \(mcpService.servers.count) 个 MCP 服务器")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 刷新按钮
            Button(action: {
                mcpService.refreshServers()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13))
                    .rotationEffect(.degrees(mcpService.isLoading ? 360 : 0))
                    .animation(mcpService.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: mcpService.isLoading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(mcpService.isLoading ? .blue : .secondary)
            .help("刷新服务器列表")
            .disabled(mcpService.isLoading)

            // 检测状态按钮
            Button(action: {
                mcpService.checkAllServerStatuses()
            }) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("检测运行状态")
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
            TextField("搜索服务器名称、命令...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(searchText.isEmpty ? "暂无 MCP 服务器" : "未找到匹配的服务器")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            if searchText.isEmpty {
                Text("点击左侧「添加 MCP」开始配置")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - MCP 卡片视图

struct MCPCardView: View {
    let server: MCPServerConfig
    let status: MCPServerStatus
    let mcpService: MCPService
    let onShowDetail: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false
    @State private var isToggling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 卡片主行
            HStack(spacing: 12) {
                // 服务器图标 + 状态
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 18))
                        .foregroundStyle(server.isEnabled ? .blue : .secondary)

                    // 状态指示点
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                }
                .frame(width: 28, height: 28)

                // 服务器信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.system(size: 14, weight: .medium))

                        // 服务器类型标签
                        Text(server.serverType.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(server.serverType == .stdio ? Color.blue : Color.purple)
                            .clipShape(Capsule())

                        if !server.isEnabled {
                            Text("已禁用")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.gray)
                                .clipShape(Capsule())
                        }
                    }

                    Text(server.commandDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // 启用/禁用 Toggle
                Toggle("", isOn: Binding(
                    get: { server.isEnabled },
                    set: { _ in toggleServer() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isToggling)

                // 操作按钮组
                HStack(spacing: 4) {
                    actionButton(icon: "pencil", help: "编辑配置", action: onShowDetail)

                    actionButton(icon: "trash", help: "删除服务器", isDestructive: true, action: onDelete)

                    // 展开/收起
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
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
    }

    // MARK: - 状态颜色

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .stopped: return .gray
        case .unknown: return .orange
        case .error: return .red
        }
    }

    // MARK: - 操作按钮

    private func actionButton(icon: String, help: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDestructive ? .red : .secondary)
        .help(help)
    }

    // MARK: - 切换启用状态

    private func toggleServer() {
        isToggling = true
        mcpService.toggleServer(server) { _, _ in
            isToggling = false
        }
    }

    // MARK: - 展开详情

    private var expandedDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 基本信息
            VStack(alignment: .leading, spacing: 8) {
                Text("配置详情")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    infoItem(title: "来源", value: server.source.displayName)

                    infoItem(title: "类型", value: server.serverType.displayName)

                    switch server.serverType {
                    case .stdio:
                        if let command = server.command {
                            infoItem(title: "命令", value: command)
                        }
                        if !server.args.isEmpty {
                            infoItem(title: "参数", value: server.args.joined(separator: " "))
                        }
                    case .http, .sse:
                        if let url = server.url {
                            infoItem(title: "地址", value: url)
                        }
                    }
                }
            }

            // 环境变量（stdio 类型）
            if server.serverType == .stdio, let env = server.env, !env.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("环境变量")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(Array(env.keys.sorted()), id: \.self) { key in
                        HStack(spacing: 8) {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("=")
                                .foregroundStyle(.tertiary)
                            Text(maskEnvValue(env[key] ?? ""))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // HTTP Headers（http/sse 类型）
            if (server.serverType == .http || server.serverType == .sse),
               let headers = server.headers, !headers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("请求头")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(Array(headers.keys.sorted()), id: \.self) { key in
                        HStack(spacing: 8) {
                            Text(key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("=")
                                .foregroundStyle(.tertiary)
                            Text(maskEnvValue(headers[key] ?? ""))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 运行状态
            HStack(spacing: 8) {
                Text("状态:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Image(systemName: status.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)

                Text(status.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
            }
        }
    }

    // MARK: - 信息项

    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - 遮蔽敏感环境变量值

    private func maskEnvValue(_ value: String) -> String {
        guard value.count > 8 else { return String(repeating: "•", count: value.count) }
        let prefix = String(value.prefix(4))
        let suffix = String(value.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}

#Preview {
    MCPListView(mcpService: MCPService.shared)
}
