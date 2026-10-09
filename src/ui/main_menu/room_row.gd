extends RefCounted
# 主菜单房间列表里的一行:房名;「房主 X · 玩法 · 地址」;座位;更新 / 加入按钮。
# 房间字段来自局域网报文(RoomList 已校验类型与范围):画之前人数再夹一次,长文本省略号截断,不撑宽面板。


const DOT_SEATS_MAX := 4   # 上限不超过它时座位画成圆点;更大的桌子(德州 8 人)圆点太挤,写成「3/8」
const JOIN := "加入"
const SIT_DOWN := "入座"
const FULL := "已满"
const PLAYING := "对局中"
const OTHER_VERSION := "版本不同"


static func build(room: Dictionary, newer: bool, on_join: Callable, on_update: Callable) -> Control:
	# newer:房主提供比自己新的同平台版本,给出「更新」按钮;版本不同且能更新时只留「更新后加入」
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
	row.add_child(_info(room))
	row.add_child(UiTheme.label(seat_text(clamp_seats(room["seated"], room["cap"])), 18, UiTheme.BRASS))
	if newer:
		row.add_child(_update_button(room, on_update))
	if room["compatible"] or not newer:
		row.add_child(_join_button(room, on_join))
	return panel


static func clamp_seats(players: int, capacity: int) -> Vector2i:
	# 人数与上限来自局域网报文,不可信:夹到 0..MAX_PLAYERS 且上限不小于人数,超大数字撑不爆界面
	var taken := clampi(players, 0, Protocol.MAX_PLAYERS)
	return Vector2i(taken, clampi(capacity, taken, Protocol.MAX_PLAYERS))


static func seat_dots(seats: Vector2i) -> String:
	return "●".repeat(seats.x) + "○".repeat(seats.y - seats.x)


static func seat_text(seats: Vector2i) -> String:
	return seat_dots(seats) if seats.y <= DOT_SEATS_MAX else "%d/%d" % [seats.x, seats.y]


static func host_line(room: Dictionary) -> String:
	# 玩法只写认识的名字(不认识的写「未知玩法」):报文里的玩法 id 只截断没清洗,不能原样画出来
	return "房主 %s · %s · %s" % [room["host"], GameMode.short_label(room["mode"]),
		Protocol.format_address(room["ip"], room["port"])]


static func join_button(room: Dictionary) -> Dictionary:
	# {"text", "enabled", "tooltip"}:能进的等待厅「加入」;德州对局中还收人「入座」;满了「已满」;
	# 不收人的对局(骗子酒馆开打后、德州散局中)「对局中」;版本(或玩法)不认识「版本不同」
	if not room["compatible"]:
		return _join_state(OTHER_VERSION, false, "房主的游戏版本和你的不一样,请让版本旧的一方更新")
	if room["open"]:
		if room["playing"]:
			return _join_state(SIT_DOWN, true, "牌局进行中:入座后从下一手开始发牌")
		return _join_state(JOIN, true, "")
	# 旧房主的报文没有 playing:没满却不开放,就是在对局中
	var seats := clamp_seats(room["seated"], room["cap"])
	return _join_state(FULL if seats.x >= seats.y else PLAYING, false, "")


static func _join_state(text: String, enabled: bool, tooltip: String) -> Dictionary:
	return {"text": text, "enabled": enabled, "tooltip": tooltip}


static func _info(room: Dictionary) -> Control:
	# 房名与房主名来自局域网报文:过长时省略号截断,不撑宽面板
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var title := UiTheme.label(room["room"], 20, UiTheme.PARCHMENT, UiTheme.display_font())
	var host := UiTheme.label(host_line(room), 15, UiTheme.MUTED)
	for label: Label in [title, host]:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(label)
	return info


static func _update_button(room: Dictionary, on_update: Callable) -> Button:
	var update := UiTheme.button("更新" if room["compatible"] else "更新后加入", not room["compatible"])
	update.add_theme_font_size_override("font_size", 15 if room["compatible"] else 18)
	update.tooltip_text = "房主是新版本 v%s,可以直接从房主这里更新" % room["ver"]
	update.pressed.connect(on_update)
	return update


static func _join_button(room: Dictionary, on_join: Callable) -> Button:
	var state := join_button(room)
	var join := UiTheme.button(state["text"])
	join.add_theme_font_size_override("font_size", 18)
	join.disabled = not state["enabled"]
	join.tooltip_text = state["tooltip"]
	join.pressed.connect(on_join)
	return join
