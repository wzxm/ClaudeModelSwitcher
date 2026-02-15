//
//  SkillDetailView.swift
//  ClaudeModelSwitcher
//
//  技能文件详情弹窗 - 左侧文件树 + 右侧文件内容预览
//

import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) private var dismiss

    @State private var fileTree: [SkillFile] = []
    @State private var selectedFile: SkillFile? = nil
    @State private var fileContent: String = ""
    @State private var expandedDirs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text(skill.name)
                    .font(.system(size: 16, weight: .semibold))
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

            Divider()

            // 内容区域
            HStack(spacing: 0) {
                // 左侧文件目录树
                fileTreePanel
                    .frame(width: 240)

                Divider()

                // 右侧文件内容预览
                fileContentPanel
            }
        }
        .frame(width: 900, height: 720)
        .onAppear {
            fileTree = skillService.getFileTree(for: skill)
            // 默认选中 SKILL.md
            selectDefaultFile()
        }
    }

    // MARK: - 文件目录树面板

    private var fileTreePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("文件目录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(flattenedFileTree) { entry in
                        flatFileRow(entry: entry)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - 扁平化文件树

    /// 将文件树展开为扁平列表，方便 ForEach 渲染
    private struct FlatFileEntry: Identifiable {
        let id: String
        let file: SkillFile
        let depth: Int
    }

    /// 计算当前可见的扁平文件列表
    private var flattenedFileTree: [FlatFileEntry] {
        var result: [FlatFileEntry] = []
        flattenFiles(fileTree, depth: 0, into: &result)
        return result
    }

    private func flattenFiles(_ files: [SkillFile], depth: Int, into result: inout [FlatFileEntry]) {
        for file in files {
            result.append(FlatFileEntry(id: file.id, file: file, depth: depth))
            if file.isDirectory, expandedDirs.contains(file.id), let children = file.children {
                flattenFiles(children, depth: depth + 1, into: &result)
            }
        }
    }

    /// 单行渲染
    private func flatFileRow(entry: FlatFileEntry) -> some View {
        let file = entry.file
        let depth = entry.depth

        return Button(action: {
            if file.isDirectory {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedDirs.contains(file.id) {
                        expandedDirs.remove(file.id)
                    } else {
                        expandedDirs.insert(file.id)
                    }
                }
            } else {
                selectedFile = file
                fileContent = skillService.readFile(at: file.path) ?? "无法读取文件内容"
            }
        }) {
            HStack(spacing: 6) {
                if depth > 0 {
                    Spacer()
                        .frame(width: CGFloat(depth) * 16)
                }

                if file.isDirectory {
                    Image(systemName: expandedDirs.contains(file.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon(for: file.name))
                    .font(.system(size: 12))
                    .foregroundStyle(fileIconColor(for: file))

                Text(file.name)
                    .font(.system(size: 12))
                    .foregroundStyle(selectedFile?.id == file.id ? .green : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                selectedFile?.id == file.id ?
                Color.green.opacity(0.1) : Color.clear
            )
        }
        .buttonStyle(.plain)
    }


    // MARK: - 文件内容面板

    /// 判断当前选中文件是否为 Markdown
    private var isMarkdownFile: Bool {
        guard let file = selectedFile else { return false }
        return (file.name as NSString).pathExtension.lowercased() == "md"
    }

    private var fileContentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 文件名标签
            HStack {
                if let file = selectedFile {
                    Text(file.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    if isMarkdownFile {
                        Text("Markdown")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                } else {
                    Text("选择一个文件查看内容")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                Spacer()

                // 在 Finder 中打开
                if let file = selectedFile {
                    Button(action: {
                        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("在 Finder 中显示")

                    // 使用默认应用打开
                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("使用默认应用打开")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // 文件内容
            if selectedFile != nil {
                if isMarkdownFile {
                    // Markdown 渲染模式
                    MarkdownRendererView(content: fileContent)
                } else {
                    // 代码原文模式
                    ScrollView([.horizontal, .vertical]) {
                        Text(fileContent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.9))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(16)
                    }
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("选择左侧文件查看内容")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 辅助方法

    /// 默认选中 SKILL.md
    private func selectDefaultFile() {
        for file in fileTree {
            if file.name == "SKILL.md" {
                selectedFile = file
                fileContent = skillService.readFile(at: file.path) ?? ""
                return
            }
        }
        // 没有 SKILL.md 就选第一个文件
        if let first = fileTree.first(where: { !$0.isDirectory }) {
            selectedFile = first
            fileContent = skillService.readFile(at: first.path) ?? ""
        }
    }

    /// 根据文件扩展名返回图标
    private func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return "doc.text.fill"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "sh", "bash", "zsh": return "terminal.fill"
        case "json": return "curlybraces"
        case "yaml", "yml": return "doc.plaintext.fill"
        case "txt": return "doc.plaintext"
        case "swift": return "swift"
        case "js", "ts": return "j.square.fill"
        default: return "doc.fill"
        }
    }

    /// 文件图标颜色
    private func fileIconColor(for file: SkillFile) -> Color {
        if file.isDirectory {
            return .blue
        }
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return .green
        case "py": return .yellow
        case "json": return .orange
        case "sh", "bash": return .pink
        default: return .secondary
        }
    }
}
