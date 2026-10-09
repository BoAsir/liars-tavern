class_name BetControls
extends PanelContainer
# 德州下注控件(规格 §6.2,底部中间 ≤ 600×170):回合横幅与倒计时环一行;5 个预设 + 滑条 + 金额一行;
# 弃牌 / 过牌或跟注 / 下注或加注到 / 全下 四个按钮;一行快捷键提示。
# 只发信号,不直接调用 Net / Sfx(截图工具能离线摆出整套 HUD);快捷键由牌桌的 _unhandled_input 转给 handle_key。
# 所有控件 focus_mode = FOCUS_NONE:焦点留在按钮或滑条上会吃掉空格 / 回车 / 方向键。
# 不是自己的回合时只留回合横幅那一行(「等待 X 行动…」+ 对方的倒计时),其余行收起。
# 与牌桌(PokerScreen)的约定:每个公共视图都调 update(pub, my_pid),包括 actions 为空或轮到别人的;
# 「新回合」= 视图里的 hand / street / current_pid 变了,或自己的合法动作集合变了——新回合金额回到最小加注,
# 同一回合里的刷新(倒计时、旁人再领)保留已调好的金额。合并视图也不会漏掉新一条街。


signal action_chosen(action: String, amount: int)   # 与 Net.submit_poker_action 同形
signal fold_confirm_requested                        # 能免费过牌时点了「弃牌」按钮:由牌桌弹确认框
signal free_check_hinted                             # 能免费过牌时按了 F:不弃牌,只提示

const MAX_SIZE := Vector2(600, 170)
const SLIDER_WIDTH := 220.0
const AMOUNT_WIDTH := 64.0
const BUTTON_HEIGHT := 46.0
const BUTTON_FONT := 19
const BUTTON_PADDING := Vector2(14, 4)
const PRESET_FONT := 14
const PRESET_PADDING := Vector2(8, 3)
const HINT_FONT := 13
const ROW_GAP := 4
const PANEL_PADDING := Vector2(10, 6)
const PRESET_LABELS := ["最小", "½ 池", "¾ 池", "1 池", "全下"]
const PRESET_FRACTIONS := {1: 0.5, 2: 0.75, 3: 1.0}   # 下标 0 是最小加注,4 是全下
const HOTKEY_HINT := "F 弃牌 · C/空格/回车 过牌或跟注 · R 加注 · ↑↓ 调一个大盲 · 1–5 预设"
const FREE_CHECK_HINT := "可以免费过牌"
const REASON_SHORT := "筹码只够跟注"
const REASON_ALL_IN := "对手都已全下"
const REASON_NOT_REOPENED := "不完整加注不重开"
const LEGAL_INTS := ["to_call", "call_amount", "min_raise_to", "max_raise_to"]
const LEGAL_BOOLS := ["can_check", "can_raise", "can_allin"]

var _situation := {"legal": {}, "current_bet": 0, "pot": 0, "opponents_live": 0, "turn": [null, null, null]}
var _presets: Array = []
var _amount := 0
var _my_turn := false
var _turn_panel: PanelContainer
var _turn_label: Label
var _ring: CountdownRing
var _amount_row: HBoxContainer
var _preset_buttons: Array = []
var _slider: HSlider
var _amount_label: Label
var _button_row: HBoxContainer
var _fold_button: Button
var _check_call_button: Button
var _raise_button: Button
var _allin_button: Button
var _hint: Label


# —— 纯逻辑 ——

static func situation(pub: Dictionary, my_pid: int) -> Dictionary:
	# 从公共视图取下注控件要的几个数;视图来自网络,类型不对一律当作没有
	var legal := _legal_of(pub.get("actions"), my_pid)
	var pot := 0
	var live := 0
	for pot_row in _as_array(pub.get("pots")):
		if pot_row is Dictionary and pot_row.get("amount") is int:
			pot += maxi(pot_row["amount"], 0)
	for p in _as_array(pub.get("players")):
		if not p is Dictionary:
			continue
		if p.get("bet") is int:
			pot += maxi(p["bet"], 0)
		if p.get("pid") != my_pid and p.get("status") == PokerRules.STATUS_ACTIVE and not PokerNameplate.has_left(p):
			live += 1
	var current_bet: int = pub["current_bet"] if pub.get("current_bet") is int else 0
	return {"legal": legal, "current_bet": current_bet, "pot": pot, "opponents_live": live, "turn": turn_key(pub)}


static func turn_key(pub: Dictionary) -> Array:
	# 回合身份:第几手、哪条街、轮到谁;类型不对当空
	var hand: Variant = pub.get("hand")
	var street: Variant = pub.get("street")
	var current: Variant = pub.get("current_pid")
	return [hand if hand is int else null, street if street is String else null, current if current is int else null]


static func raise_target(fraction: float, pot: int, current_bet: int, to_call: int) -> float:
	# 本轮没人下注:下注到 pot × f;有人下注:加注到 当前最高 + (pot + to_call) × f
	if current_bet <= 0:
		return pot * fraction
	return current_bet + (pot + to_call) * fraction


static func round_to_unit(amount: float) -> int:
	return int(round(amount / PokerRules.CHIP_UNIT)) * PokerRules.CHIP_UNIT


static func clamp_amount(amount: int, legal: Dictionary) -> int:
	var low: int = legal.get("min_raise_to", 0)
	var high: int = maxi(legal.get("max_raise_to", 0), low)
	return clampi(round_to_unit(amount), low, high)


static func preset_amounts(s: Dictionary) -> Array:
	# 5 个预设:最小、½ 池、¾ 池、1 池、全下,都已夹到合法范围
	var legal: Dictionary = s["legal"]
	if legal.is_empty():
		return []
	var out := [legal["min_raise_to"]]
	for i in [1, 2, 3]:
		var raw := raise_target(PRESET_FRACTIONS[i], s["pot"], s["current_bet"], legal["to_call"])
		out.append(clamp_amount(round_to_unit(raw), legal))
	out.append(maxi(legal["max_raise_to"], legal["min_raise_to"]))
	return out


static func labels(legal: Dictionary, current_bet: int, amount: int) -> Dictionary:
	var check_call := "过牌"
	if not legal.get("can_check", false):
		var short: bool = legal.get("call_amount", 0) < legal.get("to_call", 0)
		check_call = ("全下跟注 %s" if short else "跟注 %s") % ChipText.format(legal.get("call_amount", 0))
	return {
		"fold": "弃牌",
		"check_call": check_call,
		"raise": ("下注 %s" if current_bet <= 0 else "加注到 %s") % ChipText.format(amount),
		"allin": "全下 %s" % ChipText.format(legal.get("max_raise_to", 0)),
	}


static func raise_block_reason(s: Dictionary) -> String:
	# 不能加注时悬停提示的原因;能加注(或不是自己的回合)为空
	var legal: Dictionary = s["legal"]
	if legal.is_empty() or legal["can_raise"]:
		return ""
	if legal["max_raise_to"] <= s["current_bet"]:
		return REASON_SHORT
	if s["opponents_live"] == 0:
		return REASON_ALL_IN
	return REASON_NOT_REOPENED


static func hotkey(keycode: int) -> Dictionary:
	# 规格 §6.2 的快捷键;WASD 是探头、Esc 是离开,不在这里
	match keycode:
		KEY_F:
			return {"kind": "fold"}
		KEY_C, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			return {"kind": "check_call"}   # 回车是默认动作:过牌 / 跟注(用户要求默认选过牌)
		KEY_R:
			return {"kind": "raise"}
		KEY_UP:
			return {"kind": "step", "delta": 1}
		KEY_DOWN:
			return {"kind": "step", "delta": -1}
	if keycode >= KEY_1 and keycode <= KEY_5:
		return {"kind": "preset", "index": keycode - KEY_1}
	return {}


static func _legal_of(actions: Variant, my_pid: int) -> Dictionary:
	if not actions is Dictionary or actions.get("pid") != my_pid:
		return {}
	for key in LEGAL_INTS:
		if not actions.get(key) is int:
			return {}
	for key in LEGAL_BOOLS:
		if not actions.get(key) is bool:
			return {}
	return actions.duplicate()


static func _as_array(value: Variant) -> Array:
	return value if value is Array else []


# —— 构建 ——

func _ready() -> void:
	var style := UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.5), 1, 12)
	style.content_margin_left = PANEL_PADDING.x
	style.content_margin_right = PANEL_PADDING.x
	style.content_margin_top = PANEL_PADDING.y
	style.content_margin_bottom = PANEL_PADDING.y
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(_build_turn_row())
	box.add_child(_build_amount_row())
	box.add_child(_build_button_row())
	_hint = UiTheme.label(HOTKEY_HINT, HINT_FONT, UiTheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	_apply_turn(false)


func _build_turn_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_panel = PanelContainer.new()
	var style := UiTheme.panel_box(UiTheme.PANEL, Color(UiTheme.BRASS, 0.6), 1, 22)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_turn_panel.add_theme_stylebox_override("panel", style)
	_turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_panel.resized.connect(func(): _turn_panel.pivot_offset = _turn_panel.size / 2.0)
	row.add_child(_turn_panel)
	_turn_label = UiTheme.label("", 20, UiTheme.PARCHMENT, UiTheme.display_font())
	_turn_panel.add_child(_turn_label)
	_ring = CountdownRing.new()
	row.add_child(_ring)
	_turn_panel.visible = false
	_ring.visible = false
	return row


func _build_amount_row() -> HBoxContainer:
	_amount_row = HBoxContainer.new()
	_amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_amount_row.add_theme_constant_override("separation", 4)
	_amount_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PRESET_LABELS.size():
		var preset := _compact_button(PRESET_LABELS[i], PRESET_FONT, PRESET_PADDING)
		preset.pressed.connect(_on_preset.bind(i))
		_amount_row.add_child(preset)
		_preset_buttons.append(preset)
	_slider = HSlider.new()
	_slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.step = PokerRules.CHIP_UNIT
	_slider.value_changed.connect(_on_slider)
	_amount_row.add_child(_slider)
	_amount_label = UiTheme.label("", 16, UiTheme.BRASS_BRIGHT, UiTheme.body_font())
	_amount_label.custom_minimum_size = Vector2(AMOUNT_WIDTH, 0)
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_amount_row.add_child(_amount_label)
	return _amount_row


func _build_button_row() -> HBoxContainer:
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 10)
	_button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fold_button = _action_button("弃牌", false)
	_fold_button.pressed.connect(_on_fold)
	# 默认动作是过牌 / 跟注:它是高亮的主按钮,回车也按它;加注要主动点或按 R
	_check_call_button = _action_button("过牌", true)
	_check_call_button.pressed.connect(_check_or_call)
	_raise_button = _action_button("加注到", false)
	_raise_button.pressed.connect(func(): action_chosen.emit(PokerRules.RAISE, _amount))
	_allin_button = _action_button("全下", false)
	_allin_button.pressed.connect(func(): action_chosen.emit(PokerRules.ALLIN, 0))
	return _button_row


func _action_button(text: String, primary: bool) -> Button:
	var button := UiTheme.button(text, primary)
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.focus_mode = Control.FOCUS_NONE
	_shrink_padding(button, BUTTON_PADDING)
	_button_row.add_child(button)
	return button


func _compact_button(text: String, font_size: int, padding: Vector2) -> Button:
	var button := UiTheme.button(text)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	_shrink_padding(button, padding)
	return button


func _shrink_padding(button: Button, padding: Vector2) -> void:
	# 主题按钮的内边距(22/10)是给主菜单的;这里一行要挤 5 个预设 + 滑条,或 4 个 46 像素高的按钮
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = padding.x
		box.content_margin_right = padding.x
		box.content_margin_top = padding.y
		box.content_margin_bottom = padding.y
		box.shadow_size = 0
		button.add_theme_stylebox_override(state, box)


# —— 更新 ——

func update(pub: Dictionary, my_pid: int) -> void:
	var fresh := situation(pub, my_pid)
	if fresh["legal"].is_empty():
		# 收起控件(演出中 / 别人的回合),但记住上一个回合:同一回合恢复时保留已调好的金额
		_presets = []
		_apply_turn(false)
		return
	var new_turn: bool = fresh["turn"] != _situation["turn"] or fresh["legal"] != _situation["legal"]
	_situation = fresh
	_presets = preset_amounts(fresh)
	_apply_turn(not _presets.is_empty())
	if not _my_turn:
		return
	var legal: Dictionary = fresh["legal"]
	var low: int = legal["min_raise_to"]
	var high: int = maxi(legal["max_raise_to"], low)
	_slider.set_block_signals(true)
	_slider.min_value = low
	_slider.max_value = high
	_slider.set_block_signals(false)
	var reason := raise_block_reason(fresh)
	var can_raise: bool = legal["can_raise"]
	_raise_button.disabled = not can_raise
	_raise_button.tooltip_text = reason
	_allin_button.disabled = not legal["can_allin"]
	_allin_button.tooltip_text = "" if legal["can_allin"] else reason
	_slider.editable = can_raise and high > low
	_slider.tooltip_text = reason
	for preset in _preset_buttons:
		(preset as Button).disabled = not can_raise
		(preset as Button).tooltip_text = reason
	# 新回合从最小加注开始;同一回合里的刷新(倒计时、旁人再领)保留已调好的金额
	set_amount(low if new_turn else _amount)
	if _hint.text != FREE_CHECK_HINT or new_turn:
		_hint.text = HOTKEY_HINT


func _apply_turn(my_turn: bool) -> void:
	_my_turn = my_turn
	_amount_row.visible = my_turn
	_button_row.visible = my_turn
	_hint.visible = my_turn


func set_turn(text: String, mine: bool) -> void:
	_turn_panel.visible = text != ""
	_turn_label.text = text
	_turn_label.add_theme_color_override("font_color", UiTheme.BRASS_BRIGHT if mine else UiTheme.PARCHMENT)
	var style: StyleBoxFlat = _turn_panel.get_theme_stylebox("panel")
	style.border_color = UiTheme.BRASS_BRIGHT if mine else Color(UiTheme.BRASS, 0.6)
	style.set_border_width_all(2 if mine else 1)
	if mine:
		var tween := create_tween()
		tween.tween_property(_turn_panel, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(_turn_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_countdown(remaining: float, total: float) -> void:
	_ring.visible = true
	_ring.set_time(remaining, total)


func hide_countdown() -> void:
	_ring.visible = false


func amount() -> int:
	return _amount


func set_amount(value: int) -> void:
	var legal: Dictionary = _situation["legal"]
	if legal.is_empty():
		return
	_amount = clamp_amount(value, legal)
	_slider.set_block_signals(true)
	_slider.value = _amount
	_slider.set_block_signals(false)
	_amount_label.text = ChipText.format(_amount)
	var texts := labels(legal, _situation["current_bet"], _amount)
	_fold_button.text = texts["fold"]
	_check_call_button.text = texts["check_call"]
	_raise_button.text = texts["raise"]
	_allin_button.text = texts["allin"]


func is_my_turn() -> bool:
	return _my_turn


# —— 输入 ——

func handle_key(keycode: int) -> bool:
	# 牌桌在轮到自己、没有说明书/确认框打开时把按键转到这里;返回真表示已处理
	if not _my_turn:
		return false
	var key := hotkey(keycode)
	match key.get("kind", ""):
		"fold":
			_fold_by_key()
		"check_call":
			_check_or_call()
		"raise":
			if _raise_button.disabled:
				return false
			action_chosen.emit(PokerRules.RAISE, _amount)
		"step":
			if not _slider.editable:
				return false
			set_amount(_amount + key["delta"] * PokerRules.BIG_BLIND)
		"preset":
			if _raise_button.disabled:
				return false
			set_amount(_presets[key["index"]])
		_:
			return false
	return true


func _fold_by_key() -> void:
	# 能免费过牌时按 F 不弃牌(误按会白送一手),只提示
	if _situation["legal"]["can_check"]:
		_hint.text = FREE_CHECK_HINT
		free_check_hinted.emit()
	else:
		action_chosen.emit(PokerRules.FOLD, 0)


func _on_fold() -> void:
	if _situation["legal"].get("can_check", false):
		fold_confirm_requested.emit()
	else:
		action_chosen.emit(PokerRules.FOLD, 0)


func _check_or_call() -> void:
	var legal: Dictionary = _situation["legal"]
	action_chosen.emit(PokerRules.CHECK if legal["can_check"] else PokerRules.CALL, 0)


func _on_preset(index: int) -> void:
	set_amount(_presets[index])


func _on_slider(value: float) -> void:
	set_amount(int(value))
