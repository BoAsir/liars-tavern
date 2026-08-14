# M4:牌桌、演出、结算与收尾

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完整可玩:牌桌渲染与意图、事件队列演出(翻牌/开枪/震屏/音效)、结算与再来一局、README 与最终验收。

**Architecture:** `table.gd` 消费 `Net` 的三类信号——`state_public_updated`(渲染)、`state_private_updated`(手牌)、`game_events`(演出队列)。演出期间只入队不渲染,播完后用最新状态一次性刷新,天然解决"状态先于动画到达"的时序问题(reveal 事件自带 target 字段,不依赖可能已被新小局覆盖的公共状态)。

**依赖:** M1–M3 全部完成。

---

### Task 1: 程序化音效 Sfx

**Files:**
- Create: `src/ui/sfx.gd`
- Modify: `project.godot`(`[autoload]` 节 `Net` 行后追加)

- [ ] **Step 1: 实现 `src/ui/sfx.gd`**(白噪声合成,零外部音频资源)

```gdscript
extends Node
# 程序化音效(autoload "Sfx"):运行时合成,无需音频文件。


var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)


func click() -> void:
	_play(_make_noise(0.05, 0.35))


func bang() -> void:
	_play(_make_noise(0.45, 1.0))


func _play(stream: AudioStreamWAV) -> void:
	_player.stream = stream
	_player.play()


func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	for i in frames:
		var decay := 1.0 - float(i) / frames
		var sample := int(rng.randf_range(-1.0, 1.0) * volume * decay * decay * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
```

- [ ] **Step 2: `project.godot` 的 `[autoload]` 节追加**

```ini
Sfx="*res://src/ui/sfx.gd"
```

- [ ] **Step 3: 跑测试确认全绿,Commit**

```bash
git add src/ui/sfx.gd project.godot
git commit -m "feat: 程序化音效(click/bang)"
```

### Task 2: 牌桌主场景 table.gd

**Files:**
- Create: `src/ui/table/table.gd`

前提说明(两个接口在早期里程碑已就位,若缺失说明前置计划未按最新版执行,需先补):
- `GameState._resolve_reveal` 产出的 `reveal` 事件含 `"target"` 字段(M1b)。
- `Net.my_pid()` 返回本端 peer id(M2)。

- [ ] **Step 1: 实现 `src/ui/table/table.gd`**

```gdscript
extends Control
# 牌桌:渲染状态、发送意图、按事件队列播放演出(演出期间锁输入)。


const CARD_COLORS := {
	Card.QUEEN: Color(0.75, 0.30, 0.40),
	Card.KING: Color(0.30, 0.45, 0.75),
	Card.ACE: Color(0.80, 0.65, 0.30),
	Card.JOKER: Color(0.55, 0.35, 0.65),
}

const SettlementOverlay := preload("res://src/ui/table/settlement.gd")

var hand: Array = []
var selected := {}
var pub := {}
var animating := false
var pending_events: Array = []
var turn_deadline := 0.0

var seats_box: HBoxContainer
var target_label: Label
var pile_label: Label
var reveal_box: HBoxContainer
var turn_label: Label
var timer_label: Label
var log_label: Label
var hand_box: HBoxContainer
var play_button: Button
var challenge_button: Button


func _ready() -> void:
	_build_layout()
	Net.state_public_updated.connect(_on_public_state)
	Net.state_private_updated.connect(_on_private_state)
	Net.game_events.connect(_on_game_events)
	Net.intent_rejected.connect(_on_intent_rejected)


func _process(_delta: float) -> void:
	if pub.is_empty() or pub.get("current_pid") == null or animating:
		timer_label.text = ""
		return
	var remaining := turn_deadline - _now()
	if remaining > 0.0:
		timer_label.text = "⏱ %d 秒" % ceili(remaining)
	else:
		timer_label.text = ""


# —— 布局 ——

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	seats_box = HBoxContainer.new()
	seats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	seats_box.add_theme_constant_override("separation", 32)
	root.add_child(seats_box)

	var center := VBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 8)
	root.add_child(center)

	target_label = _centered_label(34)
	center.add_child(target_label)
	pile_label = _centered_label(20)
	center.add_child(pile_label)
	reveal_box = HBoxContainer.new()
	reveal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	reveal_box.add_theme_constant_override("separation", 8)
	center.add_child(reveal_box)
	turn_label = _centered_label(24)
	center.add_child(turn_label)
	timer_label = _centered_label(18)
	center.add_child(timer_label)
	log_label = _centered_label(16)
	log_label.modulate = Color(1.0, 0.9, 0.6)
	center.add_child(log_label)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 8)
	root.add_child(hand_box)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	root.add_child(actions)
	play_button = Button.new()
	play_button.text = "出牌"
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	actions.add_child(play_button)
	challenge_button = Button.new()
	challenge_button.text = "质疑!"
	challenge_button.disabled = true
	challenge_button.pressed.connect(_on_challenge_pressed)
	actions.add_child(challenge_button)


func _centered_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


# —— 状态与意图 ——

func _on_public_state(state: Dictionary) -> void:
	pub = state
	if not animating:
		_render()


func _on_private_state(state: Dictionary) -> void:
	hand = state["hand"]
	selected = {}
	if not animating:
		_render_hand()


func _on_intent_rejected(code: String) -> void:
	_log(Protocol.ERROR_MESSAGES.get(code, code))


func _on_play_pressed() -> void:
	Net.submit_play(selected.keys())
	selected = {}
	_update_buttons()


func _on_challenge_pressed() -> void:
	Net.submit_challenge()


func _render() -> void:
	if pub.is_empty():
		return
	target_label.text = "目标牌:「%s」" % Card.NAMES.get(pub["target"], "?")
	var last_play: Dictionary = pub["last_play"]
	if last_play.is_empty():
		pile_label.text = "桌面无牌"
	else:
		pile_label.text = "%s 声称打出 %d 张「%s」" % [
			_player_name(last_play["pid"]), last_play["count"],
			Card.NAMES.get(pub["target"], "?"),
		]
	if pub["current_pid"] == null:
		turn_label.text = ""
	elif pub["current_pid"] == Net.my_pid():
		turn_label.text = "▶ 轮到你了"
	else:
		turn_label.text = "等待 %s 行动…" % _player_name(pub["current_pid"])
	_render_seats()
	_update_buttons()


func _render_seats() -> void:
	for child in seats_box.get_children():
		child.queue_free()
	for player in pub["players"]:
		var panel := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = player["name"] + (" ◀" if player["pid"] == pub["current_pid"] else "")
		if player["pid"] == Net.my_pid():
			name_label.text += "(你)"
		if not player["alive"]:
			panel.modulate = Color(0.5, 0.5, 0.5)
		panel.add_child(name_label)
		var info := Label.new()
		if player["alive"]:
			info.text = "手牌 %d · 扣过 %d 枪" % [player["hand_count"], player["shots_fired"]]
		else:
			info.text = "已出局"
		info.add_theme_font_size_override("font_size", 13)
		panel.add_child(info)
		seats_box.add_child(panel)


func _render_hand() -> void:
	for child in hand_box.get_children():
		child.queue_free()
	for i in hand.size():
		var button := Button.new()
		button.toggle_mode = true
		button.text = Card.NAMES[hand[i]]
		button.custom_minimum_size = Vector2(64, 92)
		button.add_theme_font_size_override("font_size", 30)
		button.button_pressed = selected.has(i)
		button.toggled.connect(_on_card_toggled.bind(i))
		hand_box.add_child(button)
	_update_buttons()


func _on_card_toggled(pressed: bool, index: int) -> void:
	if pressed:
		selected[index] = true
	else:
		selected.erase(index)
	_update_buttons()


func _update_buttons() -> void:
	var my_turn: bool = (
		not pub.is_empty()
		and pub.get("current_pid") == Net.my_pid()
		and not animating
	)
	var pick := selected.size()
	play_button.disabled = not (my_turn and pick >= Rules.MIN_PLAY and pick <= Rules.MAX_PLAY)
	challenge_button.disabled = not (my_turn and not pub.get("last_play", {}).is_empty())


# —— 事件演出 ——

func _on_game_events(events: Array) -> void:
	pending_events.append_array(events)
	if not animating:
		_drain_events()


func _drain_events() -> void:
	animating = true
	_update_buttons()
	while not pending_events.is_empty():
		var ev: Dictionary = pending_events.pop_front()
		await _play_event(ev)
	animating = false
	_render()
	_render_hand()


func _play_event(ev: Dictionary) -> void:
	match ev["type"]:
		"played":
			Sfx.click()
			_log("%s 盖打 %d 张,声称全是「%s」" % [
				_player_name(ev["pid"]), ev["count"],
				Card.NAMES.get(pub.get("target", -1), "?"),
			])
			await _wait(0.5)
		"turn":
			turn_deadline = _now() + Protocol.TURN_TIMEOUT
		"reveal":
			await _play_reveal(ev)
		"gunshot":
			await _play_gunshot(ev)
		"eliminated":
			_log("%s 出局!" % _player_name(ev["pid"]))
			await _wait(0.8)
		"round_started":
			turn_deadline = _now() + Protocol.TURN_TIMEOUT
			_clear_reveal()
			_log("—— 第 %d 小局 · 目标牌「%s」——" % [ev["round"], Card.NAMES[ev["target"]]])
			await _wait(0.6)
		"match_over":
			_show_settlement(ev["winner"])


func _play_reveal(ev: Dictionary) -> void:
	_clear_reveal()
	if ev["challenger"] == null:
		_log("只剩 %s 有手牌,系统强制翻牌验证!" % _player_name(ev["pid"]))
	else:
		_log("%s 大喊:骗子!翻开 %s 的牌…" % [
			_player_name(ev["challenger"]), _player_name(ev["pid"]),
		])
	await _wait(0.8)
	for card in ev["cards"]:
		var view := _make_card_panel(card)
		reveal_box.add_child(view)
		Sfx.click()
		if Card.matches(card, ev["target"]):
			view.modulate = Color(0.7, 1.0, 0.7)
		else:
			view.modulate = Color(1.0, 0.55, 0.55)
		await _wait(0.6)
	_log("没说谎!" if ev["honest"] else "是骗子!")
	await _wait(0.9)


func _play_gunshot(ev: Dictionary) -> void:
	_log("%s 拿起左轮,对准了自己……(第 %d 次扣扳机)" % [
		_player_name(ev["pid"]), ev["shots_fired"],
	])
	await _wait(1.2)
	if ev["hit"]:
		Sfx.bang()
		_flash(Color(0.9, 0.1, 0.1, 0.4))
		await _shake()
		_log("砰!%s 中弹倒下!" % _player_name(ev["pid"]))
	else:
		Sfx.click()
		_log("咔哒——空枪!%s 长舒一口气" % _player_name(ev["pid"]))
	await _wait(0.8)


func _show_settlement(winner_pid) -> void:
	add_child(SettlementOverlay.new(_player_name(winner_pid)))


# —— 小工具 ——

func _make_card_panel(card: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLORS[card]
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(64, 92)
	var label := Label.new()
	label.text = Card.NAMES[card]
	label.add_theme_font_size_override("font_size", 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _clear_reveal() -> void:
	for child in reveal_box.get_children():
		child.queue_free()


func _shake() -> void:
	var origin := position
	var tween := create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
		tween.tween_property(self, "position", origin + offset, 0.04)
	tween.tween_property(self, "position", origin, 0.05)
	await tween.finished


func _flash(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.5)
	tween.tween_callback(rect.queue_free)


func _player_name(pid) -> String:
	if not pub.is_empty():
		for player in pub["players"]:
			if player["pid"] == pid:
				return player["name"]
	return str(pid)


func _log(text: String) -> void:
	log_label.text = text


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
```

- [ ] **Step 2: Commit**(settlement.gd 未建,preload 会报错,与 Task 3 一并验证)

```bash
git add src/ui/table/table.gd
git commit -m "feat: 牌桌场景(渲染/意图/事件演出/震屏/倒计时)"
```

### Task 3: 结算遮罩 + 接入主流程

**Files:**
- Create: `src/ui/table/settlement.gd`
- Modify: `src/ui/main.gd`(`_show_table` 换成真牌桌)

- [ ] **Step 1: 实现 `src/ui/table/settlement.gd`**

```gdscript
extends ColorRect
# 结算遮罩:展示胜者;房主可带全员回等待厅,客机等待。


var winner_name := ""


func _init(p_winner_name: String) -> void:
	winner_name = p_winner_name


func _ready() -> void:
	color = Color(0.0, 0.0, 0.0, 0.75)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "🏆 %s 活到了最后!" % winner_name
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if Net.is_host:
		var back_button := Button.new()
		back_button.text = "带大家回等待厅"
		back_button.pressed.connect(Net.request_rematch_lobby)
		box.add_child(back_button)
	else:
		var hint := Label.new()
		hint.text = "等待房主返回等待厅…"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
```

- [ ] **Step 2: 修改 `src/ui/main.gd`**

顶部常量区追加:

```gdscript
const TableScreen := preload("res://src/ui/table/table.gd")
```

将 `_show_table` 整个替换为:

```gdscript
func _show_table() -> void:
	_switch_to(TableScreen.new())
```

- [ ] **Step 3: 启动验证 + 跑测试**

Run: `$GODOT --headless --path . --quit-after 2`,然后跑测试。
Expected: 无脚本错误,测试全绿。

- [ ] **Step 4: Commit**

```bash
git add src/ui/table/settlement.gd src/ui/main.gd
git commit -m "feat: 结算遮罩与回到等待厅流程"
```

### Task 4: README 与最终验收

**Files:**
- Create: `README.md`

- [ ] **Step 1: 写 `README.md`**

```markdown
# 骗子酒馆(Liar's Tavern)

局域网 2–4 人吹牛出牌游戏(骗子牌模式)。轮流盖牌声称是目标牌,被抓包说谎或质疑失败就要对自己开一枪——活到最后的人赢。

## 运行

- 安装 [Godot 4.3+](https://godotengine.org/)(macOS 可 `brew install --cask godot`)
- 启动:`godot --path .`(或用编辑器打开后 F5)
- 导出桌面包:Godot 编辑器 → 项目 → 导出(Windows/macOS 预设)

## 联机方式

1. 任意玩家点「创建房间」成为房主。
2. 同局域网其他玩家在主菜单自动看到房间,点击加入;看不到时手输房主 IP 直连。
3. 全员准备后房主开局。

注意:
- 自动发现依赖 UDP 端口 47800 广播,同一台机器多开实例时只有一个能监听,同机测试请手输 `127.0.0.1`。
- 游戏通信走 ENet/UDP 端口 47801;防火墙需放行。
- 游戏中断线即淘汰;房主退出则房间解散。

## 规则速览

- 牌堆 20 张:Q/K/A 各 6 张 + 鬼牌 2 张(万能)。每小局抽目标牌,每人发 5 张。
- 轮到你:出 1–3 张盖牌声称全是目标牌,或质疑上家。
- 质疑翻牌:全对 → 质疑者开枪;有假 → 出牌者开枪。六膛一弹,空枪越多下次越危险。
- 只剩你有手牌时出牌会被系统强制翻牌验证。活到最后者胜。

完整规则与架构见 `docs/superpowers/specs/2026-08-14-liars-tavern-design.md`。

## 开发

- 跑单元测试:
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- 结构:`src/core/` 纯逻辑(全单测) / `src/net/` 网络 / `src/ui/` 界面。
```

- [ ] **Step 2: 双实例完整对局手动验收**

```bash
$GODOT --path . &
$GODOT --path . &
```

清单(全部通过才算完成):
1. 建房 + `127.0.0.1` 加入 + 准备 + 开局,双方进入牌桌,看到各自 5 张手牌与目标牌。
2. 房主与客机轮流出牌:选 1–3 张出牌;非自己回合按钮灰。
3. 客机质疑一次:双方同步看到逐张翻牌演出 → 开枪演出(音效/中弹震屏)→ 新小局重发牌。
4. 空枪与中弹路径都出现过(多打几局);中弹者出局变灰,不再轮到。
5. 一方挂机 30 秒:超时自动代打 1 张,游戏继续。
6. 打完一整局:结算遮罩显示胜者;房主点「带大家回等待厅」,双方回等待厅,可直接再开一局。
7. 对局中直接关闭客机窗口:房主端看到"出局"提示,若只剩一人则直接结算。
8. (有条件时)第二台真实机器:自动发现房间列表出现、点击加入成功。

- [ ] **Step 3: 跑全部测试(最终回归)**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README(运行/联机/规则/开发指引)"
```
