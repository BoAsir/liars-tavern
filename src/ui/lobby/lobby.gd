extends Control
# 等待厅:右侧面板(房名、房主地址、玩家列表、准备/开局/踢人/离开),
# 3D 场景中已加入的玩家以酒客形象落座,头顶显示名字与准备状态。


const PANEL_WIDTH := 440.0

var app: Node
var _title: Label
var _address: Label
var _list: VBoxContainer
var _status: Label
var _ready_button: Button = null
var _start_button: Button = null
var _is_ready := false
var _known := {}


func _init(p_app: Node) -> void:
	app = p_app


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Net.lobby_updated.connect(_refresh)
	# 从结算回来:收走桌上的牌与左轮,倒下的酒客重新登场
	app.world.cards.clear_all()
	app.world.revive_all()
	app.labels.clear()
	app.tavern.camera_rig.move_to(app.world.overview_view(), 1.8)
	_known = {}
	for p in Net.lobby_players:
		_known[p["pid"]] = p["name"]
	_refresh(Net.lobby_players)


func _exit_tree() -> void:
	for pid in _known:
		app.labels.untrack("lobby:%d" % pid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_leave_pressed()


# —— 布局 ——

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := UiTheme.panel_box(Color(0.07, 0.05, 0.04, 0.86), Color(UiTheme.BRASS, 0.7), 2, 14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	column.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.label("等待厅", 15, UiTheme.MUTED))
	_title = UiTheme.label(Net.lobby_meta.get("room", "酒馆"), 34, UiTheme.BRASS_BRIGHT, UiTheme.display_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	box.add_child(_address_row())
	box.add_child(UiTheme.label("同一局域网的玩家会在房间列表中看到这里;\n也可以把上面的地址告诉他们直连。", 13, UiTheme.MUTED))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	_status = UiTheme.label("", 15, UiTheme.PARCHMENT_DIM)
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var leave := UiTheme.button("离开")
	leave.pressed.connect(_on_leave_pressed)
	buttons.add_child(leave)
	var rules := UiTheme.button("规则")
	rules.tooltip_text = "翻开说明书(%s)" % OS.get_keycode_string(Rulebook.HOTKEY)
	rules.pressed.connect(func(): app.show_rules())
	buttons.add_child(rules)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	if Net.is_host:
		_start_button = UiTheme.button("开始游戏", true)
		_start_button.disabled = true
		_start_button.pressed.connect(_on_start_pressed)
		buttons.add_child(_start_button)
	else:
		_ready_button = UiTheme.button("准备", true)
		_ready_button.pressed.connect(_on_ready_toggled)
		buttons.add_child(_ready_button)


func _address_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label("房主地址", 15, UiTheme.MUTED))
	_address = UiTheme.label("", 20, UiTheme.PARCHMENT, UiTheme.latin_font())
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_address)
	var copy := UiTheme.button("复制")
	copy.add_theme_font_size_override("font_size", 15)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_address.text.split("  ")[0])
		app.toast("已复制房主地址"))
	row.add_child(copy)
	return row


# —— 刷新 ——

func _refresh(players: Array) -> void:
	_title.text = Net.lobby_meta.get("room", _title.text)
	var addresses: Array = Net.lobby_meta.get("addresses", [])
	var port: int = Net.lobby_meta.get("port", Protocol.GAME_PORT)
	_address.text = "  ".join(addresses.map(func(ip): return Protocol.format_address(ip, port))) \
		if not addresses.is_empty() else Protocol.format_address("127.0.0.1", port)
	_announce_changes(players)
	app.world.arrange(players, Net.my_pid(), true, false)
	for child in _list.get_children():
		child.queue_free()
	for i in players.size():
		_list.add_child(_player_row(players[i], i))
		_track_nameplate(players[i])
	var ready_count := players.filter(func(p): return p["ready"]).size()
	_status.text = "%d/%d 人 · %d 人已准备" % [players.size(), Protocol.MAX_PLAYERS, ready_count]
	if players.size() < Protocol.MIN_PLAYERS:
		_status.text += " · 至少 %d 人才能开局" % Protocol.MIN_PLAYERS
	elif Net.is_host and not Net.can_start():
		_status.text += " · 等待全员准备"
	if _start_button != null:
		_start_button.disabled = not Net.can_start()


func _announce_changes(players: Array) -> void:
	var now := {}
	for p in players:
		now[p["pid"]] = p["name"]
		if not _known.has(p["pid"]):
			app.toast("%s 走进了酒馆" % p["name"], UiTheme.BRASS_BRIGHT)
			Sfx.play("join")
	for pid in _known:
		if not now.has(pid):
			app.toast("%s 离开了" % _known[pid], UiTheme.MUTED)
			app.labels.untrack("lobby:%d" % pid)
	_known = now


func _player_row(player: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	var mine: bool = player["pid"] == Net.my_pid()
	var style := UiTheme.panel_box(Color(0.13, 0.09, 0.06, 0.9), Color(UiTheme.BRASS, 0.7 if mine else 0.3), 1, 8)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var species := PatronParts.species(index)
	var name_label := UiTheme.label(player["name"] + ("(你)" if mine else ""), 19, UiTheme.PARCHMENT,
		UiTheme.display_font())
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UiTheme.label(species["label"], 14, species["fur"].lightened(0.3)))
	row.add_child(name_label)
	if player["is_host"]:
		row.add_child(UiTheme.label("房主", 14, UiTheme.BRASS))
	var badge := UiTheme.label("已准备" if player["ready"] else "未准备", 15,
		UiTheme.TRUTH if player["ready"] else UiTheme.MUTED)
	row.add_child(badge)
	if Net.is_host and not player["is_host"]:
		var kick := UiTheme.button("请出")
		kick.add_theme_font_size_override("font_size", 14)
		kick.pressed.connect(func():
			var overlay: ConfirmOverlay = app.confirm("把 %s 请出酒馆?" % player["name"], "请出")
			overlay.confirmed.connect(Net.kick.bind(player["pid"])))
		row.add_child(kick)
	return panel


func _track_nameplate(player: Dictionary) -> void:
	var pid: int = player["pid"]
	if not app.world.patrons.has(pid):
		return
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL_SOFT,
		UiTheme.TRUTH if player["ready"] else Color(UiTheme.BRASS, 0.5), 1, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	plate.add_child(box)
	var name_label := UiTheme.label(player["name"], 18, UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var state := UiTheme.label("✓ 已准备" if player["ready"] else "…", 13, UiTheme.TRUTH if player["ready"] else UiTheme.MUTED)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(state)
	var patron: Patron = app.world.patrons[pid]
	app.labels.track("lobby:%d" % pid, plate, patron.nameplate_anchor)


# —— 操作 ——

func _on_start_pressed() -> void:
	Sfx.play("ui_click")
	Net.start_game()


func _on_ready_toggled() -> void:
	Sfx.play("ui_click")
	_is_ready = not _is_ready
	_ready_button.text = "取消准备" if _is_ready else "准备"
	Net.set_ready(_is_ready)


func _on_leave_pressed() -> void:
	var overlay: ConfirmOverlay = app.confirm("确定离开房间吗?" + ("\n你是房主,离开后房间会解散。" if Net.is_host else ""), "离开")
	overlay.confirmed.connect(func():
		Net.leave()
		Net.left_lobby.emit(""))
