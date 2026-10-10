#!/usr/bin/env bash
# GitHub Actions 自动发布(.github/workflows/release.yml)用的辅助步骤;真正的导出、签名、发布仍由
# .claude/skills/release-update/scripts/ship.sh 完成,这里只补上 CI 里缺的东西:
#   plan      决定这次 push 要不要发布:build.json 的 version 在远端还没有 tag v<version> 就发布。
#             同时定下给玩家看的更新说明(NOTES_OVERRIDE,否则 build.json 的 notes),写进 $GITHUB_OUTPUT
#   key       把 secret 里的签名私钥写成文件,并核对它和游戏里的公钥(src/update/update_key.gd)是一对
#   seed      CI 里没有本机 build/ 下的发布记录:按线上更新源和上一版的 tag 补出来,ship.sh check 才能照常检查
#             build 有没有加、version 有没有改、project.godot 或引擎变了时 base_build 对不对
#   published 线上更新源已经是 build/ 里这一批(同一份清单)时返回 0:重跑时跳过推更新源,直接补 GitHub Release
# 用法:tools/ci_release.sh <plan|key|seed|published>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
MAX_NOTES_CHARS=60   # 与 ship.sh 一致:更新说明显示在主菜单提示条的一行里

die() { echo "::error::$*" >&2; exit 1; }
field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[2], encoding="utf-8")).get(sys.argv[1], ""))' "$1" "$2"; }

BUILD="$(field build "$ROOT/build.json")"
VERSION="$(field version "$ROOT/build.json")"
BASE="$(field base_build "$ROOT/build.json")"
FEED_URL="$(sed -n 's/^const FEED_URL := "\(.*\)"/\1/p' "$ROOT/src/update/build_info.gd")"
RELEASE_NOTES="docs/releases/v$VERSION.md"   # GitHub Release 正文(可选;base_build = build 时必须有)

live_manifest() {  # live_manifest <平台> <输出文件>:读线上更新源的清单,读不到返回非 0
	curl -fsS --retry 3 -m 20 -o "$2" "${FEED_URL}$1/manifest.json?t=$(date +%s)"
}

output() { echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/stdout}"; }

plan() {
	echo "build.json:build $BUILD,version $VERSION,base_build $BASE"
	output version "$VERSION"
	output build "$BUILD"
	if git -C "$ROOT" ls-remote --exit-code --tags origin "refs/tags/v$VERSION" >/dev/null 2>&1; then
		echo "远端已经有 tag v$VERSION:版本号没变,不发布"
		output release false
		return 0
	fi
	local notes="${NOTES_OVERRIDE:-}"
	[ -n "$notes" ] || notes="$(field notes "$ROOT/build.json")"
	[ -n "$notes" ] || die "缺少更新说明:在 build.json 里加 \"notes\"(一句话,≤${MAX_NOTES_CHARS} 字,以「修复:」或「新增:」开头),或手动运行时填 notes"
	case "$notes" in *$'\n'*) die "更新说明只能有一行" ;; esac
	local chars; chars="$(python3 -c 'import sys; print(len(sys.argv[1]))' "$notes")"
	[ "$chars" -le "$MAX_NOTES_CHARS" ] || die "更新说明 $chars 字,太长(≤$MAX_NOTES_CHARS 字):$notes"
	local live; live="$(mktemp)"
	if live_manifest macos "$live" && [ "$(field notes "$live")" = "$notes" ]; then
		die "更新说明和线上 build $(field build "$live") 的一样,忘了改 build.json 的 notes?"
	fi
	if [ "$BASE" = "$BUILD" ] && [ ! -f "$ROOT/$RELEASE_NOTES" ]; then
		die "base_build = build(老玩家都得重装):要写 $RELEASE_NOTES,第一段就说明需要重新下载安装包"
	fi
	echo "发布 v$VERSION(build $BUILD):$notes"
	output release true
	output notes "$notes"
	output release_notes "$([ -f "$ROOT/$RELEASE_NOTES" ] && echo "$RELEASE_NOTES" || true)"
}

key() {
	[ -n "${LIARS_UPDATE_SIGNING_KEY:-}" ] || die "仓库 secret LIARS_UPDATE_SIGNING_KEY 没配:内容是 ~/.config/liarstavern/update_signing_key.pem 的全文"
	local file="${RUNNER_TEMP:-/tmp}/update_signing_key.pem"
	(umask 077 && printf '%s\n' "$LIARS_UPDATE_SIGNING_KEY" > "$file")
	local derived wanted
	derived="$(openssl pkey -in "$file" -pubout 2>/dev/null | grep -v -- ----- | tr -d '\n')" \
		|| die "LIARS_UPDATE_SIGNING_KEY 不是能读的私钥"
	wanted="$(sed -n '/BEGIN PUBLIC KEY/,/END PUBLIC KEY/p' "$ROOT/src/update/update_key.gd" | grep -v -- ----- | tr -d '\n')"
	[ -n "$derived" ] && [ "$derived" = "$wanted" ] \
		|| die "LIARS_UPDATE_SIGNING_KEY 和游戏里的公钥不是一对:用它签的更新包所有已安装的游戏都不认"
	echo "LIARS_UPDATE_KEY=$file" >> "${GITHUB_ENV:-/dev/null}"
	echo "签名私钥与公钥匹配"
}

seed() {
	local manifest="$OUT/update/macos/manifest.json"
	mkdir -p "$OUT/update/macos"
	if ! live_manifest macos "$manifest"; then
		rm -f "$manifest"
		echo "! 读不到线上更新源,当作第一次发布(不比较上一版)"
		return 0
	fi
	local last_build last_version
	last_build="$(field build "$manifest")"
	last_version="$(field version "$manifest")"
	echo "$last_build" > "$OUT/update/last_build"
	if git -C "$ROOT" rev-parse --verify --quiet "v$last_version^{commit}" >/dev/null; then
		git -C "$ROOT" show "v$last_version:project.godot" | shasum -a 256 | cut -d' ' -f1 > "$OUT/update/project.godot.sha256"
	else
		echo "! 没有上一版的 tag v$last_version,检查不了 project.godot 有没有改过"
	fi
	echo "上次发布:build $last_build,v$last_version,引擎 $(field engine "$manifest")"
}

published() {
	local plat live
	live="$(mktemp)"
	for plat in macos windows; do
		live_manifest "$plat" "$live" || return 1
		cmp -s "$live" "$OUT/update/$plat/manifest.json" || return 1
	done
	echo "线上更新源已经是这一批的 build $BUILD"
}

case "${1:-}" in
	plan) plan ;;
	key) key ;;
	seed) seed ;;
	published) published ;;
	*) sed -n '2,10p' "$0"; exit 2 ;;
esac
