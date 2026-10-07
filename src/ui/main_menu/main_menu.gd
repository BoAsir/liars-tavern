extends Control
# 主菜单:昵称 / 开设房间 / 局域网房间列表(自动发现)/ IP 直连。
# 左侧木牌面板,右侧是环绕镜头下的酒馆。面板在可滚动的侧栏里:1280x720 逻辑分辨率下整块放得下,
# 窗口再矮也只是滚动,底部的 IP 直连、状态行与页脚不会被裁掉。


const PANEL_WIDTH := 480.0
const SIDE_MARGIN := 48
const EDGE_MARGIN := 24
const ROW_GAP := 6
const ROOM_LIST_HEIGHT := 80.0   # 正好露出一个房间行,更多房间在列表内滚动

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
var _scroll: ScrollContainer
var _panel: PanelContainer
var _busy := false
var _last_join := ""    # 最近一次尝试加入的地址:被拒"版本不匹配"时据此去问房主要更新
var _scan_dots := 0.0


func _init(p_app: Node) -> void:
	app = p_app


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Discovery.rooms_updated.connect(_refresh_rooms)
	Net.join_failed.connect(_on_join_failed)
	# 传 self:旧菜单迟到的 stop_listening 不会关掉这里开的监听
	var listening := Discovery.start_listening(self)
	_scan_label.text = "正在搜索局域网房间" if listening else "无法监听局域网广播(端口被占用),请用 IP 直连"
	_refresh_rooms(Discovery.get_rooms())
	Updater.check_feed()
	_play_intro()
	_focus_default.call_deferred()


func _focus_default() -> void:
	# 默认焦点:还没有名号就先填名号,有了就落在「开设房间」,纯键盘也能直接操作。
	# 延迟执行时可能已被切走(如调试开关直接建房),不在树内就不抢
	if not is_inside_tree() or app.is_rules_open():
		return
	if _name_edit.text == "":
		_name_edit.grab_focus()
	else:
		_host_button.grab_focus()


func _exit_tree() -> void:
	# 切屏时同步调用(main 先移出再释放):立刻断开全局信号,离场的菜单不再响应
	Discovery.rooms_updated.disconnect(_refresh_rooms)
	Net.join_failed.disconnect(_on_join_failed)
	Discovery.stop_listening(self)


func _process(delta: float) -> void:
	if Discovery.is_listening() and Discovery.get_rooms().is_empty():
		_scan_dots = fmod(_scan_dots + delta * 2.0, 4.0)
		_scan_label.text = "正在搜索局域网房间" + ".".repeat(int(_scan_dots))


# —— 布局 ——

func _build() -> void:
	var column := UiTheme.side_column(self, false, SIDE_MARGIN, EDGE_MARGIN)
	_scroll = column.get_parent()
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_panel.add_theme_stylebox_override("panel", UiTheme.screen_panel(0.86, Vector2(34, 22)))
	column.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_GAP)
	_panel.add_child(box)
	_build_title(box)
	box.add_child(UpdateBanner.new())
	_build_identity(box)
	_build_rooms(box)
	_build_direct(box)
	_status = UiTheme.label("", 16, UiTheme.LIE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_build_footer(box)


func _play_intro() -> void:
	_panel.modulate.a = 0.0
	_panel.position.x -= 60
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.6)
	tween.tween_property(_panel, "position:x", _panel.position.x + 60, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_title(box: VBoxContainer) -> void:
	var title := UiTheme.label("骗子酒馆", 64, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
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
	_name_edit.text = Settings.get_string(Settings.KEY_NAME)
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
	_scan_label = UiTheme.label("", 15, UiTheme.MUTED)
	box.add_child(_scan_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ROOM_LIST_HEIGHT)
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
	_ip_edit.text = Settings.get_string(Settings.KEY_LAST_IP)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.text_submitted.connect(func(_t): _on_direct_pressed())
	row.add_child(_ip_edit)
	_join_button = UiTheme.button("加入")
	_join_button.pressed.connect(_on_direct_pressed)
	row.add_child(_join_button)


func _build_footer(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var addresses := Lan.local_private_ipv4s()
	var version := UiTheme.label("v%s · 协议 v%d · %s" % [BuildInfo.version(), Protocol.VERSION,
		"本机 " + ", ".join(addresses) if not addresses.is_empty() else "未检测到局域网地址"], 15, UiTheme.MUTED)
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 多网卡时地址很长:换行,不撑宽面板
	row.add_child(version)
	var rules := UiTheme.button("游戏规则")
	rules.add_theme_font_size_override("font_size", 15)
	rules.tooltip_text = "翻开说明书(%s)" % OS.get_keycode_string(Rulebook.HOTKEY)
	rules.pressed.connect(func(): app.show_rules())
	row.add_child(rules)
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

static func clamp_seats(players: int, capacity: int) -> Vector2i:
	# 人数与上限来自局域网报文,不可信:夹到 0..MAX_PLAYERS 且上限不小于人数,超大数字撑不爆界面
	var taken := clampi(players, 0, Protocol.MAX_PLAYERS)
	return Vector2i(taken, clampi(capacity, taken, Protocol.MAX_PLAYERS))


static func seat_dots(seats: Vector2i) -> String:
	return "●".repeat(seats.x) + "○".repeat(seats.y - seats.x)


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
	row.add_child(_room_info(room))
	var seats := clamp_seats(room["players"], room["max"])
	row.add_child(UiTheme.label(seat_dots(seats), 18, UiTheme.BRASS))
	var newer := offers_update(room, BuildInfo.build())
	if newer:
		var update := UiTheme.button("更新" if room["compatible"] else "更新后加入", not room["compatible"])
		update.add_theme_font_size_override("font_size", 15 if room["compatible"] else 18)
		update.tooltip_text = "房主是新版本 v%s,可以直接从房主这里更新" % room["ver"]
		update.pressed.connect(_update_from.bind(room["ip"], room["port"], room["host"]))
		row.add_child(update)
	if room["compatible"] or not newer:
		var join := UiTheme.button("加入")
		join.add_theme_font_size_override("font_size", 18)
		if not room["compatible"]:
			join.disabled = true
			join.text = "版本不同"
			join.tooltip_text = "房主的游戏版本和你的不一样,请让版本旧的一方更新"
		elif not room["open"]:
			join.disabled = true
			join.text = "对局中" if seats.x < seats.y else "已满"
		join.pressed.connect(_join.bind(Protocol.format_address(room["ip"], room["port"])))
		row.add_child(join)
	return panel


static func offers_update(room: Dictionary, my_build: int, my_platform := BuildInfo.platform()) -> bool:
	# 房主提供更新文件、和自己同一平台、且比自己新:列表里给出"更新"按钮
	return room.get("update", false) and room.get("plat", "") == my_platform and room.get("build", 0) > my_build


func _update_from(ip: String, port: int, host_name: String) -> void:
	Sfx.play("ui_click")
	Updater.check(Updater.lan_source(ip, port), "房主 %s" % host_name)


func _room_info(room: Dictionary) -> Control:
	# 房名与房主名来自局域网报文:过长时省略号截断,不撑宽面板
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var title := UiTheme.label(room["room"], 20, UiTheme.PARCHMENT, UiTheme.display_font())
	var host := UiTheme.label("房主 %s · %s" % [room["host"], Protocol.format_address(room["ip"], room["port"])],
		15, UiTheme.MUTED)
	for label: Label in [title, host]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(label)
	return info


# —— 操作 ——

func _on_host_pressed() -> void:
	var pname := _validated_name()
	if pname == "" or _busy:
		return
	Sfx.play("ui_click")
	var room_name := _room_edit.text.strip_edges()
	if room_name == "":
		room_name = "%s 的酒馆" % pname
	Discovery.stop_listening(self)
	var err := Net.host_game(pname, room_name)
	if err != OK:
		_show_status("开设房间失败:端口 %d-%d 都被占用(%s)" % [
			Protocol.GAME_PORT, Protocol.GAME_PORT + Protocol.GAME_PORT_ATTEMPTS - 1, error_string(err)], UiTheme.LIE)
		Discovery.start_listening(self)


func _on_direct_pressed() -> void:
	var text := _ip_edit.text.strip_edges()
	var addr := Protocol.parse_address(text)
	if not addr["ok"]:
		_show_status(addr["error"], UiTheme.LIE)
		return
	Settings.set_value(Settings.KEY_LAST_IP, text)
	_join(text)


func _join(address: String) -> void:
	var pname := _validated_name()
	if pname == "" or _busy:
		return
	Sfx.play("ui_click")
	_set_busy(true)
	_last_join = address
	_show_status("正在连接 %s …" % address, UiTheme.PARCHMENT_DIM)
	Net.join_game(pname, address)


func _on_join_failed(reason: String) -> void:
	_set_busy(false)
	_show_status(reason, UiTheme.LIE)
	Sfx.play("thud")
	if reason.contains("版本"):
		# 版本不匹配:问问房主那里有没有能用的新版本(房主比自己旧时横幅会说明)
		var addr := Protocol.parse_address(_last_join)
		if addr["ok"]:
			Updater.check(Updater.lan_source(addr["ip"], addr["port"]), "房主")
	if not Discovery.is_listening():
		Discovery.start_listening(self)


func _show_status(text: String, color: Color) -> void:
	_status.add_theme_color_override("font_color", color)
	_status.text = text
	_reveal_status()


func _reveal_status() -> void:
	# 面板高到要滚动时,把状态行(连接中 / 失败原因)滚进可视区;换行后的新尺寸要到下一帧才排好
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_scroll.ensure_control_visible(_status)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_host_button.disabled = busy
	_join_button.disabled = busy


func _validated_name() -> String:
	var pname := Protocol.sanitize_name(_name_edit.text)
	if pname == "":
		_show_status("先给自己起个名号吧", UiTheme.LIE)
		_name_edit.grab_focus()
		return ""
	Settings.set_value(Settings.KEY_NAME, pname)
	return pname


func _toggle_mute() -> void:
	Sfx.set_muted(not Sfx.muted)
	Settings.set_value(Settings.KEY_MUTED, Sfx.muted)
	_update_mute_label()


func _update_mute_label() -> void:
	_mute_button.text = "声音:关" if Sfx.muted else "声音:开"
