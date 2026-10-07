#!/usr/bin/env bash
# 把 tools/release.sh 备好的更新文件(<OUT>/update/<平台>/)发布到 GitHub 仓库的 updates 分支,
# 游戏经 raw.githubusercontent.com 读取(BuildInfo.FEED_URL)。分支每次只保留一个提交(强推),仓库不会越来越大。
# 推出去的更新所有玩家下次启动就会装上、撤不回,所以推之前逐项核对:导出记录完整且不是从脏工作区导出的,
# 两个平台是同一版、文件与清单一致,导出用的提交已经在 origin/main 上,线上现有的 build 比这次的小。
# 推送后约 5 分钟内生效(raw.githubusercontent.com 有缓存)。
# 用法:tools/publish_update.sh(先运行 tools/release.sh);OUT 默认是主仓库的 build/;需要能 git push 到 origin
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
OUT="${OUT:-${COMMON%/.git}/build}"
SRC="$OUT/update"
REMOTE="${REMOTE:-origin}"
BRANCH="updates"

for stamp in last_build last_commit; do
	[ -s "$SRC/$stamp" ] || { echo "缺少 $SRC/$stamp:先用 tools/release.sh 导出"; exit 1; }
done
BUILD="$(cat "$SRC/last_build")"
COMMIT="$(cat "$SRC/last_commit")"
case "$COMMIT" in *-dirty) echo "这批更新是从带未提交改动的工作区导出的($COMMIT),不能发布:提交后重新导出"; exit 1 ;; esac
git -C "$ROOT" fetch -q --prune "$REMOTE"
git -C "$ROOT" merge-base --is-ancestor "$COMMIT" "$REMOTE/main" \
	|| { echo "导出用的提交 ${COMMIT:0:7} 还不在 $REMOTE/main 上:先推送,玩家拿到的内容要和公开源码一致"; exit 1; }
FEED_URL="$(git -C "$ROOT" show "$COMMIT:src/update/build_info.gd" | sed -n 's/^const FEED_URL := "\(.*\)"/\1/p')"

# 两个平台的清单、签名、pck 都在,是同一版,且 pck 与清单一致;线上不比这次新
PCKS="$(python3 - "$SRC" "$BUILD" "$FEED_URL" <<'PY'
import hashlib, json, os, sys, urllib.request
src, build, feed = sys.argv[1], int(sys.argv[2]), sys.argv[3]
manifests = {}
for plat in ("macos", "windows"):   # 先把本地两个平台都查完,再和线上比
    d = os.path.join(src, plat)
    try:
        m = json.load(open(os.path.join(d, "manifest.json"), encoding="utf-8"))
    except (OSError, ValueError) as e:
        sys.exit("%s 的清单读不了:%s" % (plat, e))
    if m.get("build") != build:
        sys.exit("%s 清单是 build %s,导出记录是 build %d:这一批产物不完整,重新导出" % (plat, m.get("build"), build))
    sig = os.path.join(d, "manifest.sig")
    if not os.path.isfile(sig) or os.path.getsize(sig) == 0:
        sys.exit("%s 缺少签名 manifest.sig" % plat)
    pck = os.path.join(d, m.get("pck_file", ""))
    if not os.path.isfile(pck):
        sys.exit("%s 缺少 %s" % (plat, m.get("pck_file")))
    data = open(pck, "rb").read()
    if len(data) != m["pck_size"] or hashlib.sha256(data).hexdigest() != m["pck_sha256"]:
        sys.exit("%s 的 %s 与清单对不上" % (plat, m["pck_file"]))
    manifests[plat] = m
if len({(m["version"], m["build"]) for m in manifests.values()}) != 1:
    sys.exit("两个平台不是同一版:%s" % {p: "v%s build %s" % (m["version"], m["build"]) for p, m in manifests.items()})
for plat in manifests:
    if not feed:
        break
    try:
        live = json.load(urllib.request.urlopen(feed + plat + "/manifest.json", timeout=20))
    except Exception as e:  # 第一次发布或网络不通:不拦,只提示
        print("! 读不到线上的 %s 清单(%s),跳过线上版本比较" % (plat, e), file=sys.stderr)
        continue
    if int(live.get("build", 0)) >= build:
        sys.exit("线上 %s 已经是 build %s(v%s),不比这次的 build %d 小:换更大的 build 重新导出"
                 % (plat, live.get("build"), live.get("version"), build))
print(manifests["macos"]["pck_file"], manifests["windows"]["pck_file"])
PY
)"
read -r MAC_PCK WIN_PCK <<< "$PCKS"
URL="$(git -C "$ROOT" remote get-url "$REMOTE")"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/liars_publish.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
git -C "$STAGE" init -q -b "$BRANCH"
for pair in "macos:$MAC_PCK" "windows:$WIN_PCK"; do
	plat="${pair%%:*}"
	mkdir -p "$STAGE/$plat"
	cp "$SRC/$plat/manifest.json" "$SRC/$plat/manifest.sig" "$SRC/$plat/${pair#*:}" "$STAGE/$plat/"
done
cat > "$STAGE/README.md" <<MD
# 骗子酒馆 · 在线更新源

游戏自动读取这里的文件更新自己(build $BUILD,源码提交 ${COMMIT:0:7})。内容由发布者私钥签名,游戏只接受签名正确的更新包。
不要手动修改这个分支:它由 \`tools/publish_update.sh\` 生成,每次发布都会整体覆盖。
MD
git -C "$STAGE" add -A
git -C "$STAGE" -c user.name="$(git -C "$ROOT" config user.name)" -c user.email="$(git -C "$ROOT" config user.email)" \
	commit -q -m "update: build $BUILD (${COMMIT:0:7})"
git -C "$STAGE" push -q --force "$URL" "$BRANCH:$BRANCH"
echo "已发布 build $BUILD 到 $URL 的 $BRANCH 分支(约 5 分钟内生效)"
