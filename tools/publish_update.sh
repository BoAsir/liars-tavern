#!/usr/bin/env bash
# 把 tools/release.sh 备好的更新文件(build/update/<平台>/)发布到 GitHub 仓库的 updates 分支,
# 游戏经 raw.githubusercontent.com 读取(BuildInfo.FEED_URL)。分支每次只保留一个提交(强推),仓库不会越来越大。
# 用法:tools/publish_update.sh(先运行 tools/release.sh);需要能 git push 到 origin(SSH 即可)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${OUT:-$ROOT/build}/update"
REMOTE="${REMOTE:-origin}"
BRANCH="updates"

for plat in macos windows; do
	[ -f "$SRC/$plat/manifest.json" ] && [ -f "$SRC/$plat/manifest.sig" ] && ls "$SRC/$plat"/game-b*.pck >/dev/null 2>&1 \
		|| { echo "缺少 $SRC/$plat 的更新文件,先运行 tools/release.sh"; exit 1; }
done
BUILD=$(cat "$SRC/last_build")
URL=$(git -C "$ROOT" remote get-url "$REMOTE")

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liars_publish.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
git -C "$STAGE" init -q -b "$BRANCH"
for plat in macos windows; do
	mkdir -p "$STAGE/$plat"
	cp "$SRC/$plat/manifest.json" "$SRC/$plat/manifest.sig" "$SRC/$plat"/game-b*.pck "$STAGE/$plat/"
done
cat > "$STAGE/README.md" <<MD
# 骗子酒馆 · 在线更新源

游戏自动读取这里的文件更新自己(build $BUILD)。内容由发布者私钥签名,游戏只接受签名正确的更新包。
不要手动修改这个分支:它由 \`tools/publish_update.sh\` 生成,每次发布都会整体覆盖。
MD
git -C "$STAGE" add -A
git -C "$STAGE" -c user.name="$(git -C "$ROOT" config user.name)" -c user.email="$(git -C "$ROOT" config user.email)" \
	commit -q -m "update: build $BUILD"
git -C "$STAGE" push -q --force "$URL" "$BRANCH:$BRANCH"
echo "已发布 build $BUILD 到 $URL 的 $BRANCH 分支"
