#!/bin/bash
#
# build-release.sh - Claude Model Switcher 打包脚本
# 方式一：直接打包（无签名）
# 适用于个人使用或小范围分发
#

set -e

# ==================== 配置 ====================
APP_NAME="ClaudeModelSwitcher"
PROJECT_NAME="${APP_NAME}.xcodeproj"
SCHEME="${APP_NAME}"
OUTPUT_DIR="release"
BUILD_DIR="build"

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==================== 检查环境 ====================
check_environment() {
    log_info "检查构建环境..."

    # 检查 xcodebuild
    if ! command -v xcodebuild &> /dev/null; then
        log_error "未找到 xcodebuild，请安装 Xcode"
        exit 1
    fi

    # 检查项目文件
    if [ ! -d "$PROJECT_NAME" ]; then
        log_error "未找到项目文件: $PROJECT_NAME"
        exit 1
    fi

    log_success "环境检查通过"
}

# ==================== 获取版本号 ====================
get_version() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    # 从 Info.plist 读取版本号
    INFO_PLIST="${SCRIPT_DIR}/${APP_NAME}/Info.plist"

    if [ -f "$INFO_PLIST" ]; then
        VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")
        BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1")
    else
        log_warn "未找到 Info.plist: $INFO_PLIST"
        log_warn "使用默认版本号"
        VERSION="1.0.0"
        BUILD_NUMBER="1"
    fi

    log_info "版本: $VERSION (Build $BUILD_NUMBER)"
}

# ==================== 清理旧文件 ====================
clean_build() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR"

    log_info "清理旧的构建文件..."

    rm -rf "${SCRIPT_DIR}/${OUTPUT_DIR}"
    rm -rf "${SCRIPT_DIR}/${BUILD_DIR}"

    log_success "清理完成"
}

# ==================== 构建 ====================
build_app() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR"

    log_info "开始 Release 构建..."

    xcodebuild \
        -project "${SCRIPT_DIR}/${PROJECT_NAME}" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "${SCRIPT_DIR}/${BUILD_DIR}" \
        clean build

    # 检查构建结果
    APP_PATH="${SCRIPT_DIR}/${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
    if [ ! -d "$APP_PATH" ]; then
        log_error "构建失败，未找到 .app 文件"
        exit 1
    fi

    log_success "构建完成: $APP_PATH"
}

# ==================== 打包 ====================
package_app() {
    log_info "打包应用..."

    # 获取脚本所在目录的绝对路径
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR"

    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"

    # 定义输出文件名（使用绝对路径）
    ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
    ZIP_PATH="${SCRIPT_DIR}/${OUTPUT_DIR}/${ZIP_NAME}"
    APP_PATH="${SCRIPT_DIR}/${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

    # 检查 .app 是否存在
    if [ ! -d "$APP_PATH" ]; then
        log_error "未找到 .app 文件: $APP_PATH"
        exit 1
    fi

    # 创建 zip 包（使用绝对路径）
    cd "$(dirname "$APP_PATH")"
    zip -r "$ZIP_PATH" "${APP_NAME}.app"
    cd "$SCRIPT_DIR"

    # 计算文件大小
    FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

    log_success "打包完成: $ZIP_PATH ($FILE_SIZE)"
}

# ==================== 显示结果 ====================
show_result() {
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    echo ""
    echo "=========================================="
    log_success "构建打包完成！"
    echo "=========================================="
    echo ""
    echo "版本:     $VERSION"
    echo "输出文件: ${SCRIPT_DIR}/${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.zip"
    echo ""
    echo "安装方式:"
    echo "  1. 解压 zip 文件"
    echo "  2. 将 ${APP_NAME}.app 拖入 /Applications 文件夹"
    echo "  3. 首次打开需在「系统设置 > 隐私与安全性」中允许运行"
    echo ""
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "=========================================="
    echo "  $APP_NAME Release Builder"
    echo "=========================================="
    echo ""

    check_environment
    get_version
    clean_build
    build_app
    package_app
    show_result
}

# 执行
main "$@"
