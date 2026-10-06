extends Control
# 主菜单:昵称 / 开设房间 / 局域网房间列表(自动发现)/ IP 直连。
# 左侧木牌面板,右侧是环绕镜头下的酒馆。


const SETTINGS_PATH := "user://settings.cfg"
const PANEL_WIDTH := 480.0

var app: Node
var _name_edit: LineEdit
var _room_edit: LineEdit
var _ip_edit: LineEdit
var _room_box: VBoxContainer
var _scan_label: Label
var _status: Label
var _host_button: Button
var _join_button: Button
var _mute_button: Button
var _panel: PanelContainer
var _busy := false
var _scan_dots := 0.0


func _init(p_app: Node) -> void:
	app = p_app


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Discovery.rooms_updated.connect(_refresh_rooms)
	Net.join_failed.connect(_on_join_failed)
	var listening := Discovery.start_listening()
	_scan_label.text = "正在搜索局域网房间" if listening else "无法监听局域网广播(端口被占用),请用 IP 直连"
	_refresh_rooms(Discovery.get_rooms())
	_panel.modulate.a = 0.0
	_panel.position.x -= 60
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.6)
	tween.tween_property(_panel, "position:x", _panel.position.x + 60, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _name_edit.text == "":
		_name_edit.grab_focus.call_deferred()


func _exit_tree() -> void:
	Discovery.stop_listening()


func _process(delta: float) -> void:
	if Discovery.is_listening() and Discovery.get_rooms().is_empty():
		_scan_dots = fmod(_scan_dots + delta * 2.0, 4.0)
		_scan_label.text = "正在搜索局域网房间" + ".".repeat(int(_scan_dots))


# —— 布局 ——

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := UiTheme.panel_box(Color(0.07, 0.05, 0.04, 0.86), Color(UiTheme.BRASS, 0.7), 2, 14)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 26
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", style)
	column.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_build_title(box)
	_build_identity(box)
	_build_rooms(box)
	_build_direct(box)
	_status = UiTheme.label("", 16, UiTheme.LIE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_build_footer(box)


func _build_title(box: VBoxContainer) -> void:
	var title := UiTheme.label("骗子酒馆", 84, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.05, 0.03, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	var subtitle := UiTheme.label("LIAR'S  TAVERN   ·   局域网吹牛出牌", 16, UiTheme.PARCHMENT_DIM, UiTheme.latin_font())
	box.add_child(subtitle)
	box.add_child(_divider())


func _build_identity(box: VBoxContainer) -> void:
	box.add_child(_section("你的名号"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "输入昵称(最多 %d 字)" % Protocol.MAX_NAME_LENGTH
	_name_edit.max_length = Protocol.MAX_NAME_LENGTH
	_name_edit.text = _load_setting("name", "")
	box.add_child(_name_edit)
	box.add_child(_section("开一桌"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_room_edit = LineEdit.new()
	_room_edit.placeholder_text = "房间名(可选)"
	_room_edit.max_length = Protocol.MAX_ROOM_NAME_LENGTH
	_room_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_edit.text_submitted.connect(func(_t): _on_host_pressed())
	row.add_child(_room_edit)
	_host_button = UiTheme.button("开设房间", true)
	_host_button.pressed.connect(_on_host_pressed)
	row.add_child(_host_button)


func _build_rooms(box: VBoxContainer) -> void:
	box.add_child(_section("局域网房间"))
	_scan_label = UiTheme.label("", 14, UiTheme.MUTED)
	box.add_child(_scan_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_room_box = VBoxContainer.new()
	_room_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_room_box)


func _build_direct(box: VBoxContainer) -> void:
	box.add_child(_section("IP 直连"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "房主 IP,如 192.168.1.8 或 IP:端口"
	_ip_edit.text = _load_setting("last_ip", "")
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _on_direct_pressed())
	row.add_child(_ip_edit)
	_join_button = UiTheme.button("加入")
	_join_button.pressed.connect(_on_direct_pressed)
	row.add_child(_join_button)


func _build_footer(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var version := UiTheme.label("协议 v%d · 本机 %s" % [Protocol.VERSION, ", ".join(Lan.local_private_ipv4s())],
		13, UiTheme.MUTED)
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(version)
	_mute_button = UiTheme.button("声音:开")
	_mute_button.add_theme_font_size_override("font_size", 15)
	_mute_button.pressed.connect(_toggle_mute)
	row.add_child(_mute_button)
	_update_mute_label()


func _section(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := UiTheme.label(text, 19, UiTheme.BRASS, UiTheme.display_font())
	row.add_child(label)
	var line := _divider()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.modulate.a = 0.45
	row.add_child(line)
	return row


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = UiTheme.BRASS
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# —— 房间列表 ——

func _refresh_rooms(rooms: Array) -> void:
	for child in _room_box.get_children():
		child.queue_free()
	if rooms.is_empty():
		var empty := UiTheme.label("暂未发现房间。可以自己开一桌,或用 IP 直连。", 15, UiTheme.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_room_box.add_child(empty)
		return
	_scan_label.text = "发现 %d 个房间" % rooms.size()
	for room in rooms:
		_room_box.add_child(_room_row(room))


func _room_row(room: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := UiTheme.panel_box(Color(0.13, 0.09, 0.06, 0.9), Color(UiTheme.BRASS, 0.35), 1, 8)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 14
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(UiTheme.label(room["room"], 20, UiTheme.PARCHMENT, UiTheme.display_font()))
	info.add_child(UiTheme.label("房主 %s · %s" % [room["host"], Protocol.format_address(room["ip"], room["port"])],
		13, UiTheme.MUTED))
	var seats := "●".repeat(room["players"]) + "○".repeat(maxi(room["max"] - room["players"], 0))
	row.add_child(UiTheme.label(seats, 18, UiTheme.BRASS))
	var join := UiTheme.button("加入")
	join.add_theme_font_size_override("font_size", 18)
	if not room["open"]:
		join.disabled = true
		join.text = "对局中" if room["players"] < room["max"] else "已满"
	join.pressed.connect(_join.bind(Protocol.format_address(room["ip"], room["port"])))
	row.add_child(join)
	return panel


# —— 操作 ——

func _on_host_pressed() -> void:
	var pname := _validated_name()
	if pname == "" or _busy:
		return
	Sfx.play("ui_click")
	var room_name := _room_edit.text.strip_edges()
	if room_name == "":
		room_name = "%s 的酒馆" % pname
	Discovery.stop_listening()
	var err := Net.host_game(pname, room_name)
	if err != OK:
		_status.text = "开设房间失败:端口 %d-%d 都被占用(%s)" % [
			Protocol.GAME_PORT, Protocol.GAME_PORT + Protocol.GAME_PORT_ATTEMPTS - 1, error_string(err)]
		Discovery.start_listening()


func _on_direct_pressed() -> void:
	var text := _ip_edit.text.strip_edges()
	var addr := Protocol.parse_address(text)
	if not addr["ok"]:
		_status.text = addr["error"]
		return
	_save_setting("last_ip", text)
	_join(text)


func _join(address: String) -> void:
	var pname := _validated_name()
	if pname == "" or _busy:
		return
	Sfx.play("ui_click")
	_set_busy(true)
	_status.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	_status.text = "正在连接 %s …" % address
	Net.join_game(pname, address)


func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_status.add_theme_color_override("font_color", UiTheme.LIE)
	_status.text = reason
	Sfx.play("thud")
	if not Discovery.is_listening():
		Discovery.start_listening()


func _set_busy(busy: bool) -> void:
	_busy = busy
	_host_button.disabled = busy
	_join_button.disabled = busy


func _validated_name() -> String:
	var pname := Protocol.sanitize_name(_name_edit.text)
	if pname == "":
		_status.add_theme_color_override("font_color", UiTheme.LIE)
		_status.text = "先给自己起个名号吧"
		_name_edit.grab_focus()
		return ""
	_save_setting("name", pname)
	return pname


func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)
	_save_setting("muted", Sfx.muted)
	_update_mute_label()


func _update_mute_label() -> void:
	_mute_button.text = "声音:关" if Sfx.muted else "声音:开"


func _load_setting(key: String, default: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		return config.get_value("player", key, default)
	return default


func _save_setting(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", key, value)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("保存设置失败:%s" % error_string(err))
