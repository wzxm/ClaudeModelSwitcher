//
//  ClaudeModelSwitcherApp.swift
//  ClaudeModelSwitcher
//
//  应用入口，老王的心血之作
//

import SwiftUI
import Combine

@main
struct ClaudeModelSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 菜单栏应用不需要默认 Scene，空着就行
        Settings {
            EmptyView()
        }
    }
}

/// 应用代理 - 管理菜单栏图标和设置窗口
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuBarView: NSHostingController<MenuBarView>?

    // 设置窗口控制器，老王手动管理，不让 SwiftUI 乱来
    private var settingsWindowController: NSWindowController?

    // Claude Code 管理窗口控制器
    private var claudeCodeWindowController: NSWindowController?

    // 扩展管理窗口控制器（包含技能和 MCP）
    private var extensionManagerWindowController: NSWindowController?

    // 菜单栏应用：关闭所有窗口也不退出，老王硬性规定！
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        setupStatusBar()

        // 应用主题设置，老王专门加的
        AppConfig.shared.applyTheme()

        // 如果设置了开机自启动，注册一下
        _ = AppConfig.shared.launchAtLogin

        // 监听自定义模型变化，刷新菜单
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCustomModelsChange),
            name: .customModelsDidChange,
            object: nil
        )

        // 订阅 ClaudeCodeService 的版本更新状态变化，老王专门加的
        setupClaudeCodeObserver()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
    }

    // MARK: - 设置窗口管理

    /// 创建设置窗口（懒加载）
    private func createSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "设置"
        window.center()
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false  // 关闭不销毁，可以重复打开
        window.minSize = NSSize(width: 650, height: 450)

        // 用 NSHostingController 包装 SwiftUI 视图
        let hostingController = NSHostingController(rootView: SettingsView())
        window.contentViewController = hostingController

        return window
    }

    /// 获取或创建设置窗口控制器
    private func getOrCreateSettingsWindowController() -> NSWindowController {
        if let controller = settingsWindowController {
            return controller
        }

        let window = createSettingsWindow()
        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        return controller
    }

    /// 创建 Claude Code 管理窗口
    private func createClaudeCodeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Claude Code 管理"
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        let hostingController = NSHostingController(rootView: ClaudeCodeManagementView())
        window.contentViewController = hostingController

        // 居中必须在设置 contentViewController 之后调用，确保基于最终窗口大小计算居中位置
        window.center()

        return window
    }

    /// 获取或创建 Claude Code 管理窗口控制器
    private func getOrCreateClaudeCodeWindowController() -> NSWindowController {
        if let controller = claudeCodeWindowController {
            return controller
        }

        let window = createClaudeCodeWindow()
        let controller = NSWindowController(window: window)
        claudeCodeWindowController = controller
        return controller
    }

    /// 创建扩展管理窗口（包含技能和 MCP）
    private func createExtensionManagerWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 950, height: 650),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "扩展管理"
        window.center()
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 500)

        let hostingController = NSHostingController(rootView: SkillManagerView())
        window.contentViewController = hostingController

        return window
    }

    /// 获取或创建扩展管理窗口控制器
    private func getOrCreateExtensionManagerWindowController() -> NSWindowController {
        if let controller = extensionManagerWindowController {
            return controller
        }

        let window = createExtensionManagerWindow()
        let controller = NSWindowController(window: window)
        extensionManagerWindowController = controller
        return controller
    }

    // MARK: - 菜单栏设置

    private func setupStatusBar() {
        // 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // 设置图标 - 使用 SF Symbols
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Claude Model")
            button.image?.isTemplate = true // 适配深色/浅色模式

            // 创建菜单
            let menu = createMenu()
            statusItem?.menu = menu
        }
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // 1. 顶部当前模型状态 (自定义视图)
        let headerItem = NSMenuItem()
        let headerView = NSHostingView(rootView: CurrentModelView())
        headerView.frame = NSRect(x: 0, y: 0, width: 220, height: 32)
        headerItem.view = headerView
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // 2. 添加各平台子菜单
        addPlatformMenu(to: menu, platform: .anthropic, title: "Anthropic 官方")
        addPlatformMenu(to: menu, platform: .openrouter, title: "OpenRouter")
        addPlatformMenu(to: menu, platform: .siliconflow, title: "SiliconFlow")
        addPlatformMenu(to: menu, platform: .volcano, title: "火山引擎")
        addPlatformMenu(to: menu, platform: .zai, title: "Z.ai")
        addPlatformMenu(to: menu, platform: .zhipu, title: "智谱AI")
        addPlatformMenu(to: menu, platform: .gptproto, title: "GPT Proto")  // 老王加的

        // 添加自定义模型（如果有）
        if !AppConfig.shared.customModels.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let customMenu = NSMenu()
            for model in AppConfig.shared.customModels {
                let item = createModelMenuItem(preset: model)
                customMenu.addItem(item)
            }
            let customItem = NSMenuItem(title: "自定义模型", action: nil, keyEquivalent: "")
            customItem.submenu = customMenu
            menu.addItem(customItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Claude Code 管理
        let claudeCodeService = ClaudeCodeService.shared
        let hasUpdate = claudeCodeService.hasUpdate && claudeCodeService.isInstalled
        let claudeCodeTitle = hasUpdate ? "Claude Code 管理... (有新版本)" : "Claude Code 管理..."
        let claudeCodeItem = NSMenuItem(
            title: claudeCodeTitle,
            action: #selector(openClaudeCodeManagement),
            keyEquivalent: ""
        )
        claudeCodeItem.target = self
        // 根据状态显示不同图标
        if hasUpdate {
            claudeCodeItem.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "有更新")
        } else {
            claudeCodeItem.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Claude Code")
        }
        menu.addItem(claudeCodeItem)

        // 4. 扩展管理（技能 + MCP）
        let extensionManagerItem = NSMenuItem(
            title: "扩展管理...",
            action: #selector(openExtensionManager),
            keyEquivalent: ""
        )
        extensionManagerItem.target = self
        extensionManagerItem.image = NSImage(systemSymbolName: "puzzlepiece.extension", accessibilityDescription: "扩展管理")
        menu.addItem(extensionManagerItem)
        
        // 5. 设置
        addSettingsItem(to: menu)

        menu.addItem(NSMenuItem.separator())

        // 6. 关于
        let aboutItem = NSMenuItem(
            title: "关于 Claude Model Switcher",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 7. 退出
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// 添加平台子菜单
    private func addPlatformMenu(to menu: NSMenu, platform: ModelPlatform, title: String) {
        let platformMenu = NSMenu()
        let models = ModelPresets.presets(for: platform)
        let currentConfig = ConfigService.shared.currentConfig
        let currentModelId = currentConfig?.currentModel
        let currentPlatform = currentConfig?.currentPlatform

        var isPlatformSelected = false
        for model in models {
            let item = createModelMenuItem(preset: model)
            platformMenu.addItem(item)
            
            if model.modelId == currentModelId && platform == currentPlatform {
                isPlatformSelected = true
            }
        }

        let platformItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        platformItem.submenu = platformMenu
        
        if isPlatformSelected {
            platformItem.state = .on
        }
        
        menu.addItem(platformItem)
    }

    private func addSettingsItem(to menu: NSMenu) {
        let settingsItem = NSMenuItem(
            title: "系统设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
    }

    private func createModelMenuItem(preset: ModelPreset) -> NSMenuItem {
        let currentConfig = ConfigService.shared.currentConfig
        let currentModel = currentConfig?.currentModel
        let currentPlatform = currentConfig?.currentPlatform
        
        // 只有模型ID和平台都匹配才算选中
        let isSelected = (currentModel == preset.modelId) && (currentPlatform == preset.platform)

        let item = NSMenuItem(
            title: preset.displayName,
            action: #selector(switchModel(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = preset

        if isSelected {
            item.state = .on
        }

        if let desc = preset.description {
            item.toolTip = desc
        }

        return item
    }

    // MARK: - Actions

    @objc private func switchModel(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? ModelPreset else { return }

        do {
            try ConfigService.shared.switchModel(to: preset)
            updateMenu()
        } catch {
            print("切换模型失败: \(error.localizedDescription)")
        }
    }

    @objc private func openClaudeCodeManagement() {
        let controller = getOrCreateClaudeCodeWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openExtensionManager() {
        let controller = getOrCreateExtensionManagerWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        let controller = getOrCreateSettingsWindowController()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    /// 自定义模型变化时刷新菜单
    @objc private func handleCustomModelsChange() {
        updateMenu()
    }

    private func updateMenu() {
        statusItem?.menu = createMenu()
    }

    /// 设置 Claude Code 服务观察者，老王用来监听版本更新状态
    private var claudeCodeCancellables = Set<AnyCancellable>()

    private func setupClaudeCodeObserver() {
        // 监听 hasUpdate 属性变化，有更新就刷新菜单
        ClaudeCodeService.shared.$hasUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &claudeCodeCancellables)
    }
}

/// 菜单栏顶部的当前模型显示视图
struct CurrentModelView: View {
    @ObservedObject var configService = ConfigService.shared

    var body: some View {
        HStack(spacing: 4) {
            Text("当前:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(configService.currentModelName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 220, alignment: .leading)
        .background(Color(nsColor: .separatorColor).opacity(0.1))
    }
}
