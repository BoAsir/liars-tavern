class_name RulebookBlocks
# 说明书块渲染:把 RulebookContent 的数据块变成控件。
# 配色沿用 UiTheme 的语义:黄铜=中性,绿=真话,红=假话/危险。


const BODY_SIZE := 17
const CARD_SIZE := Vector2(66, 95)
const CARD_FAN_DEGREES := 3.0
const TONES := {"brass": UiTheme.BRASS_BRIGHT, "truth": UiTheme.TRUTH, "lie": UiTheme.LIE}


static func build(block: Dictionary) -> Control:
	match block["type"]:
		"lead":
			return _paragraph(block["text"], 21, UiTheme.PARCHMENT, UiTheme.display_font())
		"text":
			return _paragraph(block["text"], BODY_SIZE, UiTheme.PARCHMENT_DIM)
		"bullets":
			return _bullets(block["items"])
		"note":
			return _note(block["text"])
		"cards":
			return _cards(block["items"])
		"pair":
			return _pair(block["items"])
		"odds":
			return _odds(block["items"])
		"keys":
			return _keys(block["items"])
	push_warning("说明书:未知的块类型 %s" % block["type"])
	return Control.new()


# —— 文字 ——

static func _paragraph(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := UiTheme.label(text, font_size, color, font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_constant_override("line_spacing", 5)
	return label


static func _bullets(items: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var mark := UiTheme.label("◆", 10, UiTheme.BRASS)
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mark.custom_minimum_size.y = UiTheme.body_font().get_height(BODY_SIZE)
		row.add_child(mark)
		row.add_child(_paragraph(item, BODY_SIZE, UiTheme.PARCHMENT))
	return box


static func _note(text: String) -> Control:
	var panel := PanelContainer.new()
	var style := UiTheme.panel_box(Color(UiTheme.BRASS, 0.09), UiTheme.BRASS, 0, 4)
	style.border_width_left = 3
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var tag := UiTheme.label("提示", 15, UiTheme.BRASS, UiTheme.display_font())
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tag)
	row.add_child(_paragraph(text, 16, UiTheme.PARCHMENT))
	return panel


# —— 牌堆:牌面 + 张数,微微扇开 ——

static func _cards(items: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	for i in items.size():
		var item: Dictionary = items[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		row.add_child(col)
		var face := TextureRect.new()
		face.texture = CardFaces.texture(item["kind"])
		face.custom_minimum_size = CARD_SIZE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.pivot_offset = CARD_SIZE / 2.0
		face.rotation = deg_to_rad((i - (items.size() - 1) / 2.0) * CARD_FAN_DEGREES)
		col.add_child(face)
		var count := UiTheme.label("× %d" % item["count"], 22, UiTheme.BRASS_BRIGHT, UiTheme.latin_font())
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(count)
		var caption := UiTheme.label(item.get("caption", ""), 13, UiTheme.MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(caption)
	return row


# —— 二选一对照:出牌/质疑、真话/假话 ——

static func _pair(items: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for item in items:
		var tone: Color = TONES.get(item["tone"], UiTheme.BRASS_BRIGHT)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := UiTheme.panel_box(Color(tone, 0.07), Color(tone, 0.55), 1, 10)
		style.border_width_top = 3
		panel.add_theme_stylebox_override("panel", style)
		row.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		box.add_child(UiTheme.label(item["title"], 26, tone, UiTheme.display_font()))
		box.add_child(_paragraph(item["body"], 16, UiTheme.PARCHMENT))
		if item.has("result"):
			box.add_child(UiTheme.label("→ " + item["result"], 19, tone, UiTheme.display_font()))
	return row


# —— 左轮:每一枪的中弹概率 ——

static func _odds(items: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	var first: float = items[0]["chance"]
	for i in items.size():
		var item: Dictionary = items[i]
		var chance: float = item["chance"]
		var danger := inverse_lerp(first, 1.0, chance) if first < 1.0 else 1.0
		var tint := UiTheme.BRASS.lerp(UiTheme.BLOOD, danger)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var shot := UiTheme.label("第 %d 枪" % item["shot"], 16, UiTheme.PARCHMENT_DIM)
		shot.custom_minimum_size.x = 64
		row.add_child(shot)
		var dots := ChamberDots.new(4.5)
		dots.fired = item["shot"] - 1
		dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dots)
		row.add_child(OddsBar.new(chance, tint, i))
		var text := "必中" if chance >= 1.0 else "1/%d · %d%%" % [roundi(1.0 / chance), roundi(chance * 100.0)]
		var odds := UiTheme.label(text, 16, tint.lightened(0.25), UiTheme.display_font())
		odds.custom_minimum_size.x = 96
		odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(odds)
	return box


class OddsBar extends Control:
	const STAGGER := 0.06
	const GROW_TIME := 0.45

	var ratio := 0.0
	var tint := Color.WHITE
	var shown := 0.0:
		set(value):
			shown = value
			queue_redraw()
	var _index := 0

	func _init(p_ratio: float, p_tint: Color, index: int) -> void:
		ratio = p_ratio
		tint = p_tint
		_index = index
		custom_minimum_size = Vector2(120, 12)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		create_tween().tween_property(self, "shown", ratio, GROW_TIME) \
			.set_delay(_index * STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var radius := int(size.y / 2.0)
		UiTheme.flat(Color(0, 0, 0, 0.4), radius).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if shown > 0.0:
			var fill := Rect2(Vector2.ZERO, Vector2(maxf(size.x * shown, size.y), size.y))
			UiTheme.flat(tint, radius).draw(get_canvas_item(), fill)


# —— 操作键位 ——

static func _keys(items: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 12)
	for header in ["操作", "键盘", "鼠标"]:
		grid.add_child(UiTheme.label(header, 13, UiTheme.MUTED))
	for item in items:
		var action := UiTheme.label(item["action"], BODY_SIZE, UiTheme.PARCHMENT)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(action)
		var caps := HBoxContainer.new()
		caps.add_theme_constant_override("separation", 6)
		for key in item["keys"]:
			caps.add_child(_keycap(key))
		grid.add_child(caps)
		grid.add_child(UiTheme.label(item["mouse"] if item["mouse"] != "" else "—", 15, UiTheme.PARCHMENT_DIM))
	return grid


static func _keycap(text: String) -> Control:
	var panel := PanelContainer.new()
	var style := UiTheme.panel_box(Color(0.16, 0.11, 0.07), Color(UiTheme.BRASS, 0.7), 1, 5)
	style.border_width_bottom = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 34
	var label := UiTheme.label(text, 15, UiTheme.BRASS_BRIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
