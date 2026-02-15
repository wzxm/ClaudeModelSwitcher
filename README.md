# Claude Model Switcher

一款专为 macOS 设计的菜单栏应用，让你在使用 Claude Code (CLI) 时能够极速切换模型配置。

## 功能特性

- **快速切换**: 在菜单栏一键切换 Claude Code 使用的模型
- **多平台支持**: 支持 6 个主流 AI 平台
  - **Anthropic 官方** - Claude 系列模型
  - **OpenRouter** - 多模型聚合平台
  - **SiliconFlow** - DeepSeek 等国产模型
  - **火山引擎** - 字节跳动豆包系列
  - **Z.ai** - GLM 系列模型
  - **智谱AI** - 智谱 GLM 系列
- **Key 管理**: 统一管理各平台的 API Key，切换模型时自动替换
- **自定义模型**: 支持添加、编辑、删除自定义模型预设
- **开机自启**: 支持随系统启动，随时待命

## 安装

1. 下载最新版本的 `ClaudeModelSwitcher.app`
2. 将其拖入 `/Applications` 文件夹
3. 启动应用，在菜单栏即可看到应用图标

## 使用指南

### 1. 初始设置

首次启动后，点击菜单栏图标，选择 "打开设置..." (或按 `Cmd+,`)：

| 平台 | API Key 格式 | 获取地址 |
|------|-------------|----------|
| Anthropic | `sk-ant-xxx` | [Anthropic Console](https://console.anthropic.com/) |
| OpenRouter | `sk-or-xxx` | [OpenRouter Keys](https://openrouter.ai/keys) |
| SiliconFlow | - | [SiliconFlow](https://cloud.siliconflow.cn/) |
| 火山引擎 | - | [火山引擎](https://www.volcengine.com/) |
| Z.ai | - | [Z.ai](https://z.ai/) |
| 智谱AI | - | [智谱开放平台](https://open.bigmodel.cn/) |

### 2. 切换模型

点击菜单栏图标，从子菜单中选择平台和模型。

### 3. 自定义模型

在设置页面的 "自定义模型" 标签页中：
- **添加**: 点击"添加模型"按钮，填写模型 ID、显示名称、平台等信息
- **编辑**: 点击模型行右侧的编辑图标
- **删除**: 点击模型行右侧的删除图标

自定义模型会同步出现在菜单栏的"自定义模型"子菜单中，方便快速切换。

## 工作原理

本应用通过修改 `~/.claude/settings.json` 文件来实现模型切换：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://openrouter.ai/api",
    "ANTHROPIC_AUTH_TOKEN": "sk-or-v1-xxx",
    "ANTHROPIC_MODEL": "openrouter/pony-alpha"
  }
}
```

切换模型后，新启动的 `claude` 命令将使用新的配置。

## 开发构建

### 环境要求

- macOS 13.0+
- Xcode 15+
- Swift 5.9+

### 开发运行

```bash
# 克隆仓库
git clone https://github.com/yourusername/ClaudeModelSwitcher.git
cd ClaudeModelSwitcher

# 用 Xcode 打开
open ClaudeModelSwitcher.xcodeproj

# 按 Cmd + R 运行调试
```

### 命令行构建

```bash
# Debug 构建
xcodebuild -project ClaudeModelSwitcher.xcodeproj \
  -scheme ClaudeModelSwitcher \
  -configuration Debug \
  build

# Release 构建
xcodebuild -project ClaudeModelSwitcher.xcodeproj \
  -scheme ClaudeModelSwitcher \
  -configuration Release \
  build
```

## 打包分发（不上应用市场）

以下是将应用打包成可分发的 `.app` 的完整步骤：

### 方式一：直接打包（无签名）

适用于个人使用或小范围分发。

```bash
# 1. Release 构建
xcodebuild -project ClaudeModelSwitcher.xcodeproj \
  -scheme ClaudeModelSwitcher \
  -configuration Release \
  -derivedDataPath build \
  clean build

# 2. 找到生成的 .app
# 位置: build/Build/Products/Release/ClaudeModelSwitcher.app

# 3. 打包成 zip
cd build/Build/Products/Release
zip -r ClaudeModelSwitcher.zip ClaudeModelSwitcher.app
```

#### 无签名应用的安全提示

无签名应用首次打开会提示"无法验证开发者"，可通过以下方式允许运行：

**方法一：右键打开（推荐）**
1. 右键点击 `ClaudeModelSwitcher.app`
2. 选择"打开"
3. 弹出对话框点击"打开"确认

**方法二：系统设置允许**
1. 双击打开应用，会提示安全警告
2. 打开"系统设置" > "隐私与安全性"
3. 在底部点击"仍要打开"，输入密码确认

**方法三：命令行移除隔离属性**
```bash
xattr -cr /Applications/ClaudeModelSwitcher.app
```

> 以上操作只需执行一次，之后可正常双击打开。

### 方式二：签名 + 公证（推荐）

适用于公开分发，用户无需额外操作即可直接运行。

#### 1. 准备开发者证书

确保你有 Apple Developer 账号，并在 Xcode 中登录：

```bash
# 查看可用的签名证书
security find-identity -v -p codesigning
```

#### 2. 配置 Xcode 项目签名

在 Xcode 中：
1. 选择项目 > ClaudeModelSwitcher target
2. Signing & Capabilities 标签页
3. 勾选 "Automatically manage signing"
4. 选择你的 Team

或通过命令行配置：

```bash
# 设置签名证书（替换为你的证书 ID）
CERTIFICATE_ID="Developer ID Application: Your Name (XXXXXXXXXX)"

# 或使用 Team ID
TEAM_ID="XXXXXXXXXX"
```

#### 3. 构建并签名

```bash
# 定义变量
APP_NAME="ClaudeModelSwitcher"
BUNDLE_ID="com.yourname.ClaudeModelSwitcher"
CERTIFICATE="Developer ID Application: Your Name (XXXXXXXXXX)"

# Release 构建
xcodebuild -project ${APP_NAME}.xcodeproj \
  -scheme ${APP_NAME} \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="${CERTIFICATE}" \
  clean build

# 验证签名
codesign --verify --deep --strict --verbose=2 build/Build/Products/Release/${APP_NAME}.app
```

#### 4. 创建 DMG（可选但推荐）

```bash
# 创建临时 DMG 文件夹
mkdir -p dmg_temp
cp -r build/Build/Products/Release/${APP_NAME}.app dmg_temp/

# 创建 DMG
hdiutil create -volname "${APP_NAME}" \
  -srcfolder dmg_temp \
  -ov -format UDZO \
  ${APP_NAME}.dmg

# 清理
rm -rf dmg_temp
```

#### 5. 公证（Notarization）

```bash
# 提交公证（需要 App-specific password）
xcrun notarytool submit ${APP_NAME}.dmg \
  --apple-id "your@email.com" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --team-id "XXXXXXXXXX" \
  --wait

# 公证成功后，Staple 证书
xcrun stapler staple ${APP_NAME}.dmg

# 验证
spctl --assess --verbose --type open --context context:primary-signature ${APP_NAME}.dmg
```

#### 6. 分发

将公证后的 DMG 或 zip 文件上传到 GitHub Releases 或其他分发渠道。

### 快速打包脚本

创建 `build-release.sh`：

```bash
#!/bin/bash
set -e

APP_NAME="ClaudeModelSwitcher"
VERSION=$(defaults read $(pwd)/${APP_NAME}/Info.plist CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
OUTPUT_DIR="release"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# 清理
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}

# Release 构建
xcodebuild -project ${APP_NAME}.xcodeproj \
  -scheme ${APP_NAME} \
  -configuration Release \
  -derivedDataPath build \
  clean build

# 复制 .app
cp -r build/Build/Products/Release/${APP_NAME}.app ${OUTPUT_DIR}/

# 打包 zip
cd ${OUTPUT_DIR}
zip -r ${APP_NAME}-v${VERSION}.zip ${APP_NAME}.app
rm -rf ${APP_NAME}.app

echo "✅ Build complete: ${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.zip"
```

运行：
```bash
chmod +x build-release.sh
./build-release.sh
```

## 项目结构

```
ClaudeModelSwitcher/
├── ClaudeModelSwitcherApp.swift    # 应用入口，菜单栏管理
├── Models/
│   ├── ClaudeConfig.swift          # Claude 配置数据模型
│   ├── ModelPreset.swift           # 预设模型定义，平台枚举
│   └── AppConfig.swift             # 应用配置（API Keys、自定义模型）
├── Services/
│   └── ConfigService.swift         # 配置文件读写服务，文件监听
├── Views/
│   ├── MenuBarView.swift           # 菜单栏下拉视图
│   ├── SettingsView.swift          # 设置窗口（Sidebar + Detail）
│   ├── ProviderDetailView.swift    # 平台详情页（API Key 配置）
│   ├── ModelListView.swift         # 自定义模型列表（增删改）
│   └── AboutView.swift             # 关于页面
└── ViewModels/
    └── SettingsViewModel.swift     # 设置窗口业务逻辑
```

## 注意事项

- 本应用会直接修改 `~/.claude/settings.json` 文件，请确保你有该文件的读写权限
- 切换模型时，应用会覆盖配置文件中的 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_MODEL` 字段
- 切换是静默的，仅在菜单栏显示变化，不会弹出系统通知

## 许可证

MIT License

---

Made with love
