class_name UpdateBanner
extends PanelContainer
# 主菜单顶部的更新横幅:跟随 Updater 的状态显示"发现新版本 / 下载中 / 重启生效 / 为什么更新不了"。
# 没有更新相关的事时整块隐藏。


const BAR_HEIGHT := 3.0

var _title: Label
var _detail: Label
var _action: Button
var _close: Button
var _bar: ColorRect
var _bar_track: ColorRect


func _ready() -> void:
	var style := UiTheme.panel_box(Color(0.2, 0.13, 0.05, 0.92), Color(UiTheme.BRASS_BRIGHT, 0.8), 1, 8)
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_title = UiTheme.label("", 18, UiTheme.BRASS_BRIGHT, UiTheme.display_font())
	_detail = UiTheme.label("", 14, UiTheme.PARCHMENT_DIM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_title)
	text.add_child(_detail)
	_action = UiTheme.button("", true)
	_action.add_theme_font_size_override("font_size", 16)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(_on_action)
	row.add_child(_action)
	_close = UiTheme.button("×")
	_close.add_theme_font_size_override("font_size", 16)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.tooltip_text = "先不更新"
	_close.pressed.connect(func(): Updater.dismiss())
	row.add_child(_close)
	_bar_track = ColorRect.new()
	_bar_track.color = Color(UiTheme.BRASS, 0.2)
	_bar_track.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	outer.add_child(_bar_track)
	# 进度条按锚点占轨道的比例:不依赖轨道当下的像素宽度(刚显示时还没排版)
	_bar = ColorRect.new()
	_bar.color = UiTheme.BRASS_BRIGHT
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_track.add_child(_bar)
	Updater.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	Updater.changed.disconnect(_refresh)


func _refresh() -> void:
	var view := describe(Updater.state, Updater.manifest, Updater.source, Updater.message, Updater.progress)
	visible = view["visible"]
	_title.text = view["title"]
	_detail.text = view["detail"]
	_detail.visible = view["detail"] != ""
	_action.text = view["action"]
	_action.visible = view["action"] != ""
	_close.visible = view["closable"]
	_bar_track.visible = Updater.state == Updater.State.DOWNLOADING
	_bar.anchor_right = clampf(Updater.progress, 0.0, 1.0)
	_bar.offset_right = 0.0


static func describe(state: int, manifest: Dictionary, source: String, message: String, progress: float) -> Dictionary:
	# 纯函数:状态 → 横幅文字与按钮(测试直接调)
	var view := {"visible": true, "title": "", "detail": "", "action": "", "closable": false}
	match state:
		Updater.State.CHECKING:
			view["title"] = "正在检查更新…"
		Updater.State.AVAILABLE:
			view["title"] = "发现新版本 v%s" % manifest["version"]
			view["detail"] = "来自%s · %s" % [source, manifest["notes"]] if manifest["notes"] != "" else "来自%s" % source
			view["action"] = "更新"
			view["closable"] = true
		Updater.State.DOWNLOADING:
			view["title"] = "正在下载 v%s · %d%%" % [manifest["version"], roundi(progress * 100.0)]
		Updater.State.READY:
			view["title"] = "v%s 已下载好" % manifest["version"]
			view["detail"] = "重启游戏后生效"
			view["action"] = "重启"
		Updater.State.BLOCKED, Updater.State.FAILED:
			view["title"] = "暂时无法更新"
			view["detail"] = message
			view["closable"] = true
		_:
			view["visible"] = false
	return view


func _on_action() -> void:
	Sfx.play("ui_click")
	if Updater.state == Updater.State.AVAILABLE:
		Updater.download()
	elif Updater.state == Updater.State.READY:
		Updater.restart()
