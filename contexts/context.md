# Claude Model Switcher 项目上下文

## 项目简介

Claude Model Switcher 是一个 macOS 菜单栏应用，旨在帮助用户快速在 Claude Code 工具的不同模型配置之间切换。它直接修改 `~/.claude/settings.json` 文件，支持 Anthropic 官方模型和 OpenRouter 模型。

## 技术栈

- **语言**: Swift 5
- **框架**: SwiftUI
- **平台**: macOS 13.0+
- **架构**: MVVM (Model-View-ViewModel)

## 核心功能

1.  **模型切换**: 快速切换 Claude Code 使用的模型 (Anthropic / OpenRouter)。
2.  **配置管理**: 读取并修改 `~/.claude/settings.json`。
3.  **API Key 管理**: 独立存储 Anthropic 和 OpenRouter 的 API Key。
4.  **自定义模型**: 支持添加自定义模型配置。
5.  **开机自启**: 支持设置开机自动启动。

## 关键模块

### Models

- `AppConfig.swift`: 应用自身配置（API Keys, 最近使用模型, 开机自启），存储在 UserDefaults。
- `ClaudeConfig.swift`: 映射 `~/.claude/settings.json` 的数据结构。
- `ModelPreset.swift`: 定义预设模型（Sonnet, Opus, Haiku 等）和自定义模型的数据结构。

### Services

- `ConfigService.swift`: 核心服务。负责监听、读取和写入 `~/.claude/settings.json`。实现模型切换逻辑。

### Views

- `ClaudeModelSwitcherApp.swift`: 应用入口，配置 `AppDelegate` 和菜单栏逻辑。
- `SettingsView.swift`: 设置页面。

## 数据流

1.  应用启动时 `ConfigService` 读取 `~/.claude/settings.json`。
2.  用户在菜单栏选择模型。
3.  `ConfigService` 根据选择的模型预设，更新 `ClaudeConfig` 对象。
4.  `ConfigService` 将更新后的配置写入 `~/.claude/settings.json`。
5.  `AppConfig` 记录最近使用的模型。

## 开发注意事项

- 修改 `ConfigService` 时需注意文件读写的原子性和错误处理。
- `ClaudeConfig` 的结构必须与 Claude CLI 工具的配置文件格式严格一致。
- 应用沙盒设置可能影响文件访问权限（当前设计似乎直接读写用户目录，需注意 Entitlements）。
