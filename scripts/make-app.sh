#!/usr/bin/env bash
# make-app.sh — 构建 dist/CC Model.app（release 可执行 + Info.plist + ad-hoc 签名）
#
# 用法：bash scripts/make-app.sh
# 可重复运行：每次先删除旧 dist 再重建；任一步失败即以非零退出码结束。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="CC Model.app"
APP_DIR="$REPO_ROOT/dist/$APP_NAME"
EXECUTABLE_NAME="ccmodel"

cd "$REPO_ROOT"

echo "==> 1/5 删除旧 dist"
rm -rf "$REPO_ROOT/dist"

echo "==> 2/5 swift build -c release"
swift build -c release

BUILT_BIN="$REPO_ROOT/.build/release/$EXECUTABLE_NAME"
if [ ! -x "$BUILT_BIN" ]; then
    echo "error: 构建产物不存在：$BUILT_BIN" >&2
    exit 1
fi

echo "==> 3/5 搭建 bundle 骨架并生成 Info.plist"
mkdir -p "$APP_DIR/Contents/MacOS"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CC Model</string>
    <key>CFBundleDisplayName</key>
    <string>CC Model</string>
    <key>CFBundleIdentifier</key>
    <string>com.ccmodel.app</string>
    <key>CFBundleExecutable</key>
    <string>ccmodel</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> 4/5 拷贝 release 可执行文件"
cp "$BUILT_BIN" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

echo "==> 5/5 ad-hoc 签名"
codesign --force --sign - "$APP_DIR"

echo "==> 产物结构自检"
if [ ! -x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" ]; then
    echo "error: 缺少可执行文件 $APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" >&2
    exit 1
fi
if [ ! -f "$APP_DIR/Contents/Info.plist" ]; then
    echo "error: 缺少 $APP_DIR/Contents/Info.plist" >&2
    exit 1
fi

echo "完成：dist/$APP_NAME"
echo "提示：将 CC Model.app 放入 /Applications 以便登录项登记。"
