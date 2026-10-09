class_name Settlement
extends ColorRect
# 结算面板:胜者 + 名次(按出局先后倒序)+ 各自存活局数与扣扳机次数。房主可带全员回等待厅。
# 默认键盘焦点:房主「再来一局」,其他人「离开房间」。
# 面板停在屏幕右侧、竖直居中,只压暗右边(UiTheme.settlement_dock):左边留给结算庆祝里跳舞的胜者。


# 焦点落空时(如说明书合上后),这些键先把焦点交给默认按钮
const FOCUS_KEYS := ["ui_accept", "ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down"]

var _winner_name := ""
var _ranking: Array = []   # [{"name", "shots", "rounds", "place"}]
var _mine := false
var _default_button: Button = null


static func build_ranking(winner, elimination_order: Array, stats: Dictionary) -> Array:
	# stats: pid -> {"name", "shots", "rounds"}。胜者第 1 名,其余按出局先后倒序(最后倒下的第 2 名)
	var order := [winner]
	for i in range(elimination_order.size() - 1, -1, -1):
		if elimination_order[i] != winner:
			order.append(elimination_order[i])
	var ranking := []
	for pid in order:
		var entry: Dictionary = stats.get(pid, {"name": "?", "shots": 0, "rounds": 0}).duplicate()
		entry["place"] = ranking.size() + 1
		ranking.append(entry)
	return ranking


func _init(winner_name: String, ranking: Array, mine: bool) -> void:
	_winner_name = winner_name
	_ranking = ranking
	_mine = mine


func _ready() -> void:
	color = Color(0, 0, 0, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 面板停在右侧、只压暗右边:左边留给跳舞的胜者(规格 2026-10-09-winner-celebration)
	var dock := UiTheme.settlement_dock(self)
	var panel := _build_panel()
	dock.add_child(panel)
	_play_intro(panel)
	_focus_default.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null or not _is_focus_key(event):
		return
	get_viewport().set_input_as_handled()
	_default_button.grab_focus()


# —— 构建 ——

func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := UiTheme.panel_box(Color(0.07, 0.05, 0.04, 0.94), UiTheme.BRASS_BRIGHT, 2, 16)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 30
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var crown := UiTheme.label("最后的幸存者", 18, UiTheme.MUTED)
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(crown)
	var title := UiTheme.label(("你" if _mine else _winner_name), 64, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for entry in _ranking:
		box.add_child(_rank_row(entry))
	box.add_child(_build_buttons())
	return panel


func _rank_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var first: bool = entry["place"] == 1
	var place := UiTheme.label("第 %d 名" % entry["place"], 16, UiTheme.BRASS if first else UiTheme.MUTED)
	place.custom_minimum_size = Vector2(70, 0)
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(place)
	var name_label := UiTheme.label(entry["name"], 20, UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	# 规格 2.6:各玩家存活局数(出局者算到出局那一局,胜者算到最后一局)
	var rounds := UiTheme.label("存活 %d 局" % entry.get("rounds", 0), 16, UiTheme.PARCHMENT_DIM)
	rounds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rounds)
	var dots := ChamberDots.new(5.0)
	dots.fired = entry["shots"]
	dots.dead = not first
	row.add_child(dots)
	return row


func _build_buttons() -> HBoxContainer:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var leave := UiTheme.button("离开房间")
	leave.pressed.connect(_on_leave)
	buttons.add_child(leave)
	_default_button = leave
	if Net.is_host:
		var again := UiTheme.button("再来一局", true)
		again.pressed.connect(func():
			Sfx.play("ui_click")
			Net.request_rematch_lobby())
		buttons.add_child(again)
		_default_button = again
	else:
		buttons.add_child(UiTheme.label("等待房主开新一局…", 16, UiTheme.MUTED))
	return buttons


func _play_intro(panel: PanelContainer) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	# 从面板中心放大:高度随名次行数变化,布局完成后再定支点
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	var tween := create_tween().set_parallel()
	var scrim: Control = get_node("Scrim")
	scrim.modulate.a = 0.0
	tween.tween_property(scrim, "modulate:a", 1.0, 0.5)
	tween.tween_property(panel, "modulate:a", 1.0, 0.45)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# —— 焦点 ——

func _focus_default() -> void:
	# 延迟调用:切屏可能已把本面板移出场景树
	if not is_inside_tree():
		return
	# 说明书/确认框正拿着焦点时不抢:否则回车会在它们背后按下结算按钮
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		_default_button.grab_focus()


func _is_focus_key(event: InputEvent) -> bool:
	return FOCUS_KEYS.any(func(action: String): return event.is_action_pressed(action))


func _on_leave() -> void:
	Sfx.play("ui_click")
	Net.end_session()
