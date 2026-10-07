#!/usr/bin/env bash
# 发布:导出 macOS / Windows 安装包并给各自的游戏内容包(pck)签名。
# - 安装包里附上签名清单:开房时房主就能把自己这一版转发给局域网里版本旧的玩家;
# - build/update/<平台>/ 下备好 manifest.json、manifest.sig、game-b<build>.pck,用 tools/publish_update.sh 推到 GitHub
#   (BuildInfo.FEED_URL 指向那里)就是互联网更新源。
# 发布前先把 build.json 的 build 加一;project.godot 改过时还要把 base_build 设成同一个数(必须重装)。
# 用法:tools/release.sh [更新说明]
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/build}"
KEY="${LIARS_UPDATE_KEY:-$HOME/.config/liarstavern/update_signing_key.pem}"
NOTES="${1:-}"
NAME="骗子酒馆"

[ -f "$KEY" ] || { echo "缺少签名私钥 $KEY(先运行:godot --headless --path . -s tools/make_update_key.gd)"; exit 1; }

BUILD=$(sed -n 's/.*"build": *\([0-9][0-9]*\).*/\1/p' "$ROOT/build.json" | head -1)
BASE=$(sed -n 's/.*"base_build": *\([0-9][0-9]*\).*/\1/p' "$ROOT/build.json" | head -1)
STAMPS="$OUT/update"
mkdir -p "$STAMPS"
if [ -f "$STAMPS/last_build" ] && [ "$BUILD" -le "$(cat "$STAMPS/last_build")" ]; then
	echo "build.json 的 build($BUILD)没有比上次发布($(cat "$STAMPS/last_build"))大,先加一"; exit 1
fi
SETTINGS_SHA=$(shasum -a 256 "$ROOT/project.godot" | cut -d' ' -f1)
if [ -f "$STAMPS/project.godot.sha256" ] && [ "$(cat "$STAMPS/project.godot.sha256")" != "$SETTINGS_SHA" ] \
		&& [ "$BASE" != "$BUILD" ]; then
	echo "project.godot 自上次发布后改过,旧安装包叠加不了这次的内容:把 build.json 的 base_build 改成 $BUILD"; exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liars_release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

PCK_FILE="game-b$BUILD.pck"   # 按 build 命名:网上的缓存不会把新清单和旧 pck 配在一起

sign() {  # sign <pck> <平台> <输出目录>
	# 先清空上次发布留下的文件:签名失败时不能让旧清单冒充这一版
	mkdir -p "$3"
	rm -f "$3"/manifest.json "$3"/manifest.sig "$3"/*.pck
	if ! "$GODOT" --headless --path "$ROOT" -s tools/sign_update.gd -- --pck="$1" --platform="$2" --out="$3" \
			--pck-file="$PCK_FILE" --notes="$NOTES" --key="$KEY" >"$STAGE/sign_$2.log" 2>&1; then
		cat "$STAGE/sign_$2.log"; echo "签名失败:$2"; exit 1
	fi
	grep -E "已签名" "$STAGE/sign_$2.log" || true
	local want; want=$(shasum -a 256 "$1" | cut -d' ' -f1)
	grep -q "\"pck_sha256\": \"$want\"" "$3/manifest.json" || { echo "清单里的校验值和 pck 对不上:$2"; exit 1; }
	cp "$1" "$3/$PCK_FILE"
}

# —— macOS:pck 在 .app/Contents/Resources 里;附上清单后整包重新做 ad-hoc 签名 ——
"$GODOT" --headless --path "$ROOT" --export-release "macOS" "$STAGE/mac.zip" >/dev/null 2>&1
ditto -x -k "$STAGE/mac.zip" "$STAGE/mac"
APP="$(ls -d "$STAGE"/mac/*.app)"
RES="$APP/Contents/Resources"
sign "$RES/$NAME.pck" macos "$OUT/update/macos"
cp "$OUT/update/macos/manifest.json" "$RES/update_manifest.json"
cp "$OUT/update/macos/manifest.sig" "$RES/update_manifest.sig"
codesign --force --deep -s - "$APP"
mkdir -p "$OUT/macos"
rm -f "$OUT/macos/$NAME-macOS.zip"
ditto -c -k --keepParent "$APP" "$OUT/macos/$NAME-macOS.zip"

# —— Windows:exe 与 pck 分开放(房主要能读到自己的 pck 才能转发),整个文件夹打包 ——
WIN="$STAGE/win/$NAME"
mkdir -p "$WIN"
"$GODOT" --headless --path "$ROOT" --export-release "Windows Desktop" "$WIN/$NAME.exe" >/dev/null 2>&1
sign "$WIN/$NAME.pck" windows "$OUT/update/windows"
cp "$OUT/update/windows/manifest.json" "$WIN/update_manifest.json"
cp "$OUT/update/windows/manifest.sig" "$WIN/update_manifest.sig"
mkdir -p "$OUT/windows"
rm -f "$OUT/windows/$NAME-Windows.zip"
# 用 Python 的 zipfile 打包:中文文件名带 UTF-8 标记,Windows 资源管理器解压不会乱码(macOS 的 zip 不带)
python3 - "$STAGE/win" "$NAME" "$OUT/windows/$NAME-Windows.zip" <<'PY'
import os, sys, zipfile
base, name, dest = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, _, files in os.walk(os.path.join(base, name)):
        for f in sorted(files):
            path = os.path.join(root, f)
            z.write(path, os.path.relpath(path, base))
PY

echo "$BUILD" > "$STAMPS/last_build"
echo "$SETTINGS_SHA" > "$STAMPS/project.godot.sha256"
echo "发布完成 build $BUILD:"
ls -la "$OUT/macos/$NAME-macOS.zip" "$OUT/windows/$NAME-Windows.zip"
echo "互联网更新文件:$OUT/update/{macos,windows}/(用 tools/publish_update.sh 推到 GitHub)"
