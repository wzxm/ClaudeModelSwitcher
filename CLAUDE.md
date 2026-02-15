# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Claude Model Switcher 是一款 macOS 菜单栏应用，用于快速切换 Claude Code CLI 使用的模型配置。通过修改 `~/.claude/settings.json` 文件实现模型切换，支持 6 个主流 AI 平台（Anthropic、OpenRouter、SiliconFlow、火山引擎、Z.ai、智谱AI）。

## 构建和开发

```bash
# 用 Xcode 打开项目
open ClaudeModelSwitcher.xcodeproj

# 命令行构建（release）
xcodebuild -project ClaudeModelSwitcher.xcodeproj -scheme ClaudeModelSwitcher -configuration Release build
```

**环境要求**: macOS 13.0+, Xcode 15+, Swift 5.9+

## 架构设计

采用 MVVM 架构，核心数据流：

```
用户选择模型 → ConfigService.switchModel() → 写入 ~/.claude/settings.json → 文件监听器触发重载
```

### 关键模块

| 模块 | 职责 |
|------|------|
| `ConfigService.swift` | **核心服务** - 读写 `~/.claude/settings.json`，文件监听，模型切换逻辑 |
| `ClaudeConfig.swift` | Claude 配置数据结构，必须与 Claude CLI 配置格式严格一致 |
| `AppConfig.swift` | 应用自身配置（API Keys、最近使用、开机自启），存储在 UserDefaults |
| `ModelPreset.swift` | 预设模型定义，包含各平台模型列表和平台枚举 |

### 平台支持

在 `ModelPlatform` 枚举中定义，新增平台需要：
1. 在 `ModelPlatform` 添加 case
2. 在 `baseUrl` 属性添加 API 地址
3. 在 `ModelPresets` 添加预设模型
4. 在 `AppConfig` 添加对应 API Key 存储

## 配置文件格式

应用修改的 `~/.claude/settings.json` 格式：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "sk-or-v1-xxx",
    "ANTHROPIC_MODEL": "openrouter/pony-alpha"
  }
}
```

## 注意事项

- **ConfigService 修改需谨慎** - 涉及文件读写原子性和错误处理
- **ClaudeConfig 结构不可随意改动** - 必须与 Claude CLI 配置格式保持一致
- **沙盒权限** - 应用直接读写用户目录，需注意 Entitlements 配置
