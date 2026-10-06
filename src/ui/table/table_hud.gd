class_name TableHud
extends Control
# 牌桌 HUD:左上目标牌与局数、右上说明书按钮、顶部回合横幅与环形倒计时、底部出牌/质疑按钮与快捷键提示、
# 右侧事件日志、左下自己的弹巢、屏幕中央的大字宣告与自己的对话气泡。


signal play_pressed
signal challenge_pressed
signal rules_pressed

const LOG_LINES := 6

var _target_tex: TextureRect
var _target_name: Label
var _round_label: Label
var _turn_label: Label
var _turn_panel: PanelContainer
var _ring: CountdownRing
var _play_button: Button
var _challenge_button: Button
var _hint: Label
var _log_box: VBoxContainer
var _my_name: Label
var _my_dots: ChamberDots
var _my_status: Label
var _announce_box: VBoxContainer
var _announce: Label
var _announce_sub: Label
var _announce_tween: Tween = null
var _bubble_anchor: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_target_panel()
	_build_rules_button()
	_build_turn_banner()
	_build_actions()
	_build_log()
	_build_my_status()
	_build_announce()


# —— 构建 ——

func _build_target_panel() -> void:
	var panel := _corner_panel(Control.PRESET_TOP_LEFT, Vector2(24, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	_target_tex = TextureRect.new()
	_target_tex.custom_minimum_size = Vector2(54, 78)
	_target_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_tex.texture = CardFaces.texture(CardFaces.BACK)
	row.add_child(_target_tex)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	_round_label = UiTheme.label("准备开局", 14, UiTheme.MUTED)
	info.add_child(_round_label)
	info.add_child(UiTheme.label("本局目标", 15, UiTheme.PARCHMENT_DIM))
	_target_name = UiTheme.label("?", 34, UiTheme.BRASS_BRIGHT, UiTheme.display_font())
	info.add_child(_target_name)


func _build_rules_button() -> void:
	var button := UiTheme.button("规则 · %s" % OS.get_keycode_string(RulebookContent.HOTKEY))
	button.add_theme_font_size_override("font_size", 15)
	# 不抢焦点:否则点过之后空格/回车会再次触发它,而不是质疑/出牌
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): rules_pressed.emit())
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _build_turn_banner() -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position.y = 18
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_turn_panel = PanelContainer.new()
	_turn_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL, Color(UiTheme.BRASS, 0.6), 1, 22))
	_turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_turn_panel)
	_turn_label = UiTheme.label("", 22, UiTheme.PARCHMENT, UiTheme.display_font())
	_turn_panel.add_child(_turn_label)
	_ring = CountdownRing.new()
	holder.add_child(_ring)
	_turn_panel.visible = false
	_ring.visible = false


func _build_actions() -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.position.y -= 22
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.add_theme_constant_override("separation", 8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_bubble_anchor = Control.new()
	_bubble_anchor.custom_minimum_size = Vector2(0, 40)
	_bubble_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_bubble_anchor)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	holder.add_child(row)
	_challenge_button = UiTheme.button("质疑!")
	_challenge_button.custom_minimum_size = Vector2(150, 54)
	_challenge_button.add_theme_font_size_override("font_size", 26)
	_challenge_button.pressed.connect(func(): challenge_pressed.emit())
	row.add_child(_challenge_button)
	_play_button = UiTheme.button("出牌", true)
	_play_button.custom_minimum_size = Vector2(180, 54)
	_play_button.add_theme_font_size_override("font_size", 26)
	_play_button.pressed.connect(func(): play_pressed.emit())
	row.add_child(_play_button)
	_hint = UiTheme.label("", 14, UiTheme.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(_hint)
	set_actions(false, false, 0, false)


func _build_log() -> void:
	_log_box = VBoxContainer.new()
	_log_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_log_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_log_box.position.x -= 24
	_log_box.custom_minimum_size = Vector2(300, 0)
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	_log_box.add_theme_constant_override("separation", 4)
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_box)


func _build_my_status() -> void:
	var panel := _corner_panel(Control.PRESET_BOTTOM_LEFT, Vector2(24, -20))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_my_name = UiTheme.label("", 20, UiTheme.PARCHMENT, UiTheme.display_font())
	box.add_child(_my_name)
	_my_dots = ChamberDots.new(6.0)
	box.add_child(_my_dots)
	_my_status = UiTheme.label("", 13, UiTheme.MUTED)
	box.add_child(_my_status)


func _build_announce() -> void:
	_announce_box = VBoxContainer.new()
	_announce_box.set_anchors_preset(Control.PRESET_CENTER)
	_announce_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_announce_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_announce_box.position.y -= 90
	_announce_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_announce_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announce_box)
	_announce = UiTheme.label("", 76, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_theme_constant_override("shadow_offset_x", 3)
	_announce.add_theme_constant_override("shadow_offset_y", 5)
	_announce.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_announce_box.add_child(_announce)
	_announce_sub = UiTheme.label("", 24, UiTheme.PARCHMENT, UiTheme.display_font())
	_announce_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_box.add_child(_announce_sub)
	_announce_box.modulate.a = 0.0


func _corner_panel(preset: int, offset: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.5), 1, 12))
	panel.set_anchors_preset(preset)
	if preset == Control.PRESET_BOTTOM_LEFT:
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position += offset
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


# —— 更新 ——

func set_target(kind: int, round_number: int) -> void:
	_target_tex.texture = CardFaces.texture(kind)
	_target_name.text = "「%s」" % Card.NAMES.get(kind, "?")
	_round_label.text = "第 %d 局" % round_number
	var tween := create_tween()
	_target_tex.pivot_offset = _target_tex.size / 2.0
	tween.tween_property(_target_tex, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(_target_tex, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_turn(text: String, mine: bool) -> void:
	_turn_panel.visible = text != ""
	_turn_label.text = text
	_turn_label.add_theme_color_override("font_color", UiTheme.BRASS_BRIGHT if mine else UiTheme.PARCHMENT)
	var style: StyleBoxFlat = _turn_panel.get_theme_stylebox("panel")
	style.border_color = UiTheme.BRASS_BRIGHT if mine else Color(UiTheme.BRASS, 0.6)
	style.set_border_width_all(2 if mine else 1)
	if mine:
		_turn_panel.pivot_offset = _turn_panel.size / 2.0
		var tween := create_tween()
		tween.tween_property(_turn_panel, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(_turn_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_countdown(remaining: float, total: float, visible_ring: bool) -> void:
	_ring.visible = visible_ring
	if visible_ring:
		_ring.set_time(remaining, total)


func set_actions(can_play: bool, can_challenge: bool, selected: int, my_turn: bool) -> void:
	_play_button.disabled = not can_play
	_challenge_button.disabled = not can_challenge
	_play_button.text = "出牌 ×%d" % selected if selected > 0 else "出牌"
	if my_turn:
		_hint.text = "点选 1-3 张牌(或按 1-5)· Enter 出牌 · C 质疑上家"
	elif selected > 0:
		_hint.text = "已预选 %d 张,轮到你时按 Enter 出牌" % selected
	else:
		_hint.text = "可以先点选手牌预选 · %s 规则 · Esc 离开" % OS.get_keycode_string(RulebookContent.HOTKEY)


func set_actions_visible(visible_actions: bool) -> void:
	_play_button.get_parent().visible = visible_actions
	_hint.visible = visible_actions


func set_my_status(display_name: String, shots: int, alive: bool) -> void:
	_my_name.text = display_name + "(你)"
	_my_dots.fired = shots
	_my_dots.dead = not alive
	_my_status.text = "已扣扳机 %d 次 · 下一枪中弹概率 1/%d" % [shots, Revolver.CHAMBERS - shots] \
		if alive and shots < Revolver.CHAMBERS else "已出局,观战中"


func log_event(text: String, color := UiTheme.PARCHMENT) -> void:
	var label := UiTheme.label(text, 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(300, 0)
	_log_box.add_child(label)
	label.modulate.a = 0.0
	create_tween().tween_property(label, "modulate:a", 1.0, 0.25)
	while _log_box.get_child_count() > LOG_LINES:
		var oldest := _log_box.get_child(0)
		_log_box.remove_child(oldest)
		oldest.queue_free()
	for i in _log_box.get_child_count():
		var child: Control = _log_box.get_child(i)
		child.self_modulate.a = lerpf(0.35, 1.0, float(i + 1) / _log_box.get_child_count())


func announce(text: String, color: Color, sub := "", hold := 1.0) -> void:
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce.text = text
	_announce.add_theme_color_override("font_color", color)
	_announce_sub.text = sub
	_announce_box.pivot_offset = _announce_box.size / 2.0
	_announce_box.scale = Vector2(1.6, 1.6)
	_announce_box.modulate.a = 0.0
	_announce_tween = create_tween()
	_announce_tween.set_parallel()
	_announce_tween.tween_property(_announce_box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_property(_announce_box, "modulate:a", 1.0, 0.18)
	_announce_tween.chain().tween_interval(hold)
	_announce_tween.chain().tween_property(_announce_box, "modulate:a", 0.0, 0.4)


func my_bubble(text: String, color := UiTheme.INK) -> void:
	var bubble := SpeechBubble.new(text, color)
	_bubble_anchor.add_child(bubble)
	bubble.position = Vector2(-60, -10)
