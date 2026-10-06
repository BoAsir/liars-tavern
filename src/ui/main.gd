extends Node
# 入口:常驻 3D 酒馆 + 后处理 + 2D 屏幕(主菜单 / 等待厅 / 牌桌)切换。
# 各屏幕通过 app(本节点)访问酒馆、角色层、后处理、铭牌层与提示条。


const MainMenuScreen := preload("res://src/ui/main_menu/main_menu.gd")
const LobbyScreen := preload("res://src/ui/lobby/lobby.gd")
const TableScreen := preload("res://src/ui/table/table_screen.gd")

var tavern: Tavern
var world: TableWorld
var post_fx: PostFx
var labels: WorldLabels
var toasts: ToastLayer
var flags: DebugFlags

var _ui: Control
var _screen: Control = null


func _ready() -> void:
	get_window().min_size = Vector2i(1024, 600)
	get_tree().auto_accept_quit = false
	tavern = Tavern.new()
	add_child(tavern)
	world = TableWorld.new(tavern)
	tavern.table_root.add_child(world)
	world.cards.sfx.connect(Sfx.play)
	post_fx = PostFx.new()
	add_child(post_fx)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	labels = WorldLabels.new(tavern.camera_rig.camera)
	_ui.add_child(labels)
	toasts = ToastLayer.new()
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 20
	add_child(toast_layer)
	var toast_root := Control.new()
	toast_root.theme = UiTheme.theme()
	toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(toast_root)
	toast_root.add_child(toasts)
	Net.joined_lobby.connect(_show_lobby)
	Net.returned_to_lobby.connect(_show_lobby)
	Net.left_lobby.connect(_back_to_menu)
	Net.game_started.connect(_show_table)
	await CardFaces.build(self)
	Card3D.refresh_materials()
	Sfx.start_ambience()
	_show_menu()
	flags = DebugFlags.new(self)
	add_child(flags)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game(0)


func quit_game(code: int) -> void:
	# 优雅退出:先断开联机(房主通知客人解散)、停掉音频,等音频线程回收后再退出
	Net.leave()
	Sfx.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)


func _exit_tree() -> void:
	# 静态缓存持有的资源在退出时释放,避免 ObjectDB 泄漏告警
	Card3D.clear_materials()
	CardFaces.clear()
	WorldMaterials.clear_cache()
	Fx.clear_cache()
	UiTheme.clear_cache()


func toast(text: String, color := UiTheme.PARCHMENT) -> void:
	toasts.show_toast(text, color)


func confirm(message: String, confirm_text := "确定", cancel_text := "取消") -> ConfirmOverlay:
	var overlay := ConfirmOverlay.new(message, confirm_text, cancel_text)
	_ui.add_child(overlay)
	return overlay


func current_screen() -> Control:
	return _screen


# —— 屏幕切换 ——

func _show_menu() -> void:
	world.clear()
	labels.clear()
	post_fx.set_tension(0.0, 0.8)
	tavern.camera_rig.parallax_enabled = false
	tavern.camera_rig.orbit(Vector3(0, 0.9, -0.2), 3.3, 1.15, 0.045, 2.2)
	_switch_to(MainMenuScreen.new(self))


func _show_lobby() -> void:
	post_fx.set_tension(0.0, 0.8)
	tavern.camera_rig.parallax_enabled = false
	_switch_to(LobbyScreen.new(self))


func _show_table(_seats: Array) -> void:
	_switch_to(TableScreen.new(self))


func _back_to_menu(reason: String) -> void:
	_show_menu()
	if reason != "":
		confirm(reason, "知道了", "")


func _switch_to(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(screen)
