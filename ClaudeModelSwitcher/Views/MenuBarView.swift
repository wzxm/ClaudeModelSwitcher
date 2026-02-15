//
//  MenuBarView.swift
//  ClaudeModelSwitcher
//
//  菜单栏视图，老王花了不少心思设计的
//

import SwiftUI

/// 菜单栏视图 - 显示模型列表和快捷操作
struct MenuBarView: View {
    @ObservedObject var configService = ConfigService.shared
    @ObservedObject var appConfig = AppConfig.shared

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 当前状态显示
            currentStatusView

            Divider()

            // 最近使用的模型
            if !appConfig.recentModels.isEmpty {
                recentModelsSection
                Divider()
            }

            // Anthropic 模型
            anthropicModelsSection

            Divider()

            // OpenRouter 模型
            openRouterModelsSection

            // 自定义模型
            if !appConfig.customModels.isEmpty {
                Divider()
                customModelsSection
            }

            Divider()

            // 底部操作
            bottomActions
        }
        .frame(width: 280)
    }

    // MARK: - 当前状态
    private var currentStatusView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("当前模型")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(configService.currentModelName)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer()
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - 最近使用
    private var recentModelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最近使用")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(appConfig.recentModels, id: \.self) { modelId in
                modelMenuItem(modelId: modelId, showPlatform: true)
            }
        }
    }

    // MARK: - Anthropic 模型
    private var anthropicModelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Anthropic 官方")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(ModelPresets.anthropicModels) { model in
                modelMenuItem(preset: model)
            }
        }
    }

    // MARK: - OpenRouter 模型
    private var openRouterModelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OpenRouter")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(ModelPresets.openRouterModels) { model in
                modelMenuItem(preset: model)
            }
        }
    }

    // MARK: - 自定义模型
    private var customModelsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("自定义模型")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(appConfig.customModels) { model in
                modelMenuItem(preset: model)
            }
        }
    }

    // MARK: - 底部操作
    private var bottomActions: some View {
        VStack(spacing: 0) {
            Button {
                openSettingsWindow()
            } label: {
                Label("打开设置...", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 模型菜单项组件

    @ViewBuilder
    private func modelMenuItem(preset: ModelPreset) -> some View {
        Button {
            switchToModel(preset: preset)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.body)
                    if let desc = preset.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                // 当前选中的模型显示勾
                if configService.currentConfig?.currentModel == preset.modelId {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func modelMenuItem(modelId: String, showPlatform: Bool = false) -> some View {
        Button {
            try? configService.quickSwitchModel(to: modelId)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelId.components(separatedBy: "/").last ?? modelId)
                        .font(.body)
                    if showPlatform {
                        Text(modelId.contains("/") ? "OpenRouter" : "Anthropic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if configService.currentConfig?.currentModel == modelId {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - 操作方法

    private func switchToModel(preset: ModelPreset) {
        do {
            try configService.switchModel(to: preset)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func openSettingsWindow() {
        // 打开设置窗口
        if #available(macOS 13.0, *) {
            // macOS 13+ 可以用 Settings 场景
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApplication.shared.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
