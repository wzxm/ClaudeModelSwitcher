//
//  SettingsView.swift
//  ClaudeModelSwitcher
//
//  设置窗口主视图，全新 Sidebar + Detail 布局
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject var configService = ConfigService.shared
    
    // UI State
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var selection: SettingsPage? = .anthropic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(selection: $selection) {
                Section("平台") {
                    ForEach([SettingsPage.anthropic, .openrouter, .siliconflow, .volcano, .zai, .zhipu, .gptproto], id: \.self) { page in
                        NavigationLink(value: page) {
                            Label(page.title, systemImage: page.icon)
                        }
                    }
                }

                Section("其他") {
                    NavigationLink(value: SettingsPage.custom) {
                        Label(SettingsPage.custom.title, systemImage: SettingsPage.custom.icon)
                    }
                    NavigationLink(value: SettingsPage.general) {
                        Label(SettingsPage.general.title, systemImage: SettingsPage.general.icon)
                    }
                    NavigationLink(value: SettingsPage.about) {
                        Label(SettingsPage.about.title, systemImage: SettingsPage.about.icon)
                    }
                }
            }
            .listStyle(.sidebar)

        } detail: {
            // Detail View
            if let selection = selection {
                switch selection {
                case .anthropic, .openrouter, .siliconflow, .volcano, .zai, .zhipu, .gptproto:
                    ProviderDetailView(page: selection, viewModel: viewModel)
                case .custom:
                    ModelListView(viewModel: viewModel)
                case .general:
                    GeneralSettingsView(viewModel: viewModel)
                case .about:
                    AboutView()
                }
            } else {
                Text("请选择一个项目")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 650, minHeight: 600)
        // 删掉自动保存，只有点"保存配置"按钮才保存，别TM偷偷改用户配置！
    }
}

/// 通用设置视图 (Simplified)
struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var configService = ConfigService.shared

    var body: some View {
        Form {
            Section("当前状态") {
                HStack {
                    Text("当前模型:")
                        .frame(width: 100, alignment: .leading)
                    Text(configService.currentModelName)
                        .fontWeight(.medium)
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }

                HStack {
                    Text("API 平台:")
                        .frame(width: 100, alignment: .leading)
                    Text(configService.currentConfig?.currentPlatform.rawValue ?? "未知")
                }
            }

            Section("外观") {
                Picker("主题", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            }

//            Divider()

            Section("系统集成") {
                Toggle("开机自启动", isOn: $viewModel.launchAtLogin)
                    .toggleStyle(.switch)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
