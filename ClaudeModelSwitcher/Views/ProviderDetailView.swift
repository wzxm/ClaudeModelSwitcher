//
//  ProviderDetailView.swift
//  ClaudeModelSwitcher
//
//  模型提供商详情页（右侧视图）
//  仿照 Modern UI 重新设计
//

import SwiftUI

struct ProviderDetailView: View {
    let page: SettingsPage
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var configService = ConfigService.shared
    
    // UI 状态
    @State private var showApiKey: Bool = false
    @State private var isHovering: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerView

                VStack(spacing: 24) {
                    // 配置信息卡片
                    configInfoCard

                    // API Key 输入卡片
                    apiKeyCard

                    // 保存按钮
                    saveButton
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showToast)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 16) {
            headerIcon
            
            VStack(spacing: 4) {
                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let subtitle = page.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onHover { hover in
            isHovering = hover
        }
    }

    @ViewBuilder
    private var headerIcon: some View {
        let baseImage = Image(systemName: page.icon)
            .font(.system(size: 48))
            .foregroundStyle(page.color ?? .primary)

        if #available(macOS 14.0, *) {
            baseImage.symbolEffect(.bounce, value: isHovering)
        } else {
            baseImage
        }
    }
    
    private var configInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置信息")
                .font(.headline)
            
            VStack(spacing: 0) {
                infoRow(title: "API 地址", value: apiAddress)
                Divider()
                    .padding(.leading, 100)
                infoRow(title: "默认模型", value: defaultModel)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(1)
            .background(Color(nsColor: .separatorColor))
            .cornerRadius(9)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .frame(width: 80, alignment: .leading)
                .foregroundStyle(.secondary)
            
            Text(value)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }
    
    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if showApiKey {
                        TextField("输入 API Key", text: apiKeyBinding)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("输入 API Key", text: apiKeyBinding)
                            .textFieldStyle(.plain)
                    }

                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                // 显示已保存的 API Key（脱敏），老王专门加的安全功能
                if let currentKey = currentApiKey, !currentKey.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("已保存: \(maskedApiKey(currentKey))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("未设置 API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var saveButton: some View {
        Button {
            viewModel.saveSettings()
        } label: {
            Text("保存配置")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    // MARK: - Helpers

    private var apiAddress: String {
        page.platform?.baseUrl ?? "未设置"
    }

    private var defaultModel: String {
        guard let platform = page.platform else { return "" }
        return ModelPresets.presets(for: platform).first?.modelId ?? ""
    }

    private var apiKeyBinding: Binding<String> {
        guard let platform = page.platform else { return .constant("") }
        return viewModel.apiKeyBinding(for: platform)
    }

    /// 当前已保存的 API Key（用于脱敏显示）
    private var currentApiKey: String? {
        guard let platform = page.platform else { return nil }
        return AppConfig.shared.apiKey(for: platform)
    }

    private func maskedApiKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
}

// MARK: - Toast 提示组件，老王不想让用户点SB的"好的"

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .padding(.top, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // 2秒后自动消失，不用用户烦
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview 调试用

#Preview("Toast") {
    struct ToastPreview: View {
        @State var show = true
        var body: some View {
            ZStack {
                Color.clear
                ToastView(message: "配置已保存", isShowing: $show)
            }
            .frame(width: 300, height: 200)
        }
    }
    return ToastPreview()
}
