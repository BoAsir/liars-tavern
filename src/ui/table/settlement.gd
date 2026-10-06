class_name Settlement
extends ColorRect
# 结算面板:胜者 + 名次(按出局先后倒序)+ 各自扣扳机次数。房主可带全员回等待厅。


var _winner_name := ""
var _ranking: Array = []   # [{"name", "shots", "place"}]
var _mine := false


func _init(winner_name: String, ranking: Array, mine: bool) -> void:
	_winner_name = winner_name
	_ranking = ranking
	_mine = mine


func _ready() -> void:
	color = Color(0, 0, 0, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
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
	center.add_child(panel)
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
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var leave := UiTheme.button("离开房间")
	leave.pressed.connect(_on_leave)
	buttons.add_child(leave)
	if Net.is_host:
		var again := UiTheme.button("再来一局", true)
		again.pressed.connect(func():
			Sfx.play("ui_click")
			Net.request_rematch_lobby())
		buttons.add_child(again)
		again.grab_focus.call_deferred()
	else:
		buttons.add_child(UiTheme.label("等待房主开新一局…", 16, UiTheme.MUTED))
	panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(240, 200)
	panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "color:a", 0.55, 0.5)
	tween.tween_property(panel, "modulate:a", 1.0, 0.45)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rank_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var place := UiTheme.label("第 %d 名" % entry["place"], 16, UiTheme.BRASS if entry["place"] == 1 else UiTheme.MUTED)
	place.custom_minimum_size = Vector2(70, 0)
	row.add_child(place)
	var name_label := UiTheme.label(entry["name"], 20, UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var dots := ChamberDots.new(5.0)
	dots.fired = entry["shots"]
	dots.dead = entry["place"] != 1
	row.add_child(dots)
	return row


func _on_leave() -> void:
	Sfx.play("ui_click")
	Net.leave()
	Net.left_lobby.emit("")
