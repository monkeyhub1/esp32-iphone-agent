#!/usr/bin/env bash
# 在别人的 Mac 上只做一件事：编出「未签名 IPA」。
#
# 不登录 Apple ID、不配置证书、不插手机、不打开 Xcode 图形界面。
# 编完把这个 .ipa 拷到 U 盘带回家，用 Sideloadly 用自己的 Apple ID 签。
#
# 用法：把整个项目文件夹拷到 Mac，打开「终端」，输入 bash + 空格，
#       把本文件拖进终端窗口，回车。

set -euo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"

echo "=============================================="
echo " ESP32 iPhone Agent —— 未签名 IPA 构建脚本"
echo "=============================================="
echo

# ---------- 环境检查 ----------
echo "==> [1/4] 检查 macOS 与 Xcode"

echo "macOS: $(sw_vers -productVersion)"

if ! command -v xcodebuild >/dev/null 2>&1; then
  cat <<'EOF'
❌ 这台 Mac 没装 Xcode。

需要去 App Store 搜索 "Xcode" 安装：
  - 版本要求：16 或更新（App 最低支持 iOS 18）
  - 体积约 15GB，下载可能要几十分钟
  - 装完首次启动要点「同意」并输入管理员密码装组件

装完再重新运行本脚本。
EOF
  exit 1
fi

XCODE_LINE="$(xcodebuild -version | head -1)"
echo "Xcode: $XCODE_LINE"

MAJOR="$(echo "$XCODE_LINE" | sed -E 's/^Xcode ([0-9]+).*/\1/')"
if [ "${MAJOR:-0}" -lt 16 ]; then
  echo
  echo "❌ Xcode 版本太旧（当前 $MAJOR，需要 16+）。"
  echo "   这个 App 最低支持 iOS 18，老版本 SDK 编不过。"
  echo "   升级路径：macOS 更新到 14.5+ 后，在 App Store 更新 Xcode。"
  exit 1
fi

# 许可证是否已接受（首次装完 Xcode 常见卡点）
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo
  echo "⚠️  Xcode 首次启动的组件还没装好。"
  echo "   请在「应用程序」里手动打开一次 Xcode，点「同意」并等组件装完，再重跑本脚本。"
  exit 1
fi

echo "✅ 环境 OK"
echo

# ---------- 编译 ----------
echo "==> [2/4] 开始编译（约 3-5 分钟，第一次会久一点）"
cd "$ROOT/ios"

xcodebuild \
  -project IPhoneAgent.xcodeproj \
  -scheme IPhoneAgent \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP="build/Build/Products/Release-iphoneos/IPhoneAgent.app"
if [ ! -d "$APP" ]; then
  echo "❌ 编译结束但没找到产物：$APP"
  exit 1
fi
echo "✅ 编译成功"
echo

# ---------- 打包 ----------
echo "==> [3/4] 打包成 IPA"
rm -rf Payload "$ROOT/IPhoneAgent-unsigned.ipa"
mkdir -p Payload
cp -R "$APP" Payload/
zip -qry "$ROOT/IPhoneAgent-unsigned.ipa" Payload
rm -rf Payload

echo "✅ 打包完成"
echo

# ---------- 汇报 ----------
echo "==> [4/4] 结果"
echo "   Bundle ID : $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "   版本      : $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
echo "   内嵌扩展  : $(ls -1 "$APP/PlugIns" 2>/dev/null | tr '\n' ' ')"
echo "   IPA 路径  : $ROOT/IPhoneAgent-unsigned.ipa"
echo
ls -lh "$ROOT/IPhoneAgent-unsigned.ipa"
echo
echo "=============================================="
echo " 下一步：把这个 .ipa 拷到 U 盘带回家，"
echo " 用 Windows 上的 Sideloadly + 你自己的 Apple ID 安装。"
echo "=============================================="
echo
echo "离开前如果想清干净（可选）："
echo "  rm -rf \"$ROOT/ios/build\""
echo "  再删掉整个项目文件夹即可"
