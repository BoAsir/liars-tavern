extends GutTest
# 等待厅界面(规格 §3.2):按玩法摆桌(获准时就知道玩法,名单 meta 晚到且不同时再摆一次);
# 德州 8 人也要在 1280×720 里放下:玩家列表最多露出 4 行、其余在列表里滚动;
# 3D 铭牌单行「名字 ✓」不超过 130×44(8 人围坐时两行的铭牌会互相压住)。


const LobbyScreen := preload("res://src/ui/lobby/lobby.gd")
const LONG_NAME := "小明明明明明明明明明明明"   # 昵称上限 12 字


class StubRig:
	extends RefCounted
	var moves := 0

	func move_to(_xform: Transform3D, _time: float) -> void:
		moves += 1


class StubWorld:
	extends RefCounted
	var patrons := {}

	func lobby_view() -> Transform3D:
		return Transform3D.IDENTITY


class StubTavern:
	extends RefCounted
	var camera_rig := StubRig.new()


class StubApp:
	extends Node
	# 只记下按哪个玩法摆过桌子、镜头挪过几次
	var applied: Array = []
	var world := StubWorld.new()
	var tavern := StubTavern.new()

	func apply_table_mode(mode: String) -> void:
		applied.append(mode)


func before_each():
	# 名单行要用 Net.my_pid():前面的测试 leave() 过的话树上没有 peer,先换回默认的离线 peer
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func after_each():
	# 自动加载是全局的:别把玩法、房主身份留给后面的测试
	Net.game_mode = GameMode.DEFAULT
	Net.is_host = false


func test_table_follows_the_mode_and_a_late_change_only_once():
	var app: StubApp = autofree(StubApp.new())
	var lobby: Control = autofree(LobbyScreen.new(app))
	Net.game_mode = GameMode.HOLDEM
	lobby._apply_table_mode()
	assert_eq(app.applied, [GameMode.HOLDEM], "进等待厅就按玩法摆桌")
	lobby._sync_table_mode()
	assert_eq(app.applied, [GameMode.HOLDEM], "玩法没变:刷新名单不重摆")
	Net.game_mode = GameMode.SHORT_DECK
	lobby._sync_table_mode()
	lobby._sync_table_mode()
	assert_eq(app.applied, [GameMode.HOLDEM, GameMode.SHORT_DECK], "名单 meta 带来不同的玩法:只重摆一次")
	assert_eq(app.tavern.camera_rig.moves, 2, "每次摆桌都换到等待厅机位")


func test_list_shows_every_row_up_to_the_limit():
	assert_eq(LobbyScreen.visible_list_height([44.0, 58.0, 58.0], 8.0, 4), 44.0 + 58.0 + 58.0 + 2 * 8.0)
	assert_eq(LobbyScreen.visible_list_height([], 8.0, 4), 0.0)


func test_list_beyond_the_limit_scrolls_instead_of_growing():
	var rows := [44.0, 58.0, 58.0, 58.0, 58.0, 58.0, 58.0, 58.0]
	assert_eq(LobbyScreen.visible_list_height(rows, 8.0, 4), 44.0 + 3 * 58.0 + 3 * 8.0)
	assert_eq(LobbyScreen.LIST_VISIBLE_ROWS, 4, "骗子酒馆满员 4 人时列表不滚动")


func _plate_texts(plate: Control) -> Array:
	return plate.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func test_nameplate_is_one_short_line():
	for pname in ["阿花", LONG_NAME]:
		for ready in [true, false]:
			var plate: Control = LobbyScreen.nameplate(pname, ready)
			add_child_autofree(plate)
			var size := plate.get_combined_minimum_size()
			assert_lte(size.x, LobbyScreen.PLATE_MAX.x, "%s ready=%s" % [pname, ready])
			assert_lte(size.y, LobbyScreen.PLATE_MAX.y, "%s ready=%s" % [pname, ready])
			assert_eq(plate.find_children("*", "Label", true, false).size(), 2 if ready else 1, "单行:名字(+ ✓)")


func test_nameplate_marks_ready_players():
	var ready: Control = autofree(LobbyScreen.nameplate("阿花", true))
	assert_eq(_plate_texts(ready), ["阿花", "✓"])
	var waiting: Control = autofree(LobbyScreen.nameplate("阿花", false))
	assert_eq(_plate_texts(waiting), ["阿花"])


func test_short_names_get_their_full_width():
	# 名字一栏按文字宽度给足(只有超长昵称才省略号截断):不能缩成只剩「…」
	var plate: Control = LobbyScreen.nameplate("阿花", true)
	add_child_autofree(plate)
	var name_label: Label = plate.find_children("*", "Label", true, false)[0]
	var text_width := name_label.get_theme_font("font").get_string_size("阿花", HORIZONTAL_ALIGNMENT_LEFT, -1,
		name_label.get_theme_font_size("font_size")).x
	assert_gt(text_width, 0.0)
	assert_gte(name_label.get_combined_minimum_size().x, text_width - 0.5)


func test_row_buttons_keep_rows_as_short_as_the_name():
	# 名单行里的「请出」用主题样式但收小内边距:有按钮的行和没按钮的行一样高,4 行露出的高度省下来
	var button: Button = autofree(LobbyScreen.row_button("请出"))
	for state in LobbyScreen.ROW_BUTTON_STATES:
		var box: StyleBox = button.get_theme_stylebox(state)
		assert_true(button.has_theme_stylebox_override(state), state)
		assert_eq([box.content_margin_left, box.content_margin_top], [LobbyScreen.ROW_BUTTON_PADDING.x,
			LobbyScreen.ROW_BUTTON_PADDING.y], state)
	assert_eq(button.focus_mode, Control.FOCUS_ALL, "仍能用键盘请出")


func _themed(control: Control) -> Control:
	# 挂在用游戏主题的节点下量尺寸:字体与按钮样式和真实界面一致
	var holder := Control.new()
	holder.theme = UiTheme.theme()
	add_child_autofree(holder)
	holder.add_child(control)
	return control


func test_player_rows_stay_compact_with_long_names_and_kick_buttons():
	# 每行不超过 36 像素(规格 §3.2):房名折成两行、广播告警同时出现时面板也放得下
	var lobby: Control = autofree(LobbyScreen.new(autofree(StubApp.new())))
	Net.is_host = true
	for player in [{"pid": 1, "name": "房主", "ready": true, "is_host": true},
			{"pid": 5, "name": LONG_NAME, "ready": false, "is_host": false}]:
		var row: Control = _themed(lobby._player_row(player, 0))
		assert_lte(row.get_combined_minimum_size().y, LobbyScreen.ROW_MAX_HEIGHT, player["name"])
		assert_lte(row.get_combined_minimum_size().x, LobbyScreen.PANEL_WIDTH, "长昵称不撑宽面板")


# —— 自选形象(子项目② §3.2)——

class SpeciesApp:
	extends StubApp
	# 记下提示条;本机设置写到临时文件
	var toasts: Array = []
	var settings_path := ""
	var species := Species.UNASSIGNED

	func toast(text: String, _color := Color.WHITE) -> void:
		toasts.append(text)

	func is_rules_open() -> bool:
		return false


func _species_app() -> SpeciesApp:
	var app: SpeciesApp = autofree(SpeciesApp.new())
	app.settings_path = OS.get_temp_dir().path_join("liars_tavern_lobby_species_gut_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(app.settings_path)
	return app


func _roster(my_species: Variant, other_species: Variant) -> Array:
	# 离线 peer 的 my_pid 就是 1:别人用另一个 pid
	return [{"pid": Net.my_pid() + 1, "name": "阿杰", "ready": true, "is_host": true, "species": other_species},
		{"pid": Net.my_pid(), "name": "我", "ready": false, "is_host": false, "species": my_species}]


func test_rows_show_species_chips_and_only_mine_is_a_button():
	var lobby: Control = autofree(LobbyScreen.new(_species_app()))
	var roster := _roster(5, 7)
	var other: Control = _themed(lobby._player_row(roster[0], 0))
	var mine: Control = _themed(lobby._player_row(roster[1], 1))
	var other_chip: SpeciesChip = other.find_children("*", "SpeciesChip", true, false)[0]
	var my_chip: SpeciesChip = mine.find_children("*", "SpeciesChip", true, false)[0]
	assert_eq(other_chip.species, 7)
	assert_eq(other_chip.focus_mode, Control.FOCUS_NONE, "别人的头像只是展示")
	assert_eq(my_chip.species, 5)
	assert_eq(my_chip.focus_mode, Control.FOCUS_ALL, "自己的头像点开挑选面板")
	assert_eq(my_chip.tooltip_text, "换形象:羊驼 · 披毯客")


func test_unassigned_or_junk_species_shows_picking():
	var lobby: Control = autofree(LobbyScreen.new(_species_app()))
	for junk in [-1, 99, "fox", null]:
		var row: Control = _themed(lobby._player_row({"pid": 9, "name": "新来的", "ready": false, "is_host": false,
			"species": junk}, 0))
		var chip: SpeciesChip = row.find_children("*", "SpeciesChip", true, false)[0]
		assert_eq(chip.tooltip_text, "挑选中…", str(junk))


func test_granted_request_is_saved_as_the_local_preference():
	var app := _species_app()
	var lobby: Control = autofree(LobbyScreen.new(app))
	lobby._pending = 3
	lobby._pending_deadline = Time.get_ticks_msec() + 1000
	lobby._settle_species_request(_roster(3, 7))
	assert_eq(lobby._pending, Species.UNASSIGNED)
	assert_eq(Settings.get_species(app.settings_path), 3, "房主确认之后才写本机设置")
	assert_eq(app.species, 3)
	assert_eq(app.toasts, [])
	DirAccess.remove_absolute(app.settings_path)


func test_request_lost_to_someone_else_says_who_took_it():
	var app := _species_app()
	var lobby: Control = autofree(LobbyScreen.new(app))
	lobby._pending = 1
	lobby._pending_deadline = Time.get_ticks_msec() + 1000
	lobby._settle_species_request(_roster(0, 1))
	assert_eq(app.toasts, ["「熊」刚被 阿杰 选走了"])
	assert_eq(Settings.get_species(app.settings_path), Species.UNASSIGNED, "本机偏好不被改写")
	assert_eq(lobby._pending, Species.UNASSIGNED)


func test_unrelated_roster_keeps_the_request_until_it_times_out():
	var app := _species_app()
	var lobby: Control = autofree(LobbyScreen.new(app))
	lobby._pending = 4
	lobby._pending_deadline = Time.get_ticks_msec() + 1000
	lobby._settle_species_request(_roster(0, 7))
	assert_eq(lobby._pending, 4, "别人准备了之类的名单:继续等")
	lobby._pending_deadline = Time.get_ticks_msec() - 1
	lobby._settle_species_request(_roster(0, 7))
	assert_eq(lobby._pending, Species.UNASSIGNED, "超时静默放弃")
	assert_eq(app.toasts, [])
