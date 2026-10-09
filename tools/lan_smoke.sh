#!/usr/bin/env bash
# 无头联机冒烟:1 个房主 + 2 个 bot 客户端(一个走局域网发现,一个直连 127.0.0.1)跑完整局。
# 通过条件:三个进程都以 0 退出、都收到 MATCH_OVER、都收到另外两人的视线与脖子同步和快捷对话、日志里没有脚本错误。
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
CAP_SECONDS="${CAP_SECONDS:-240}"
SPEED="${SPEED:-4}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/liars_smoke.XXXXXX")"

run_capped() {
	# macOS 没有 timeout 命令,用 perl alarm 兜底
	perl -e 'alarm shift; exec @ARGV' "$CAP_SECONDS" "$@"
}

COMMON=(--headless --path "$ROOT" -- --bot --fast="$SPEED" --quit-after-match)
# 每次运行用独立的游戏端口与房名:同机并行跑多份冒烟时,直连与发现都只会进自己的房间
PORT="${PORT:-$((47830 + RANDOM % 150))}"
ROOM="冒烟$$"

run_capped "$GODOT" "${COMMON[@]}" --autohost=3 --port="$PORT" --room="$ROOM" --name=房主 >"$LOG_DIR/host.log" 2>&1 &
HOST=$!
sleep 2
run_capped "$GODOT" "${COMMON[@]}" --discover="$ROOM" --name=发现 >"$LOG_DIR/discover.log" 2>&1 &
DISCOVER=$!
run_capped "$GODOT" "${COMMON[@]}" --autojoin="127.0.0.1:$PORT" --name=直连 >"$LOG_DIR/direct.log" 2>&1 &
DIRECT=$!

status=0
for pair in "host:$HOST" "discover:$DISCOVER" "direct:$DIRECT"; do
	name="${pair%%:*}"
	pid="${pair##*:}"
	if wait "$pid"; then code=0; else code=$?; fi
	log="$LOG_DIR/$name.log"
	# 脚本错误与 push_error 打出的引擎错误行都算失败
	errors=$(grep -c "SCRIPT ERROR\|^ERROR:" "$log" || true)
	# 每个进程都应收到另外两人的视线与伸出的脖子(房主直收,客户端经房主转发)
	if [ "$code" -ne 0 ] || ! grep -q "MATCH_OVER" "$log" || [ "$errors" -ne 0 ] || ! grep -q "GAZE peers=2 necks=2" "$log" || ! grep -q "QUIPS heard=2" "$log"; then
		echo "FAIL $name (exit=$code, script_errors=$errors) — 日志:$log"
		grep -A3 "SCRIPT ERROR\|FAIL" "$log" | head -20
		status=1
	else
		echo "ok   $name — $(grep -m1 MATCH_OVER "$log") · $(grep -m1 -o "GAZE peers=[0-9]* necks=[0-9]*" "$log") · $(grep -m1 -o "QUIPS heard=[0-9]*" "$log")"
	fi
done
[ "$status" -eq 0 ] && echo "联机冒烟通过(日志:$LOG_DIR)"
exit "$status"
