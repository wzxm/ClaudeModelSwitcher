//
//  ClaudeCodeManagementView.swift
//  ClaudeModelSwitcher
//
//  Claude Code CLI 管理窗口，安装卸载更新一键搞定
//  老王专门为不想敲命令的懒人准备的
//

import SwiftUI

struct ClaudeCodeManagementView: View {
    @StateObject private var service = ClaudeCodeService.shared


    var body: some View {
        VStack(spacing: 20) {
            // 顶部标题区域
            headerView

            Divider()

            // 主内容区域
            ScrollView {
                VStack(spacing: 20) {
                    // 安装状态卡片
                    statusCardView

                    // 操作按钮区域
                    actionButtonsView

                    // 日志输出区域
                    if !service.outputLog.isEmpty {
                        logView
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 560)
        .padding()
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Code 管理")
                    .font(.system(size: 18, weight: .semibold))
                Text("一键安装或卸载 Claude Code CLI")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Status Card View

    private var statusCardView: some View {
        VStack(spacing: 16) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(service.isInstalled ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: service.isInstalled ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 32))
                    .foregroundStyle(service.isInstalled ? .green : .secondary)
            }

            // 状态文本
            VStack(spacing: 6) {
                if service.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("处理中...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                } else if service.isInstalled {
                    Text("已安装")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.green)

                    // 版本信息显示
                    VStack(spacing: 4) {
                        if let version = service.version {
                            HStack(spacing: 4) {
                                Text("当前版本:")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(version)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }

                        // 只有在有更新时才显示最新版本
                        if service.hasUpdate, let latest = service.latestVersion {
                            HStack(spacing: 4) {
                                Text("最新版本:")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(latest)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                        }

                        // 检查版本状态
                        // if service.isCheckingVersion {
                        //     HStack(spacing: 4) {
                        //         ProgressView()
                        //             .scaleEffect(0.6)
                        //         Text("检查更新中...")
                        //             .font(.system(size: 12))
                        //             .foregroundStyle(.secondary)
                        //     }
                        // }
                    }
                } else {
                    Text("未安装")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("点击下方按钮开始安装")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }

            // 有更新可用提示
            if service.isInstalled && service.hasUpdate && !service.isProcessing {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.blue)
                    Text("有新版本可用！点击下方按钮更新")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // npm 状态检查
            if !service.isNpmAvailable && !service.isProcessing {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("检测到 npm 未安装，请先安装 Node.js")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons View

    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if service.isInstalled {
                // 已安装：一行显示操作按钮
                HStack(spacing: 8) {
                    // 有更新时显示更新按钮
                    if service.hasUpdate {
                        Button(action: {
                            Task { await service.update() }
                        }) {
                            HStack(spacing: 4) {
                                if service.isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle")
                                }
                                Text("更新")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(service.isProcessing || !service.isNpmAvailable)
                    }

                    // 检查更新按钮
                    Button(action: {
                        Task { await service.manualCheckUpdate() }
                    }) {
                        HStack(spacing: 4) {
                            if service.isCheckingVersion {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("检查更新")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                    }
                    .buttonStyle(.bordered)
                    .disabled(service.isProcessing || service.isCheckingVersion || !service.isNpmAvailable)

                    // 卸载按钮
                    Button(role: .destructive, action: {
                        Task { await service.uninstall() }
                    }) {
                        HStack(spacing: 4) {
                            if service.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("卸载")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(service.isProcessing || !service.isNpmAvailable)
                }

            } else {
                // 未安装：显示安装按钮
                Button(action: {
                    Task {
                        await service.install()
                    }
                }) {
                    HStack {
                        if service.isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(service.isProcessing ? "安装中..." : "安装 Claude Code")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(service.isProcessing || !service.isNpmAvailable)

                // 安装说明
                VStack(alignment: .leading, spacing: 8) {
                    Text("安装说明：")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("通过 npm 全局安装", systemImage: "checkmark")
                        Label("安装包：@anthropic-ai/claude-code", systemImage: "checkmark")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }

            // 取消按钮（处理中显示）
            if service.isProcessing {
                Button(action: {
                    service.cancel()
                }) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Log View

    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("执行日志")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    service.outputLog = ""
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(service.outputLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("logEnd")
                }
                .frame(height: 120)
                .onChange(of: service.outputLog) { _ in
                    withAnimation {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
        }
    }


}

#Preview {
    ClaudeCodeManagementView()
}
