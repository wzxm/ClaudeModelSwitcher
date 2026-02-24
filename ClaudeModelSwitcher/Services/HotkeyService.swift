//
//  HotkeyService.swift
//  ClaudeModelSwitcher
//
//  全局快捷键服务，老王专门加的功能
//  使用 Carbon API 实现全局快捷键，艹，虽然是老 API 但稳定可靠
//

import Foundation
import Carbon
import AppKit

/// 快捷键标识
enum HotkeyAction: String, CaseIterable {
    case nextModel = "nextModel"       // 切换下一个模型
    case prevModel = "prevModel"       // 切换上一个模型
    case openSettings = "openSettings" // 打开设置窗口
    case recentModel = "recentModel"   // 切换到最近使用的模型

    var displayName: String {
        switch self {
        case .nextModel: return "下一个模型"
        case .prevModel: return "上一个模型"
        case .openSettings: return "打开设置"
        case .recentModel: return "最近使用的模型"
        }
    }

    var defaultShortcut: String {
        switch self {
        case .nextModel: return "⌘ + ⇧ + M"
        case .prevModel: return "⌘ + ⇧ + N"
        case .openSettings: return "⌘ + ⇧ + S"
        case .recentModel: return "⌘ + ⇧ + R"
        }
    }
}

/// 全局快捷键服务
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()

    // MARK: - Published 属性

    /// 是否启用快捷键
    @Published var enabled: Bool = true

    /// 快捷键配置（存储格式: "⌘⇧M" 这样的显示格式）
    @Published var shortcuts: [HotkeyAction: String] = [:]

    // MARK: - 私有属性

    private var hotkeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private let configService = ConfigService.shared

    // MARK: - 初始化

    private init() {
        loadShortcuts()
    }

    // MARK: - 公开方法

    /// 启动快捷键监听
    func start() {
        guard enabled else { return }
        registerAllHotkeys()
    }

    /// 停止快捷键监听
    func stop() {
        unregisterAllHotkeys()
    }

    /// 重新注册快捷键（配置变化后调用）
    func reload() {
        unregisterAllHotkeys()
        if enabled {
            registerAllHotkeys()
        }
    }

    /// 更新快捷键配置
    func updateShortcut(_ action: HotkeyAction, shortcut: String) {
        shortcuts[action] = shortcut
        saveShortcuts()
        reload()
    }

    /// 更新启用状态
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: "hotkeyEnabled")
        if enabled {
            registerAllHotkeys()
        } else {
            unregisterAllHotkeys()
        }
    }

    // MARK: - 私有方法

    /// 加载快捷键配置
    private func loadShortcuts() {
        enabled = UserDefaults.standard.bool(forKey: "hotkeyEnabled")
        // 首次使用默认为启用
        if !UserDefaults.standard.bool(forKey: "hotkeyConfigured") {
            enabled = true
            UserDefaults.standard.set(true, forKey: "hotkeyEnabled")
            UserDefaults.standard.set(true, forKey: "hotkeyConfigured")
        }

        // 加载快捷键配置，没有就用默认值
        for action in HotkeyAction.allCases {
            if let saved = UserDefaults.standard.string(forKey: "hotkey_\(action.rawValue)") {
                shortcuts[action] = saved
            } else {
                shortcuts[action] = action.defaultShortcut
            }
        }
    }

    /// 保存快捷键配置
    private func saveShortcuts() {
        for (action, shortcut) in shortcuts {
            UserDefaults.standard.set(shortcut, forKey: "hotkey_\(action.rawValue)")
        }
    }

    /// 注册所有快捷键
    private func registerAllHotkeys() {
        // 先注册事件处理器
        registerEventHandler()

        for (action, shortcut) in shortcuts {
            if let (keyCode, modifiers) = parseShortcut(shortcut) {
                registerHotkey(action: action, keyCode: keyCode, modifiers: modifiers)
            }
        }
    }

    /// 注销所有快捷键
    private func unregisterAllHotkeys() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    /// 注册单个快捷键
    private func registerHotkey(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) {
        var hotkeyRef: EventHotKeyRef?

        let prefix = String(action.rawValue.prefix(4))
        let signature = prefix.fourCharCode

        // 艹，hashValue 可能是负数或超大，直接转会崩溃！用取模限制范围
        let idValue = UInt32(truncatingIfNeeded: action.hashValue & 0xFFFFFFFF)
        let hotkeyID = EventHotKeyID(
            signature: OSType(signature),
            id: idValue
        )

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs[action] = ref
        } else {
            print("注册快捷键失败: \(action.displayName), 状态码: \(status)")
        }
    }

    /// 注册事件处理器
    private func registerEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // 艹，这个 callback 老王用闭包封装，避免裸指针太恶心
        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()

            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            if status == noErr {
                service.handleHotkey(id: hotkeyID)
            }

            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    /// 处理快捷键按下事件
    private func handleHotkey(id: EventHotKeyID) {
        // 根据签名找到对应的 action
        let action = HotkeyAction.allCases.first { (action: HotkeyAction) -> Bool in
            let prefix = String(action.rawValue.prefix(4))
            return OSType(prefix.fourCharCode) == id.signature
        }

        guard let foundAction = action else { return }

        // 在主线程执行操作
        DispatchQueue.main.async { [weak self] in
            self?.performAction(foundAction)
        }
    }

    /// 执行快捷键动作
    private func performAction(_ action: HotkeyAction) {
        switch action {
        case .nextModel:
            switchToNextModel()

        case .prevModel:
            switchToPrevModel()

        case .openSettings:
            openSettings()

        case .recentModel:
            switchToRecentModel()
        }
    }

    /// 切换到下一个模型
    private func switchToNextModel() {
        let allModels = getAllModels()
        let currentModel = configService.currentConfig?.currentModel
        let currentPlatform = configService.currentConfig?.currentPlatform

        guard let currentIndex = allModels.firstIndex(where: {
            $0.modelId == currentModel && $0.platform == currentPlatform
        }) else {
            // 当前模型不在列表中，切换到第一个
            if let first = allModels.first {
                try? configService.switchModel(to: first)
                showNotification(title: "模型已切换", message: first.displayName)
            }
            return
        }

        // 切换到下一个（循环）
        let nextIndex = (currentIndex + 1) % allModels.count
        let nextModel = allModels[nextIndex]
        try? configService.switchModel(to: nextModel)
        showNotification(title: "模型已切换", message: nextModel.displayName)
    }

    /// 切换到上一个模型
    private func switchToPrevModel() {
        let allModels = getAllModels()
        let currentModel = configService.currentConfig?.currentModel
        let currentPlatform = configService.currentConfig?.currentPlatform

        guard let currentIndex = allModels.firstIndex(where: {
            $0.modelId == currentModel && $0.platform == currentPlatform
        }) else {
            // 当前模型不在列表中，切换到最后一个
            if let last = allModels.last {
                try? configService.switchModel(to: last)
                showNotification(title: "模型已切换", message: last.displayName)
            }
            return
        }

        // 切换到上一个（循环）
        let prevIndex = (currentIndex - 1 + allModels.count) % allModels.count
        let prevModel = allModels[prevIndex]
        try? configService.switchModel(to: prevModel)
        showNotification(title: "模型已切换", message: prevModel.displayName)
    }

    /// 打开设置窗口
    private func openSettings() {
        // 发送通知，让 AppDelegate 打开设置窗口
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
    }

    /// 切换到最近使用的模型
    private func switchToRecentModel() {
        let recentModels = AppConfig.shared.recentModels

        guard let firstRecent = recentModels.first else {
            showNotification(title: "无法切换", message: "没有最近使用的模型")
            return
        }

        // 查找对应的 ModelPreset
        let allModels = getAllModels()
        if let model = allModels.first(where: { $0.modelId == firstRecent }) {
            try? configService.switchModel(to: model)
            showNotification(title: "模型已切换", message: model.displayName)
        }
    }

    /// 获取所有模型列表
    private func getAllModels() -> [ModelPreset] {
        var allModels: [ModelPreset] = []

        for platform in ModelPlatform.allCases {
            allModels.append(contentsOf: ModelPresets.presets(for: platform))
        }

        // 添加自定义模型
        allModels.append(contentsOf: AppConfig.shared.customModels)

        return allModels
    }

    /// 显示通知（使用系统通知风格的弹窗）
    private func showNotification(title: String, message: String) {
        // 发送通知，让 AppDelegate 显示 Toast
        NotificationCenter.default.post(
            name: .showToast,
            object: nil,
            userInfo: ["title": title, "message": message]
        )
    }

    /// 解析快捷键字符串
    /// - Parameter shortcut: 快捷键字符串，如 "⌘⇧M"
    /// - Returns: (keyCode, modifiers)
    private func parseShortcut(_ shortcut: String) -> (UInt32, UInt32)? {
        var modifiers: UInt32 = 0
        var key: Character?

        for char in shortcut {
            switch char {
            case "⌘":
                modifiers |= UInt32(cmdKey)
            case "⇧":
                modifiers |= UInt32(shiftKey)
            case "⌥":
                modifiers |= UInt32(optionKey)
            case "⌃":
                modifiers |= UInt32(controlKey)
            default:
                key = char
            }
        }

        guard let keyCode = key?.keyCode else { return nil }
        return (keyCode, modifiers)
    }
}

// MARK: - 扩展

extension String {
    /// 将字符串转换为 FourCharCode
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8 {
            result = (result << 8) | FourCharCode(char)
        }
        return result
    }
}

extension Character {
    /// 获取字符对应的键码
    var keyCode: UInt32? {
        switch self.uppercased() {
        case "A": return 0x00
        case "S": return 0x01
        case "D": return 0x02
        case "F": return 0x03
        case "H": return 0x04
        case "G": return 0x05
        case "Z": return 0x06
        case "X": return 0x07
        case "C": return 0x08
        case "V": return 0x09
        case "B": return 0x0B
        case "Q": return 0x0C
        case "W": return 0x0D
        case "E": return 0x0E
        case "R": return 0x0F
        case "Y": return 0x10
        case "T": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "O": return 0x1F
        case "U": return 0x20
        case "[": return 0x21
        case "I": return 0x22
        case "P": return 0x23
        case "L": return 0x25
        case "J": return 0x26
        case "'": return 0x27
        case "K": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "N": return 0x2D
        case "M": return 0x2E
        case ".": return 0x2F
        case "`": return 0x32
        case " ": return 0x31
        default: return nil
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let showToast = Notification.Name("showToast")
}
