//
//  ModelListView.swift
//  ClaudeModelSwitcher
//
//  自定义模型列表视图
//

import SwiftUI

struct ModelListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var newModelId: String = ""
    @State private var newDisplayName: String = ""
    @State private var newPlatform: ModelPlatform = .openrouter
    @State private var newDescription: String = ""
    @State private var showingAddSheet: Bool = false

    // 编辑相关状态
    @State private var editingModel: ModelPreset?
    @State private var showingEditSheet: Bool = false
    @State private var editModelId: String = ""
    @State private var editDisplayName: String = ""
    @State private var editPlatform: ModelPlatform = .openrouter
    @State private var editDescription: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 模型列表
            if viewModel.customModels.isEmpty {
                emptyStateView
            } else {
                modelListView
            }

            Divider()

            // 底部操作栏
            HStack {
                Spacer()
                Button("添加模型") {
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .sheet(isPresented: $showingAddSheet) {
            addModelSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editModelSheet
        }
        .overlay {
            ToastView(message: viewModel.toastMessage, isShowing: $viewModel.showToast)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showToast)
        .alert("提示", isPresented: $viewModel.showingAlert) {
            Button("好的", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无自定义模型")
                .font(.headline)
            Text("点击下方按钮添加你常用的模型")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 模型列表视图
    private var modelListView: some View {
        List {
            ForEach(viewModel.customModels) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .fontWeight(.medium)
                        Text(model.modelId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let desc = model.description {
                            Text(desc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // 平台标签
                    Text(model.platform.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(platformColor(for: model.platform))
                        .cornerRadius(4)

                    // 操作按钮
                    HStack(spacing: 8) {
                        Button {
                            startEditing(model: model)
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("编辑")

                        Button {
                            viewModel.deleteCustomModel(model)
                        } label: {
                            Image(systemName: "trash.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("删除")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// 获取平台对应的颜色
    private func platformColor(for platform: ModelPlatform) -> Color {
        switch platform {
        case .anthropic: return .orange.opacity(0.2)
        case .openrouter: return .blue.opacity(0.2)
        case .siliconflow: return .purple.opacity(0.2)
        case .volcano: return .red.opacity(0.2)
        case .zai: return .cyan.opacity(0.2)
        case .zhipu: return .teal.opacity(0.2)
        case .gptproto: return .indigo.opacity(0.2)  // 老王加的
        }
    }

    /// 开始编辑模型
    private func startEditing(model: ModelPreset) {
        editingModel = model
        editModelId = model.modelId
        editDisplayName = model.displayName
        editPlatform = model.platform
        editDescription = model.description ?? ""
        showingEditSheet = true
    }

    // MARK: - 添加模型表单
    private var addModelSheet: some View {
        VStack(spacing: 12) {
            Text("添加自定义模型")
                .font(.headline)

            Form {
                TextField("模型 ID", text: $newModelId)
                    .help("例如: openrouter/custom-model")

                TextField("显示名称", text: $newDisplayName)
                    .help("在菜单中显示的名称")

                Picker("平台", selection: $newPlatform) {
                    ForEach(ModelPlatform.allCases, id: \.self) { platform in
                        Text(platform.rawValue).tag(platform)
                    }
                }

                TextField("描述（可选）", text: $newDescription)
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") {
                    showingAddSheet = false
                    clearForm()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    viewModel.addCustomModel(
                        modelId: newModelId,
                        displayName: newDisplayName.isEmpty ? newModelId : newDisplayName,
                        platform: newPlatform,
                        description: newDescription.isEmpty ? nil : newDescription
                    )
                    showingAddSheet = false
                    clearForm()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newModelId.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 350)
    }

    private func clearForm() {
        newModelId = ""
        newDisplayName = ""
        newPlatform = .openrouter
        newDescription = ""
    }

    // MARK: - 编辑模型表单
    private var editModelSheet: some View {
        VStack(spacing: 12) {
            Text("编辑自定义模型")
                .font(.headline)

            Form {
                TextField("模型 ID", text: $editModelId)
                    .help("例如: openrouter/custom-model")

                TextField("显示名称", text: $editDisplayName)
                    .help("在菜单中显示的名称")

                Picker("平台", selection: $editPlatform) {
                    ForEach(ModelPlatform.allCases, id: \.self) { platform in
                        Text(platform.rawValue).tag(platform)
                    }
                }

                TextField("描述（可选）", text: $editDescription)
            }
            .formStyle(.grouped)

            HStack {
                Button("取消") {
                    showingEditSheet = false
                    editingModel = nil
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    if let original = editingModel {
                        viewModel.updateCustomModel(
                            original,
                            newModelId: editModelId,
                            newDisplayName: editDisplayName,
                            newPlatform: editPlatform,
                            newDescription: editDescription.isEmpty ? nil : editDescription
                        )
                    }
                    showingEditSheet = false
                    editingModel = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editModelId.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

#Preview {
    ModelListView(viewModel: SettingsViewModel())
        .frame(width: 500, height: 400)
}
