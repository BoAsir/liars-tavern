#!/usr/bin/env bash
# 把 tools/release.sh 导出的安装包发布成 GitHub Release,给新玩家下载(已安装的玩家走在线更新,用不着这一步)。
# - tag 是 v<版本>,打在导出这批安装包的那个提交上(release.sh 记在 <OUT>/update/last_commit),该提交必须已在 origin/main;
# - 附件用 ASCII 文件名(GitHub 会改掉文件名里的中文),显示名里也带上文件名;另附 SHA256SUMS.txt;
# - 发布前核对两个安装包附带的签名清单就是这一版、提交里的 build.json 也是这一版;发布后从公开地址下载回来逐字节比对;
# - 可以重复运行:Release 已存在时只做核对(REPAIR=1 时用本地文件覆盖对不上的附件);上次中断留下草稿时提示怎么清掉。
# 用法:tools/publish_release.sh [发布说明.md](不给就按模板生成)。需要 gh 已登录;OUT 默认是主仓库的 build/。
#       DRY_RUN=1 只做核对、打印要发布的内容;TARGET=<提交> 只用于没有导出记录的旧产物(有记录时必须与之一致)。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
OUT="${OUT:-${COMMON%/.git}/build}"
NAME="骗子酒馆"
MAC_ZIP="$OUT/macos/$NAME-macOS.zip"
WIN_ZIP="$OUT/windows/$NAME-Windows.zip"
NOTES_IN="${1:-}"
CURL=(curl -fsSL --retry 3 --connect-timeout 20 --speed-limit 10240 --speed-time 60)

command -v gh >/dev/null || { echo "需要 GitHub CLI(gh)"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh 还没登录:先运行 gh auth login"; exit 1; }
for f in "$MAC_ZIP" "$WIN_ZIP" "$OUT/update/macos/manifest.json" "$OUT/update/windows/manifest.json"; do
	[ -f "$f" ] || { echo "缺少 $f,先运行 tools/release.sh"; exit 1; }
done
[ -z "$NOTES_IN" ] || [ -f "$NOTES_IN" ] || { echo "找不到发布说明 $NOTES_IN"; exit 1; }
REPO="$(cd "$ROOT" && gh repo view --json nameWithOwner -q .nameWithOwner)"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liars_gh_release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

# —— 核对:两个平台的清单是同一版,安装包里附带的清单与之一致(防止传错一批旧安装包) ——
CHECKED="$(python3 - "$OUT" "$MAC_ZIP" "$WIN_ZIP" <<'PY'
import json, os, sys, zipfile
out, mac_zip, win_zip = sys.argv[1:4]
published = {p: json.load(open(os.path.join(out, "update", p, "manifest.json"), encoding="utf-8")) for p in ("macos", "windows")}
if (published["macos"]["version"], published["macos"]["build"]) != (published["windows"]["version"], published["windows"]["build"]):
    sys.exit("两个平台的更新清单不是同一版:macOS v%s build %s / Windows v%s build %s" % (
        published["macos"]["version"], published["macos"]["build"], published["windows"]["version"], published["windows"]["build"]))
def bundled(zip_path, suffix):
    # 只按纯 ASCII 的路径结尾找:macOS 的 zip 里中文目录名可能没带 UTF-8 标记
    with zipfile.ZipFile(zip_path) as z:
        names = [i for i in z.infolist() if i.filename.endswith(suffix)]
        if len(names) != 1:
            sys.exit("%s 里找不到唯一的 %s" % (os.path.basename(zip_path), suffix))
        return json.loads(z.read(names[0]))
for plat, zip_path, suffix in (("macos", mac_zip, "/Contents/Resources/update_manifest.json"),
                               ("windows", win_zip, "/update_manifest.json")):
    if bundled(zip_path, suffix) != published[plat]:
        sys.exit("%s 安装包附带的清单和 update/%s 的不一致:安装包和更新文件不是同一次 release.sh 产出的" % (plat, plat))
m = published["macos"]
print(m["version"], m["build"], m["base_build"])
PY
)"
read -r VERSION BUILD BASE <<< "$CHECKED"
TAG="v$VERSION"

# —— tag 打在哪个提交:以导出记录为准 ——
STAMP="$(cat "$OUT/update/last_commit" 2>/dev/null || true)"
case "$STAMP" in *-dirty) echo "这批安装包是从带未提交改动的工作区导出的($STAMP),不能发布:提交后重新导出"; exit 1 ;; esac
resolve() { git -C "$ROOT" rev-parse --verify --quiet "$1^{commit}" || { echo "找不到提交 $1" >&2; return 1; }; }
if [ -n "$STAMP" ]; then
	TARGET_SHA="$(resolve "$STAMP")"
	if [ -n "${TARGET:-}" ] && [ "$(resolve "$TARGET")" != "$TARGET_SHA" ]; then
		echo "TARGET=$TARGET 和导出记录 ${STAMP:0:7} 不一致:安装包是从后者导出的"; exit 1
	fi
elif [ -n "${TARGET:-}" ]; then
	TARGET_SHA="$(resolve "$TARGET")"
else
	echo "没有导出记录(旧版 release.sh 导出的?):用 TARGET=<导出用的提交> 指定"; exit 1
fi
TARGET_BUILD="$(git -C "$ROOT" show "$TARGET_SHA:build.json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["version"], d["build"])')"
[ "$TARGET_BUILD" = "$VERSION $BUILD" ] \
	|| { echo "提交 ${TARGET_SHA:0:7} 里的 build.json 是 $TARGET_BUILD,安装包是 v$VERSION build $BUILD:对不上"; exit 1; }
git -C "$ROOT" fetch -q --prune origin
git -C "$ROOT" merge-base --is-ancestor "$TARGET_SHA" origin/main \
	|| { echo "提交 ${TARGET_SHA:0:7} 还不在 origin/main 上:先推送,下载到的安装包要和公开源码一致"; exit 1; }
# 附注 tag 的 refs/tags/X 指向 tag 对象,X^{} 才是提交:有 ^{} 行就以它为准(它排在后面)
REMOTE_TAG="$(git -C "$ROOT" ls-remote --tags origin "refs/tags/$TAG" "refs/tags/$TAG^{}" | awk '{print $1}' | tail -1)"
[ -z "$REMOTE_TAG" ] || [ "$REMOTE_TAG" = "$TARGET_SHA" ] \
	|| { echo "GitHub 上已有 tag $TAG,但指向别的提交 $REMOTE_TAG"; exit 1; }

# —— 附件:ASCII 文件名 + 校验值 ——
MAC_ASSET="LiarsTavern-$VERSION-macOS.zip"
WIN_ASSET="LiarsTavern-$VERSION-Windows.zip"
cp "$MAC_ZIP" "$STAGE/$MAC_ASSET"
cp "$WIN_ZIP" "$STAGE/$WIN_ASSET"
(cd "$STAGE" && shasum -a 256 "$MAC_ASSET" "$WIN_ASSET" > SHA256SUMS.txt)
ASSETS=("$MAC_ASSET" "$WIN_ASSET" SHA256SUMS.txt)

label_for() {  # 页面上的显示名(gh 的 文件#显示名):带上文件名,和说明里引用的名字对得上
	case "$1" in
		"$MAC_ASSET") echo "$1(macOS,Intel / Apple 芯片通用)" ;;
		"$WIN_ASSET") echo "$1(Windows 64 位)" ;;
		*) echo "$1(校验值)" ;;
	esac
}

BAD=()
verify_public() {  # 从公开地址(不带登录)下载回来逐字节比对;对不上的记在 BAD 里
	local asset
	BAD=()
	for asset in "${ASSETS[@]}"; do
		if ! "${CURL[@]}" -o "$STAGE/check-$asset" "https://github.com/$REPO/releases/download/$TAG/$asset" \
				|| ! cmp -s "$STAGE/$asset" "$STAGE/check-$asset"; then
			BAD+=("$asset")
		fi
	done
	[ "${#BAD[@]}" -eq 0 ]
}

repair() {  # 用本地文件覆盖对不上的附件,再核对一次
	local asset args=()
	for asset in "${BAD[@]}"; do args+=("$STAGE/$asset#$(label_for "$asset")"); done
	gh release upload "$TAG" -R "$REPO" --clobber "${args[@]}"
	verify_public
}

EXISTING="$(gh release view "$TAG" -R "$REPO" --json isDraft -q .isDraft 2>/dev/null || true)"
if [ "$EXISTING" = "true" ]; then
	echo "上次发布中断,留下了草稿 Release $TAG(还没公开)。确认后删掉草稿再重跑:gh release delete $TAG -R $REPO --yes"; exit 1
elif [ "$EXISTING" = "false" ]; then
	echo "Release $TAG 已经发布过,只做核对:https://github.com/$REPO/releases/tag/$TAG"
	if verify_public; then echo "公开附件与本地一致"; exit 0; fi
	if [ "${REPAIR:-0}" = 1 ]; then
		repair && { echo "已补传并核对一致"; exit 0; }
		echo "补传后仍对不上:${BAD[*]}"; exit 1
	fi
	echo "公开附件与本地不一致或下载失败:${BAD[*]}。网络问题就直接重跑;确实要用本地文件覆盖时 REPAIR=1 重跑"; exit 1
fi

NOTES="$STAGE/notes.md"
if [ -n "$NOTES_IN" ]; then
	cp "$NOTES_IN" "$NOTES"
else
	CHANGES="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("notes") or "见提交记录")' \
		"$OUT/update/macos/manifest.json")"
	if [ "$BASE" = "$BUILD" ]; then
		UPDATE_LINE="**这一版需要重新下载安装包**:改了项目设置或引擎,已安装的游戏没法在线更新到这一版。"
	else
		UPDATE_LINE="已经装过的玩家不用下载:游戏启动时会自动更新到这一版,也可以在局域网里从同系统、新版本的房主那里更新。"
	fi
	cat > "$NOTES" <<MD
## 本次更新

$CHANGES

$UPDATE_LINE

## 下载

| 系统 | 文件 |
|---|---|
| macOS(Intel / Apple 芯片通用) | \`$MAC_ASSET\` |
| Windows 64 位 | \`$WIN_ASSET\` |

- **macOS**:解压得到 \`$NAME.app\`(用访达双击解压)。没有经过苹果公证,第一次打开会被系统拦下:到「系统设置 → 隐私与安全性」底部点「仍要打开」
  (macOS 14 及更早也可以右键点 App 选「打开」)。macOS 15 及以上第一次开房、搜索或加入房间时会询问「本地网络」权限,请选允许。
- **Windows**:解压后运行文件夹里的 \`$NAME.exe\`(exe 与同目录的 \`.pck\` 要放在一起)。程序没有数字签名,
  出现「Windows 已保护你的电脑」时点「更多信息」→「仍要运行」;防火墙询问时请允许,搜不到房间时把网络设为「专用网络」。

校验值见 \`SHA256SUMS.txt\`。
MD
fi

echo "准备发布 $TAG(build $BUILD,base_build $BASE)到 $REPO,tag 打在 ${TARGET_SHA:0:7}"
cat "$STAGE/SHA256SUMS.txt"
if [ "${DRY_RUN:-0}" = 1 ]; then
	echo "DRY_RUN:不发布。说明如下:"; cat "$NOTES"; exit 0
fi

ARGS=()
for asset in "${ASSETS[@]}"; do ARGS+=("$STAGE/$asset#$(label_for "$asset")"); done
gh release create "$TAG" -R "$REPO" --target "$TARGET_SHA" --title "$NAME v$VERSION" --notes-file "$NOTES" --latest "${ARGS[@]}"

if verify_public; then
	echo "已发布并核对:https://github.com/$REPO/releases/tag/$TAG"
else
	echo "Release 已经公开(https://github.com/$REPO/releases/tag/$TAG),但附件核对失败:${BAD[*]}。"
	echo "网络问题就直接重跑本脚本(只核对);确实对不上时 REPAIR=1 重跑,用本地文件覆盖"
	exit 1
fi
