#!/usr/bin/env bash
# 发布第一步:把**当前提交**导出成 macOS / Windows 安装包,并给各自的游戏内容包(pck)签名。
# - 总在当前提交的临时干净副本(git worktree)里导出:工作区里没提交、没 git add 的改动都不会进包,
#   导出途中别人改了工作区也不影响;版本号等也从提交里的 build.json 读;
# - 安装包里附上签名清单:开房时房主就能把自己这一版转发给局域网里版本旧的玩家;
# - <OUT>/update/<平台>/ 下备好 manifest.json、manifest.sig、game-b<build>.pck,
#   由 tools/publish_update.sh 推到 GitHub 的 updates 分支(BuildInfo.FEED_URL)就是互联网更新源;
# - 两个平台全部做完才一次性换掉 <OUT> 里的旧产物,中途失败不会留下一半新一半旧。
# OUT 默认是主仓库的 build/(从 worktree 里运行也一样),发布记录 last_build / last_commit 等也写在那里。
# 发布前先把 build.json 的 build 加一并提交;project.godot 改过时还要把 base_build 设成同一个数(老玩家必须重装)。
# 用法:tools/release.sh [更新说明]
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
OUT="${OUT:-${COMMON%/.git}/build}"
KEY="${LIARS_UPDATE_KEY:-$HOME/.config/liarstavern/update_signing_key.pem}"
NOTES="${1:-}"
NAME="骗子酒馆"

[ -f "$KEY" ] || { echo "缺少签名私钥 $KEY(先运行:godot --headless --path . -s tools/make_update_key.gd)"; exit 1; }
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
at_commit() { git -C "$ROOT" show "$COMMIT:$1"; }
json_field() { python3 -c 'import json, sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1"; }
BUILD="$(at_commit build.json | json_field build)"
BASE="$(at_commit build.json | json_field base_build)"
VERSION="$(at_commit build.json | json_field version)"
STATUS="$(git -C "$ROOT" status --porcelain)"
[ -z "$STATUS" ] || echo "! 工作区有未提交或未跟踪的改动:它们不会进包,导出的是提交 ${COMMIT:0:7}"

STAMPS="$OUT/update"
mkdir -p "$STAMPS"
if [ -f "$STAMPS/last_build" ] && [ "$BUILD" -le "$(cat "$STAMPS/last_build")" ]; then
	echo "提交里 build.json 的 build($BUILD)没有比上次发布($(cat "$STAMPS/last_build"))大:先加一并提交"; exit 1
fi
SETTINGS_SHA="$(at_commit project.godot | shasum -a 256 | cut -d' ' -f1)"
if [ -f "$STAMPS/project.godot.sha256" ] && [ "$(cat "$STAMPS/project.godot.sha256")" != "$SETTINGS_SHA" ] \
		&& [ "$BASE" != "$BUILD" ]; then
	echo "project.godot 自上次发布后改过,旧安装包叠加不了这次的内容:把 build.json 的 base_build 改成 $BUILD 并提交"; exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liars_release.XXXXXX")"
SRC="$STAGE/src"
NEW="$STAGE/out"
cleanup() {
	git -C "$ROOT" worktree remove --force "$SRC" >/dev/null 2>&1 || true
	rm -rf "$STAGE"
}
trap cleanup EXIT
echo "导出提交 $(git -C "$ROOT" log -1 --format='%h %s' "$COMMIT")"
git -C "$ROOT" worktree add -q --detach "$SRC" "$COMMIT"
# 新副本要先导入资源:没有 class_name 缓存时,签名脚本连 UpdateManifest 都找不到
"$GODOT" --headless --path "$SRC" --import >"$STAGE/import.log" 2>&1 || true
[ -f "$SRC/.godot/global_script_class_cache.cfg" ] || { tail -20 "$STAGE/import.log"; echo "导入资源失败"; exit 1; }

PCK_FILE="game-b$BUILD.pck"   # 按 build 命名:网上的缓存不会把新清单和旧 pck 配在一起

sign() {  # sign <pck> <平台>:清单、签名、pck 写到 $NEW/update/<平台>/
	local dir="$NEW/update/$2"
	mkdir -p "$dir"
	# Godot 在 -s 脚本解析失败时也返回 0:不能只看退出码,还要看清单是否真的写出来了
	"$GODOT" --headless --path "$SRC" -s tools/sign_update.gd -- --pck="$1" --platform="$2" --out="$dir" \
		--pck-file="$PCK_FILE" --notes="$NOTES" --key="$KEY" >"$STAGE/sign_$2.log" 2>&1 || true
	if [ ! -s "$dir/manifest.json" ] || [ ! -s "$dir/manifest.sig" ]; then
		cat "$STAGE/sign_$2.log"; echo "签名失败:$2(没有生成清单)"; exit 1
	fi
	grep -E "已签名" "$STAGE/sign_$2.log" || true
	local want; want="$(shasum -a 256 "$1" | cut -d' ' -f1)"
	grep -q "\"pck_sha256\": \"$want\"" "$dir/manifest.json" || { echo "清单里的校验值和 pck 对不上:$2"; exit 1; }
	cp "$1" "$dir/$PCK_FILE"
}

# —— macOS:pck 在 .app/Contents/Resources 里;附上清单后整包重新做 ad-hoc 签名 ——
"$GODOT" --headless --path "$SRC" --export-release "macOS" "$STAGE/mac.zip" >"$STAGE/export_mac.log" 2>&1 || true
[ -s "$STAGE/mac.zip" ] || { tail -20 "$STAGE/export_mac.log"; echo "macOS 导出失败"; exit 1; }
ditto -x -k "$STAGE/mac.zip" "$STAGE/mac"
APP="$(ls -d "$STAGE"/mac/*.app)"
RES="$APP/Contents/Resources"
sign "$RES/$NAME.pck" macos
cp "$NEW/update/macos/manifest.json" "$RES/update_manifest.json"
cp "$NEW/update/macos/manifest.sig" "$RES/update_manifest.sig"
# 「显示简介」里的版本号:导出预设里写死的是 1.0,换成这一版
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD" "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"
mkdir -p "$NEW/macos"
# 不带扩展属性(系统给每个文件加的 com.apple.provenance 等):ditto 会把它们存成 ._ 文件,
# 用 unzip 之类不合并 ._ 的工具解压时这些文件落进 .app,签名随之失效
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$APP" "$NEW/macos/$NAME-macOS.zip"
python3 - "$NEW/macos/$NAME-macOS.zip" <<'PY'
import sys, zipfile
bad = [i.filename for i in zipfile.ZipFile(sys.argv[1]).infolist() if i.filename.rsplit("/", 1)[-1].startswith("._")]
sys.exit("macOS 安装包里混进了 %d 个 ._ 文件" % len(bad) if bad else 0)
PY

# —— Windows:exe 与 pck 分开放(房主要能读到自己的 pck 才能转发),整个文件夹打包 ——
WIN="$STAGE/win/$NAME"
mkdir -p "$WIN"
"$GODOT" --headless --path "$SRC" --export-release "Windows Desktop" "$WIN/$NAME.exe" >"$STAGE/export_win.log" 2>&1 || true
[ -s "$WIN/$NAME.exe" ] && [ -s "$WIN/$NAME.pck" ] || { tail -20 "$STAGE/export_win.log"; echo "Windows 导出失败"; exit 1; }
sign "$WIN/$NAME.pck" windows
cp "$NEW/update/windows/manifest.json" "$WIN/update_manifest.json"
cp "$NEW/update/windows/manifest.sig" "$WIN/update_manifest.sig"
mkdir -p "$NEW/windows"
# 用 Python 的 zipfile 打包:中文文件名带 UTF-8 标记,Windows 资源管理器解压不会乱码(macOS 的 zip 不带)
python3 - "$STAGE/win" "$NAME" "$NEW/windows/$NAME-Windows.zip" <<'PY'
import os, sys, zipfile
base, name, dest = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for root, _, files in os.walk(os.path.join(base, name)):
        for f in sorted(files):
            path = os.path.join(root, f)
            z.write(path, os.path.relpath(path, base))
PY

# —— 全部成功后才换掉旧产物,最后写发布记录 ——
for part in macos windows update/macos update/windows; do
	rm -rf "${OUT:?}/$part"
	mkdir -p "$(dirname "$OUT/$part")"
	mv "$NEW/$part" "$OUT/$part"
done
echo "$BUILD" > "$STAMPS/last_build"
echo "$SETTINGS_SHA" > "$STAMPS/project.godot.sha256"
echo "$COMMIT" > "$STAMPS/last_commit"
echo "发布完成 build $BUILD(v$VERSION,提交 ${COMMIT:0:7}):"
ls -la "$OUT/macos/$NAME-macOS.zip" "$OUT/windows/$NAME-Windows.zip"
echo "互联网更新文件:$OUT/update/{macos,windows}/(用 tools/publish_update.sh 推到 GitHub)"
