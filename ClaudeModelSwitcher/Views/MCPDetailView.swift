//
//  MCPDetailView.swift
//  ClaudeModelSwitcher
//
//  MCP 服务器详情编辑弹窗
//  老王的代码，别tm乱改
//

import SwiftUI

struct MCPDetailView: View {
    let server: MCPServerConfig
    @ObservedObject var mcpService: MCPService
    @Environment(\.dismiss) private var dismiss

    // 编辑状态
    @State private var editedName: String = ""
    @State private var editedCommand: String = ""
    @State private var editedArgs: String = ""
    @State private var editedEnvVars: [(key: String, value: String)] = []

    @State private var isSaving = false
    @State private var saveMessage = ""
    @State private var saveSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            Divider()

            // 编辑表单
            ScrollView {
                formContent
                    .padding(20)
            }

            Divider()

            // 底部按钮
            footerView
        }
        .frame(width: 560, height: 520)
        .onAppear {
            loadServerData()
        }
    }

    // MARK: - 顶部标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("编辑 MCP 服务器")
                    .font(.system(size: 16, weight: .semibold))
                Text("修改服务器配置信息")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 表单内容

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 服务器名称（只读显示）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("服务器 ID")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("(不可修改)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Text(editedName)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
            }

            // 命令
            VStack(alignment: .leading, spacing: 8) {
                Text("命令")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("npx / node / python / uvx", text: $editedCommand)
                    .customInputStyle()

                Text("可执行命令路径")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 参数
            VStack(alignment: .leading, spacing: 8) {
                Text("参数")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("-y @modelcontextprotocol/server-xxx", text: $editedArgs)
                    .customInputStyle()

                Text("命令行参数，多个参数用空格分隔")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // 环境变量
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("环境变量")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: addEnvVar) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11))
                            Text("添加")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }

                if editedEnvVars.isEmpty {
                    Text("暂无环境变量，点击「添加」创建")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                        .cornerRadius(6)
                } else {
                    VStack(spacing: 8) {
                        ForEach(editedEnvVars.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("KEY", text: $editedEnvVars[index].key)
                                    .customInputStyle()
                                    .frame(width: 140)

                                Text("=")
                                    .foregroundStyle(.tertiary)

                                // 敏感值用 SecureField
                                if isSensitiveKey(editedEnvVars[index].key) {
                                    SecureField("VALUE", text: $editedEnvVars[index].value)
                                        .customInputStyle()
                                } else {
                                    TextField("VALUE", text: $editedEnvVars[index].value)
                                        .customInputStyle()
                                }

                                Button(action: { editedEnvVars.remove(at: index) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // 提示消息
            if !saveMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: saveSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(saveSuccess ? .green : .red)
                    Text(saveMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 底部按钮

    private var footerView: some View {
        HStack {
            // 重置按钮
            Button(action: loadServerData) {
                Text("重置")
                    .font(.system(size: 13))
            }
            .controlSize(.regular)

            Spacer()

            // 取消按钮
            Button("取消") {
                dismiss()
            }
            .controlSize(.regular)

            // 保存按钮
            Button(action: saveChanges) {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("保存修改")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!hasChanges || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 是否有修改

    private var hasChanges: Bool {
        editedCommand != server.command ||
        editedArgs != server.args.joined(separator: " ") ||
        envVarsDict != server.env
    }

    // MARK: - 环境变量转字典

    private var envVarsDict: [String: String]? {
        var dict: [String: String] = [:]
        for (key, value) in editedEnvVars {
            if !key.isEmpty {
                dict[key] = value
            }
        }
        return dict.isEmpty ? nil : dict
    }

    // MARK: - 加载服务器数据

    private func loadServerData() {
        editedName = server.name
        editedCommand = server.command ?? ""
        editedArgs = server.args.joined(separator: " ")

        editedEnvVars = []
        if let env = server.env {
            for (key, value) in env.sorted(by: { $0.key < $1.key }) {
                editedEnvVars.append((key: key, value: value))
            }
        }

        saveMessage = ""
    }

    // MARK: - 添加环境变量

    private func addEnvVar() {
        editedEnvVars.append((key: "", value: ""))
    }

    // MARK: - 保存修改

    private func saveChanges() {
        isSaving = true
        saveMessage = ""

        // 解析参数
        let argsList = editedArgs.trimmingCharacters(in: .whitespaces).isEmpty ? [] :
            editedArgs.split(separator: " ").map { String($0) }

        // 创建更新后的配置
        let updatedConfig = MCPServerConfig(
            id: server.id,
            name: server.name,
            serverType: server.serverType,
            command: editedCommand.trimmingCharacters(in: .whitespaces),
            args: argsList,
            env: envVarsDict,
            url: server.url,
            headers: server.headers,
            isEnabled: server.isEnabled,
            createdAt: server.createdAt,
            source: server.source
        )

        mcpService.updateServer(updatedConfig) { success, message in
            isSaving = false
            saveMessage = message
            saveSuccess = success

            if success {
                // 延迟关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - 判断是否为敏感键名

    private func isSensitiveKey(_ key: String) -> Bool {
        let lowerKey = key.lowercased()
        return lowerKey.contains("token") ||
               lowerKey.contains("key") ||
               lowerKey.contains("secret") ||
               lowerKey.contains("password") ||
               lowerKey.contains("auth")
    }
}

#Preview {
    MCPDetailView(
        server: MCPServerConfig(
            id: "github",
            name: "GitHub",
            serverType: .stdio,
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_TOKEN": "ghp_xxx"],
            url: nil,
            headers: nil,
            isEnabled: true,
            createdAt: Date(),
            source: .claudeJson
        ),
        mcpService: MCPService.shared
    )
}
