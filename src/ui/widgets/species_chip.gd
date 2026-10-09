class_name SpeciesChip
extends Button
# 圆形物种头像(子项目② §3.1/§3.2):主菜单名号旁 56 px 的按钮、等待厅名单行里的小头像、挑选面板格子里的大头像。
# 头像来自 SpeciesPortraits;还没烘好(或只有回退圆片)时在色圆片上叠物种首字,
# 烘好之前每帧轮询 is_built(),换上之后停止轮询。没有形象(-1)时是灰圆片加「…」,提示「挑选中…」。


const GLYPH_RATIO := 0.5        # 首字字号 / 头像直径
const RING_WIDTH := 2
const FOCUS_EXPAND := 3
const PENDING_GLYPH := "…"

var species := Species.UNASSIGNED
var tooltip_prefix := "":      # 提示前缀,如「挑选形象:」
	set(value):
		tooltip_prefix = value
		set_species(species)
var _diameter := 56.0
var _portrait: TextureRect
var _glyph: Label


func _init(p_species := Species.UNASSIGNED, diameter := 56.0, interactive := true) -> void:
	_diameter = diameter
	custom_minimum_size = Vector2.ONE * diameter
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style(interactive)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_glyph = UiTheme.label("", maxi(int(diameter * GLYPH_RATIO), 10), UiTheme.PARCHMENT, UiTheme.display_font())
	_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph)
	if interactive:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		# 别人的头像只是展示:不抢焦点、不挡点击(提示也就不显示)
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_species(p_species)


func set_species(index: int) -> void:
	species = Species.sanitize(index)
	tooltip_text = tooltip_prefix + (Species.title(species) if species != Species.UNASSIGNED else "挑选中…")
	_refresh()


func shows_glyph() -> bool:
	return _glyph.visible


func glyph_text() -> String:
	return _glyph.text


func _process(_delta: float) -> void:
	if SpeciesPortraits.is_built():
		_refresh()


func _refresh() -> void:
	_portrait.texture = SpeciesPortraits.texture(species)
	var baked := SpeciesPortraits.is_built() and SpeciesPortraits.is_baked() and species != Species.UNASSIGNED
	_glyph.visible = not baked
	_glyph.text = Species.GLYPHS[species] if species != Species.UNASSIGNED else PENDING_GLYPH
	set_process(not SpeciesPortraits.is_built())


func _style(interactive: bool) -> void:
	# 圆形、没有内边距(否则主题按钮的内边距会把 28 px 的小头像撑大);悬停与焦点画黄铜圈
	var radius := int(ceilf(_diameter / 2.0))
	var plain := UiTheme.panel_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, radius)
	plain.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plain.set_content_margin(side, 0)
	var ring: StyleBoxFlat = plain.duplicate()
	ring.border_color = UiTheme.BRASS_BRIGHT if interactive else Color.TRANSPARENT
	ring.set_border_width_all(RING_WIDTH)
	var focus: StyleBoxFlat = ring.duplicate()
	focus.expand_margin_left = FOCUS_EXPAND
	focus.expand_margin_right = FOCUS_EXPAND
	focus.expand_margin_top = FOCUS_EXPAND
	focus.expand_margin_bottom = FOCUS_EXPAND
	for state in ["normal", "disabled"]:
		add_theme_stylebox_override(state, plain)
	for state in ["hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, ring)
	add_theme_stylebox_override("focus", focus)
