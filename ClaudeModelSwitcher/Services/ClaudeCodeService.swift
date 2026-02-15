//
//  ClaudeCodeService.swift
//  ClaudeModelSwitcher
//
//  Claude Code CLI 安装/卸载/更新服务
//  老王加了个版本检查功能，定时去看有没有新版本，别tm用老版本
//

import Foundation
import Combine

/// Claude Code 服务错误类型
enum ClaudeCodeServiceError: LocalizedError {
    case npmNotInstalled
    case installFailed(String)
    case uninstallFailed(String)
    case updateFailed(String)
    case versionCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case .npmNotInstalled:
            return "npm 未安装，请先安装 Node.js"
        case .installFailed(let message):
            return "安装失败：\(message)"
        case .uninstallFailed(let message):
            return "卸载失败：\(message)"
        case .updateFailed(let message):
            return "更新失败：\(message)"
        case .versionCheckFailed(let message):
            return "版本检查失败：\(message)"
        }
    }
}

/// Claude Code CLI 服务 - 负责安装、卸载、检测、更新
class ClaudeCodeService: ObservableObject {
    static let shared = ClaudeCodeService()

    // MARK: - Published Properties

    /// 是否已安装
    @Published private(set) var isInstalled: Bool = false

    /// 安装的版本号
    @Published private(set) var version: String?

    /// npm 上的最新版本号
    @Published private(set) var latestVersion: String?

    /// 是否有可用更新（当前版本和最新版本不同时为 true）
    @Published private(set) var hasUpdate: Bool = false

    /// 是否正在检查版本
    @Published private(set) var isCheckingVersion: Bool = false

    /// 是否正在处理中
    @Published private(set) var isProcessing: Bool = false

    /// 输出日志
    @Published var outputLog: String = ""

    /// 错误信息
    @Published var errorMessage: String?

    /// npm 是否已安装
    @Published private(set) var isNpmAvailable: Bool = false

    // MARK: - Private Properties

    private var process: Process?
    /// 用户默认 shell，用于正确加载 nvm/fnm 等环境
    private let userShell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    /// 定时检查版本的 Timer，老王硬性规定每 4 小时检查一次
    private var versionCheckTimer: Timer?
    /// 版本检查间隔（秒），默认 4 小时
    private let versionCheckInterval: TimeInterval = 4 * 60 * 60

    // MARK: - Initialization

    private init() {
        checkNpmAvailability()
        checkInstallation()
        // 启动时检查一下最新版本
        Task {
            await checkLatestVersion()
        }
        // 启动定时检查
        startVersionCheckTimer()
    }

    deinit {
        versionCheckTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// 检查 npm 是否可用
    func checkNpmAvailability() {
        var available = false
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [userShell, "-l", "-c", "which npm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            available = task.terminationStatus == 0
        } catch {
            available = false
        }

        DispatchQueue.main.async {
            self.isNpmAvailable = available
        }
    }

    /// 检查 Claude Code 安装状态
    func checkInstallation() {
        var installed = false
        var detectedVersion: String?

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [userShell, "-l", "-c", "which claude"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    if let v = getVersion(at: path) {
                        installed = true
                        detectedVersion = v
                    }
                }
            }
        } catch {
            print("检查安装状态失败: \(error)")
        }

        DispatchQueue.main.async {
            self.isInstalled = installed
            self.version = detectedVersion
            self.updateHasUpdateStatus()
        }
    }

    /// 检查 npm 上的最新版本（老王专门加的，让你知道有没有新版本）
    func checkLatestVersion() async {
        guard isNpmAvailable else { return }

        await MainActor.run {
            isCheckingVersion = true
        }

        do {
            let latest = try await fetchLatestVersionFromNpm()
            await MainActor.run {
                self.latestVersion = latest
                self.updateHasUpdateStatus()
                self.isCheckingVersion = false
            }
        } catch {
            await MainActor.run {
                self.isCheckingVersion = false
                print("检查最新版本失败: \(error)")
            }
        }
    }

    /// 更新 Claude Code 到最新版本（老王推荐的更新方式）
    func update() async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            outputLog = "开始更新 Claude Code CLI...\n"
        }

        do {
            // 1. 检查 npm
            guard isNpmAvailable else {
                throw ClaudeCodeServiceError.npmNotInstalled
            }

            // 2. 执行更新
            await appendLog("正在更新 @anthropic-ai/claude-code...")
            try await runNpmUpdate()

            // 3. 检查更新结果
            await appendLog("验证更新...")
            checkInstallation()

            // 4. 重新检查最新版本
            await checkLatestVersion()

            if isInstalled {
                await appendLog("✅ 更新成功！当前版本: \(version ?? "未知")")
            } else {
                throw ClaudeCodeServiceError.updateFailed("更新后未能检测到 claude 命令")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                outputLog += "\n❌ \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    /// 安装 Claude Code
    func install() async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            outputLog = "开始安装 Claude Code CLI...\n"
        }

        do {
            // 1. 检查 npm
            guard isNpmAvailable else {
                throw ClaudeCodeServiceError.npmNotInstalled
            }

            // 2. 执行安装
            await appendLog("正在安装 @anthropic-ai/claude-code...")
            try await runNpmInstall()

            // 3. 检查安装结果
            await appendLog("验证安装...")
            checkInstallation()

            if isInstalled {
                await appendLog("✅ 安装成功！版本: \(version ?? "未知")")
            } else {
                throw ClaudeCodeServiceError.installFailed("安装后未能检测到 claude 命令")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                outputLog += "\n❌ \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    /// 卸载 Claude Code
    func uninstall() async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            outputLog = "开始卸载 Claude Code CLI...\n"
        }

        do {
            await appendLog("正在卸载 @anthropic-ai/claude-code...")
            try await runNpmUninstall()

            await appendLog("验证卸载...")
            checkInstallation()

            if !isInstalled {
                await appendLog("✅ 卸载成功！")
            } else {
                throw ClaudeCodeServiceError.uninstallFailed("卸载后仍能检测到 claude 命令")
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                outputLog += "\n❌ \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    // MARK: - Private Methods

    /// 获取指定路径的 claude 版本
    private func getVersion(at path: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [userShell, "-l", "-c", "'\(path)' --version 2>/dev/null || echo ''"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {
            print("获取版本失败: \(error)")
        }

        return nil
    }

    /// 从 npm 获取最新版本号（老王这个SB方法专门用来查最新版本）
    private func fetchLatestVersionFromNpm() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [userShell, "-l", "-c", "npm view @anthropic-ai/claude-code version 2>/dev/null"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            task.terminationHandler = { _ in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ClaudeCodeServiceError.versionCheckFailed("无法获取最新版本号"))
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: ClaudeCodeServiceError.versionCheckFailed(error.localizedDescription))
            }
        }
    }

    /// 更新 hasUpdate 状态（比较当前版本和最新版本）
    private func updateHasUpdateStatus() {
        let update = {
            guard let current = self.version, let latest = self.latestVersion else {
                self.hasUpdate = false
                return
            }
            // 提取纯版本号比较，因为 claude --version 返回类似 "2.1.39 (Claude Code)"
            // 而 npm view 返回的是 "2.1.39"
            let currentClean = self.extractVersionNumber(from: current)
            let latestClean = self.extractVersionNumber(from: latest)
            self.hasUpdate = (currentClean != latestClean)
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async {
                update()
            }
        }
    }

    /// 从版本字符串中提取纯版本号（去掉后缀如 " (Claude Code)"）
    private func extractVersionNumber(from versionString: String) -> String {
        // 匹配类似 "1.2.3" 的版本号模式
        let components = versionString.split(separator: " ")
        if let first = components.first {
            return String(first)
        }
        return versionString
    }

    /// 启动定时检查版本的 Timer
    private func startVersionCheckTimer() {
        versionCheckTimer?.invalidate()
        versionCheckTimer = Timer.scheduledTimer(withTimeInterval: versionCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkLatestVersion()
            }
        }
    }

    /// 手动触发检查更新（用户点了刷新按钮）
    func manualCheckUpdate() async {
        await checkLatestVersion()
        checkInstallation()
    }

    /// 执行 npm install
    private func runNpmInstall() async throws {
        try await runProcess(
            executable: "/usr/bin/env",
            arguments: [userShell, "-l", "-c", "npm install -g @anthropic-ai/claude-code"]
        )
    }

    /// 执行 npm uninstall
    private func runNpmUninstall() async throws {
        try await runProcess(
            executable: "/usr/bin/env",
            arguments: [userShell, "-l", "-c", "npm uninstall -g @anthropic-ai/claude-code"]
        )
    }

    /// 执行 npm update（老王专门加的更新命令）
    private func runNpmUpdate() async throws {
        try await runProcess(
            executable: "/usr/bin/env",
            arguments: [userShell, "-l", "-c", "npm update -g @anthropic-ai/claude-code"]
        )
    }

    /// 通用进程执行方法
    private func runProcess(executable: String, arguments: [String]) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: executable)
            task.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            // 实时输出
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    Task { @MainActor in
                        self?.outputLog += output
                    }
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    Task { @MainActor in
                        self?.outputLog += output
                    }
                }
            }

            task.terminationHandler = { task in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if task.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"

                    // 判断是安装、卸载还是更新，老王这逻辑很清晰
                    if arguments.contains("install") {
                        continuation.resume(throwing: ClaudeCodeServiceError.installFailed(errorMessage))
                    } else if arguments.contains("update") {
                        continuation.resume(throwing: ClaudeCodeServiceError.updateFailed(errorMessage))
                    } else {
                        continuation.resume(throwing: ClaudeCodeServiceError.uninstallFailed(errorMessage))
                    }
                } else {
                    continuation.resume()
                }
            }

            do {
                try task.run()
                self.process = task
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// 追加日志
    private func appendLog(_ message: String) async {
        await MainActor.run {
            outputLog += "\n\(message)"
        }
    }

    /// 取消当前操作
    func cancel() {
        process?.terminate()
        process = nil
        Task { @MainActor in
            isProcessing = false
            outputLog += "\n操作已取消"
        }
    }
}
