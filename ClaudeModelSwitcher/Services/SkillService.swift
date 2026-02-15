//
//  SkillService.swift
//  ClaudeModelSwitcher
//
//  技能管理核心服务，扫描、同步、删除技能
//

import Foundation
import Combine

class SkillService: ObservableObject {
    static let shared = SkillService()

    /// 技能源目录路径
    private let skillsBasePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/skills"
    }()

    @Published var skills: [Skill] = []
    @Published var isLoading = false

    /// 缓存同步状态，避免每次渲染都检查文件系统，老王加的
    @Published private(set) var syncStatusCache: [String: [SyncTarget: SyncStatus]] = [:]

    private let fileManager = FileManager.default
    private let syncQueue = DispatchQueue(label: "com.clademodelswitcher.sync", qos: .userInitiated)

    private init() {
        scanSkills()
    }

    // MARK: - 扫描技能

    /// 扫描 ~/.claude/skills/ 目录获取所有技能
    /// 扫描 ~/.claude/skills/ 目录获取所有技能
    func scanSkills() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            
            guard fileManager.fileExists(atPath: self.skillsBasePath) else {
                DispatchQueue.main.async {
                    self.skills = []
                    self.syncStatusCache = [:]
                    self.isLoading = false
                }
                return
            }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: self.skillsBasePath)
                var foundSkills: [Skill] = []

                for item in contents {
                    let itemPath = "\(self.skillsBasePath)/\(item)"
                    var isDir: ObjCBool = false
                    guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir),
                          isDir.boolValue else { continue }

                    // 跳过隐藏目录
                    guard !item.hasPrefix(".") else { continue }

                    // 检查是否有 SKILL.md
                    let skillMDPath = "\(itemPath)/SKILL.md"
                    let hasSkillMD = fileManager.fileExists(atPath: skillMDPath)
                    
                    // 获取目录创建时间
                    let attrs = try? fileManager.attributesOfItem(atPath: itemPath)
                    let createdDate = attrs?[.creationDate] as? Date ?? Date()

                    // 解析 SKILL.md 获取信息
                    var skillName = item
                    var skillDescription: String? = nil
                    if hasSkillMD {
                        let parsed = self.parseSkillMD(at: skillMDPath)
                        skillName = parsed.name ?? item
                        skillDescription = parsed.description
                    }

                    // 检查是否是 git 仓库或 symlink
                    var sourceType: SkillSourceType = fileManager.fileExists(atPath: "\(itemPath)/.git") ? .git : .local
                    var sourceURL: String? = nil
                    if sourceType == .git {
                        sourceURL = self.getGitRemoteURL(at: itemPath)
                    }

                    // 检查是否为 symlink
                    let resourceValues = try? URL(fileURLWithPath: itemPath).resourceValues(forKeys: [.isSymbolicLinkKey])
                    let isSymlink = resourceValues?.isSymbolicLink ?? false
                    if isSymlink {
                        // symlink 的来源
                        if let resolvedPath = try? fileManager.destinationOfSymbolicLink(atPath: itemPath) {
                            sourceURL = resolvedPath
                        }
                        // symlink 目标通常也是 git 仓库，检查解析后的实际路径
                        if sourceType == .local {
                            let realPath = (itemPath as NSString).resolvingSymlinksInPath
                            if fileManager.fileExists(atPath: "\(realPath)/.git") {
                                sourceType = .git
                                if sourceURL == nil {
                                    sourceURL = self.getGitRemoteURL(at: realPath)
                                }
                            }
                        }
                    }

                    let skill = Skill(
                        id: item,
                        name: skillName,
                        path: itemPath,
                        createdDate: createdDate,
                        sourceType: sourceType,
                        sourceURL: sourceURL,
                        description: skillDescription
                    )
                    foundSkills.append(skill)
                }

                // 按名称排序
                let sortedSkills = foundSkills.sorted { $0.name.lowercased() < $1.name.lowercased() }

                DispatchQueue.main.async {
                    self.skills = sortedSkills
                    // 扫描完成后异步刷新同步状态缓存
                    self.refreshAllSyncStatusCache()
                    self.isLoading = false
                }
            } catch {
                let errorMsg = error.localizedDescription
                DispatchQueue.main.async {
                    print("扫描技能目录失败: \(errorMsg)")
                    self.skills = []
                    self.syncStatusCache = [:]
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - 解析 SKILL.md

    /// 解析 SKILL.md 的 YAML frontmatter
    func parseSkillMD(at path: String) -> (name: String?, description: String?) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return (nil, nil)
        }

        // 检查是否有 YAML frontmatter
        guard content.hasPrefix("---") else {
            return (nil, nil)
        }

        // 提取 frontmatter
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else {
            return (nil, nil)
        }

        let frontmatter = parts[1]
        var name: String? = nil
        var description: String? = nil

        // 简单的 YAML 解析
        let lines = frontmatter.components(separatedBy: .newlines)
        var isMultilineDescription = false
        var descriptionLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
                isMultilineDescription = false
            } else if trimmed.hasPrefix("description:") {
                let value = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                if value == "|" || value == ">" {
                    // 多行描述
                    isMultilineDescription = true
                    descriptionLines = []
                } else {
                    description = value
                    isMultilineDescription = false
                }
            } else if isMultilineDescription {
                if trimmed.isEmpty || (!line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.isEmpty) {
                    // 多行描述结束
                    if !trimmed.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                        isMultilineDescription = false
                    }
                }
                if isMultilineDescription && !trimmed.isEmpty {
                    descriptionLines.append(trimmed)
                }
            }
        }

        if !descriptionLines.isEmpty {
            description = descriptionLines.joined(separator: " ")
        }

        return (name, description)
    }

    // MARK: - 删除技能

    /// 删除技能目录
    func deleteSkill(_ skill: Skill) -> Bool {
        do {
            try fileManager.removeItem(atPath: skill.path)
            skills.removeAll { $0.id == skill.id }
            return true
        } catch {
            print("删除技能失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - 同步技能

    /// 将技能同步到指定目标工具（创建 symlink），异步执行不阻塞主线程
    func syncSkill(_ skill: Skill, to target: SyncTarget, completion: ((Bool) -> Void)? = nil) {
        // Claude Code 本身就是源目录，不需要同步
        if target == .claudeCode {
            DispatchQueue.main.async { completion?(true) }
            return
        }

        // 在后台队列执行文件操作，不阻塞主线程
        syncQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            let targetDir = target.skillsDirectoryPath
            let targetPath = target.skillPath(for: skill.folderName)

            // 确保目标 skills 目录存在
            if !self.fileManager.fileExists(atPath: targetDir) {
                do {
                    try self.fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                } catch {
                    print("创建目标目录失败: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
            }

            // 如果目标已存在，先删除
            if self.fileManager.fileExists(atPath: targetPath) {
                do {
                    try self.fileManager.removeItem(atPath: targetPath)
                } catch {
                    print("删除旧同步失败: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
            }

            // 创建 symlink
            do {
                try self.fileManager.createSymbolicLink(atPath: targetPath, withDestinationPath: skill.path)

                // 更新缓存
                DispatchQueue.main.async {
                    if self.syncStatusCache[skill.id] == nil {
                        self.syncStatusCache[skill.id] = [:]
                    }
                    self.syncStatusCache[skill.id]?[target] = .synced
                    completion?(true)
                }
            } catch {
                print("创建 symlink 失败: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    /// 检查技能在目标工具是否已同步（从缓存读取，不阻塞主线程）
    func getSyncStatus(_ skill: Skill, for target: SyncTarget) -> SyncStatus {
        // Claude Code 是源目录，始终已同步
        if target == .claudeCode {
            return .synced
        }

        // 从缓存读取，没有就返回未同步，然后异步更新缓存
        if let cached = syncStatusCache[skill.id]?[target] {
            return cached
        }

        // 异步更新缓存，下次渲染就能用上了
        refreshSyncStatusCache(for: skill, target: target)
        return .notSynced
    }

    /// 异步刷新单个技能的同步状态缓存
    private func refreshSyncStatusCache(for skill: Skill, target: SyncTarget) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }

            let targetPath = target.skillPath(for: skill.folderName)
            let status: SyncStatus = self.fileManager.fileExists(atPath: targetPath) ? .synced : .notSynced

            DispatchQueue.main.async {
                if self.syncStatusCache[skill.id] == nil {
                    self.syncStatusCache[skill.id] = [:]
                }
                self.syncStatusCache[skill.id]?[target] = status
            }
        }
    }

    /// 刷新所有技能的同步状态缓存
    func refreshAllSyncStatusCache() {
        for skill in skills {
            for target in SyncTarget.allCases {
                refreshSyncStatusCache(for: skill, target: target)
            }
        }
    }

    // MARK: - 文件树

    /// 获取技能目录的文件树
    func getFileTree(for skill: Skill) -> [SkillFile] {
        return buildFileTree(at: skill.path)
    }

    /// 递归构建文件树
    private func buildFileTree(at path: String) -> [SkillFile] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var files: [SkillFile] = []

        for item in contents.sorted() {
            // 跳过隐藏文件
            guard !item.hasPrefix(".") else { continue }
            // 跳过 __pycache__
            guard item != "__pycache__" else { continue }

            let itemPath = "\(path)/\(item)"
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let children = buildFileTree(at: itemPath)
                files.append(SkillFile(name: item, path: itemPath, isDirectory: true, children: children))
            } else {
                let attrs = try? fileManager.attributesOfItem(atPath: itemPath)
                let size = attrs?[.size] as? Int64
                files.append(SkillFile(name: item, path: itemPath, isDirectory: false, fileSize: size))
            }
        }

        return files
    }

    /// 读取文件内容
    func readFile(at path: String) -> String? {
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - 辅助方法

    /// 获取 git 仓库的远程 URL
    private func getGitRemoteURL(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "remote", "get-url", "origin"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// 刷新技能列表
    func refreshSkills() {
        scanSkills()
    }

    // MARK: - 安装技能

    /// 从本地路径安装技能（支持文件夹和 zip 文件）
    func installFromLocal(path: String, skillName: String?, completion: @escaping (Bool, String) -> Void) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            // 确保 skills 目录存在
            if !self.fileManager.fileExists(atPath: self.skillsBasePath) {
                do {
                    try self.fileManager.createDirectory(atPath: self.skillsBasePath, withIntermediateDirectories: true)
                } catch {
                    DispatchQueue.main.async { completion(false, "创建技能目录失败: \(error.localizedDescription)") }
                    return
                }
            }

            var isDir: ObjCBool = false
            guard self.fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
                DispatchQueue.main.async { completion(false, "路径不存在: \(path)") }
                return
            }

            if isDir.boolValue {
                // 文件夹：直接复制
                self.copySkillDirectory(from: path, skillName: skillName, completion: completion)
            } else if path.hasSuffix(".zip") {
                // zip 文件：解压后复制
                self.unzipAndInstall(at: path, skillName: skillName, completion: completion)
            } else {
                DispatchQueue.main.async { completion(false, "不支持的文件类型，请选择文件夹或 .zip 文件") }
            }
        }
    }

    /// 从 Git 仓库安装技能
    func installFromGit(url: String, skillName: String?, completion: @escaping (Bool, String) -> Void) {
        syncQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false, "内部错误") }
                return
            }

            // 确保 skills 目录存在
            if !self.fileManager.fileExists(atPath: self.skillsBasePath) {
                do {
                    try self.fileManager.createDirectory(atPath: self.skillsBasePath, withIntermediateDirectories: true)
                } catch {
                    DispatchQueue.main.async { completion(false, "创建技能目录失败: \(error.localizedDescription)") }
                    return
                }
            }

            // 从 URL 推断技能名称
            let inferredName = skillName ?? self.inferSkillNameFromGitURL(url)
            let targetPath = "\(self.skillsBasePath)/\(inferredName)"

            // 检查是否已存在
            if self.fileManager.fileExists(atPath: targetPath) {
                DispatchQueue.main.async { completion(false, "技能「\(inferredName)」已存在") }
                return
            }

            // 执行 git clone
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["clone", "--depth", "1", url, targetPath]
            process.currentDirectoryURL = URL(fileURLWithPath: self.skillsBasePath)

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    // 克隆成功，刷新列表
                    DispatchQueue.main.async {
                        self.scanSkills()
                        completion(true, "技能「\(inferredName)」安装成功")
                    }
                } else {
                    // 克隆失败
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
                    DispatchQueue.main.async { completion(false, "克隆失败: \(errorMessage)") }
                }
            } catch {
                DispatchQueue.main.async { completion(false, "执行 git clone 失败: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - 安装辅助方法

    /// 复制技能目录
    private func copySkillDirectory(from sourcePath: String, skillName: String?, completion: @escaping (Bool, String) -> Void) {
        // 推断技能名称
        let inferredName = skillName ?? URL(fileURLWithPath: sourcePath).lastPathComponent
        let targetPath = "\(skillsBasePath)/\(inferredName)"

        // 检查是否已存在
        if fileManager.fileExists(atPath: targetPath) {
            DispatchQueue.main.async { completion(false, "技能「\(inferredName)」已存在") }
            return
        }

        // 复制目录
        do {
            try fileManager.copyItem(atPath: sourcePath, toPath: targetPath)
            DispatchQueue.main.async {
                self.scanSkills()
                completion(true, "技能「\(inferredName)」安装成功")
            }
        } catch {
            DispatchQueue.main.async { completion(false, "复制失败: \(error.localizedDescription)") }
        }
    }

    /// 解压 zip 并安装
    private func unzipAndInstall(at zipPath: String, skillName: String?, completion: @escaping (Bool, String) -> Void) {
        // 创建临时目录
        let tempDir = "\(FileManager.default.temporaryDirectory.path)/skill_unzip_\(UUID().uuidString)"

        do {
            try fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        } catch {
            DispatchQueue.main.async { completion(false, "创建临时目录失败") }
            return
        }

        // 使用 unzip 命令解压
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", zipPath, "-d", tempDir]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                DispatchQueue.main.async { completion(false, "解压失败") }
                // 清理临时目录
                try? fileManager.removeItem(atPath: tempDir)
                return
            }

            // 查找解压后的目录
            let contents = try fileManager.contentsOfDirectory(atPath: tempDir)
            let directories = contents.filter { item -> Bool in
                let itemPath = "\(tempDir)/\(item)"
                var isDir: ObjCBool = false
                return fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) && isDir.boolValue
            }

            // 如果只有一个目录，使用它；否则使用 tempDir
            let sourceDir = directories.count == 1 ? "\(tempDir)/\(directories[0])" : tempDir

            // 复制到 skills 目录
            let inferredName = skillName ?? URL(fileURLWithPath: sourceDir).lastPathComponent
            let targetPath = "\(skillsBasePath)/\(inferredName)"

            if fileManager.fileExists(atPath: targetPath) {
                DispatchQueue.main.async { completion(false, "技能「\(inferredName)」已存在") }
                try? fileManager.removeItem(atPath: tempDir)
                return
            }

            try fileManager.copyItem(atPath: sourceDir, toPath: targetPath)

            // 清理临时目录
            try? fileManager.removeItem(atPath: tempDir)

            DispatchQueue.main.async {
                self.scanSkills()
                completion(true, "技能「\(inferredName)」安装成功")
            }
        } catch {
            // 清理临时目录
            try? fileManager.removeItem(atPath: tempDir)
            DispatchQueue.main.async { completion(false, "安装失败: \(error.localizedDescription)") }
        }
    }

    /// 从 Git URL 推断技能名称
    private func inferSkillNameFromGitURL(_ url: String) -> String {
        // 提取最后一个路径组件，去掉 .git 后缀
        var name = URL(string: url)?.lastPathComponent ?? url
        if name.hasSuffix(".git") {
            name = String(name.dropLast(4))
        }
        // 清理特殊字符
        return name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "-", options: .regularExpression)
    }

    // MARK: - npx skills CLI 集成

    /// 通用 npx skills 命令执行器
    private func runNpxSkillsCommand(args: [String], completion: @escaping (Bool, String) -> Void) {
        syncQueue.async {
            let process = Process()
            // 查找 npx 路径
            let npxPath = self.findNpxPath()
            process.executableURL = URL(fileURLWithPath: npxPath)
            process.arguments = ["-y", "skills"] + args

            let fullCommand = "\(npxPath) -y skills \(args.joined(separator: " "))"
            print("[SkillService] 执行命令: \(fullCommand)")
            print("[SkillService] npx 路径: \(npxPath)")

            // 设置 PATH 环境变量，确保能找到 node/npm
            var env = ProcessInfo.processInfo.environment
            let additionalPaths = [
                "/usr/local/bin",
                "/opt/homebrew/bin",
                "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/*/bin",
                "\(FileManager.default.homeDirectoryForCurrentUser.path)/.volta/bin"
            ]
            if let existingPath = env["PATH"] {
                env["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
            }
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errOutput = String(data: errData, encoding: .utf8) ?? ""

                print("[SkillService] 命令退出码: \(process.terminationStatus)")
                if !output.isEmpty {
                    print("[SkillService] stdout: \(output)")
                }
                if !errOutput.isEmpty {
                    print("[SkillService] stderr: \(errOutput)")
                }

                if process.terminationStatus == 0 {
                    DispatchQueue.main.async { completion(true, output) }
                } else {
                    print("[SkillService] ❌ 命令失败: \(errOutput)")
                    DispatchQueue.main.async { completion(false, errOutput) }
                }
            } catch {
                print("[SkillService] ❌ 执行异常: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false, "执行命令失败: \(error.localizedDescription)") }
            }
        }
    }

    /// 查找 npx 可执行文件路径
    private func findNpxPath() -> String {
        let candidates = [
            "/usr/local/bin/npx",
            "/opt/homebrew/bin/npx",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.volta/bin/npx",
        ]
        for path in candidates {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
        // 尝试通过 which 查找
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["npx"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !result.isEmpty { return result }
        } catch {}
        return "/usr/local/bin/npx"
    }

    /// 搜索技能（npx skills find <query>）
    func searchSkills(query: String, completion: @escaping (Bool, [SkillSearchResult], String) -> Void) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(false, [], "请输入搜索关键词")
            return
        }

        runNpxSkillsCommand(args: ["find", query]) { success, output in
            guard success else {
                completion(false, [], output)
                return
            }

            // 清除 ANSI 转义码（颜色等控制字符）
            let cleanOutput = output.replacingOccurrences(
                of: "\u{1B}\\[[0-9;]*m",
                with: "",
                options: .regularExpression
            )

            // 解析输出格式：
            // vercel-labs/agent-skills@vercel-react-best-practices
            // └ https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices
            let lines = cleanOutput.components(separatedBy: .newlines)
            var results: [SkillSearchResult] = []

            var i = 0
            while i < lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespaces)

                // 匹配 owner/repo@skill 格式的行
                if line.contains("@") && line.contains("/") && !line.hasPrefix("└") && !line.hasPrefix("Install") && !line.contains("╗") && !line.contains("║") && !line.contains("╚") && !line.isEmpty {
                    let packageId = line
                    var url = ""

                    // 下一行应该是 URL
                    if i + 1 < lines.count {
                        let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                        if nextLine.hasPrefix("└") {
                            url = nextLine
                                .replacingOccurrences(of: "└", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            i += 1
                        }
                    }

                    // 解析 owner/repo 和 skill name
                    let parts = packageId.components(separatedBy: "@")
                    let ownerRepo = parts.first ?? ""
                    let skillName = parts.count > 1 ? parts[1] : packageId

                    results.append(SkillSearchResult(
                        id: packageId,
                        name: skillName,
                        owner: ownerRepo,
                        url: url
                    ))
                }
                i += 1
            }

            completion(true, results, results.isEmpty ? "未找到相关技能" : "")
        }
    }

    /// 从注册表安装技能（npx skills add <package>）
    func addSkillFromRegistry(package: String, completion: @escaping (Bool, String) -> Void) {
        print("[SkillService] 开始安装技能: \(package)")
        runNpxSkillsCommand(args: ["add", package, "-g", "--agent", "claude-code", "-y"]) { success, output in
            if success {
                print("[SkillService] ✅ 技能安装成功: \(package)")
                // 安装成功后刷新技能列表
                self.scanSkills()
                completion(true, "技能「\(package)」安装成功")
            } else {
                print("[SkillService] ❌ 技能安装失败: \(package), 原因: \(output)")
                completion(false, "安装失败: \(output)")
            }
        }
    }

    /// 检查技能更新（npx skills check）
    func checkSkillUpdates(completion: @escaping (Bool, String) -> Void) {
        runNpxSkillsCommand(args: ["check"]) { success, output in
            completion(success, success ? output : "检查更新失败: \(output)")
        }
    }

    /// 更新所有技能（npx skills update）
    func updateAllSkills(completion: @escaping (Bool, String) -> Void) {
        runNpxSkillsCommand(args: ["update"]) { success, output in
            if success {
                self.scanSkills()
                completion(true, "技能更新完成")
            } else {
                completion(false, "更新失败: \(output)")
            }
        }
    }
}
