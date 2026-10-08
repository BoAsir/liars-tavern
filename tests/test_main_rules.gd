extends GutTest
# main 翻开说明书(规格 §6.6):默认翻到本房玩法那本,主菜单上是上次选的玩法那本;两本书分别记住读到的页。
# main 不进树(不搭酒馆):只给它一个放说明书的图层,屏幕用不进树的占位


const MainScript := preload("res://src/ui/main.gd")
const MainMenuScreen := preload("res://src/ui/main_menu/main_menu.gd")
const LIARS := RulebookContent.BOOK_LIARS
const POKER := RulebookContent.BOOK_POKER

var app: Node
var settings_path := ""
var saved_mode := GameMode.DEFAULT


func before_each():
	saved_mode = Net.game_mode
	settings_path = OS.get_temp_dir().path_join("liars_tavern_rules_gut_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(settings_path)
	app = autofree(MainScript.new())
	app.settings_path = settings_path
	app._rules_root = add_child_autofree(Control.new())
	app._screen = autofree(Control.new())   # 不是主菜单:等待厅或牌桌,算在房间里


func after_each():
	Net.game_mode = saved_mode
	DirAccess.remove_absolute(settings_path)


func test_in_a_room_opens_the_book_of_the_room_mode():
	for mode in GameMode.ALL:
		Net.game_mode = mode
		assert_eq(_book_opened(), RulebookContent.book_for_mode(mode), mode)


func test_on_the_main_menu_opens_the_book_of_the_last_chosen_mode():
	app._screen = autofree(MainMenuScreen.new(app))
	Net.game_mode = GameMode.LIARS   # 主菜单上不看它(离开房间后是默认值)
	for mode in [GameMode.SHORT_DECK, GameMode.HOLDEM, GameMode.LIARS]:
		Settings.set_value(Settings.KEY_LAST_MODE, mode, settings_path)
		assert_eq(_book_opened(), RulebookContent.book_for_mode(mode), mode)


func test_main_menu_falls_back_to_the_liars_book_without_a_valid_last_mode():
	app._screen = autofree(MainMenuScreen.new(app))
	Net.game_mode = GameMode.HOLDEM
	assert_eq(_book_opened(), LIARS, "还没有设置文件")
	for bad in ["chess", 42]:
		Settings.set_value(Settings.KEY_LAST_MODE, bad, settings_path)
		assert_eq(_book_opened(), LIARS, "读到非法值:%s" % bad)


func test_before_any_screen_counts_as_the_main_menu():
	# 启动时牌面还在生成、主菜单还没出来就按了 F1
	app._screen = null
	Net.game_mode = GameMode.HOLDEM
	assert_eq(_book_opened(), LIARS)


func test_each_book_reopens_at_the_page_it_was_left_on():
	Net.game_mode = GameMode.LIARS
	var book := _open()
	assert_eq(book.current_section(), 0, "第一次翻开从头读")
	book.show_section(3)
	book.show_book(POKER)
	assert_eq(book.current_section(), 0, "德州那本第一次翻开也从头读")
	book.show_section(2)
	book.close()
	book = _open()
	assert_eq(book.current_book(), LIARS)
	assert_eq(book.current_section(), 3)
	book.show_book(POKER)
	assert_eq(book.current_section(), 2)
	book.close()
	Net.game_mode = GameMode.SHORT_DECK
	book = _open()
	assert_eq(book.current_book(), POKER, "进了德州房间:默认翻德州那本,停在上次读到的页")
	assert_eq(book.current_section(), 2)


func test_opens_only_one_book_at_a_time():
	var book := _open()
	app.show_rules()
	assert_eq(app._rulebook, book)
	assert_eq(app._rules_root.get_child_count(), 1)


func _open() -> Rulebook:
	app.show_rules()
	assert_true(app.is_rules_open(), "说明书没有翻开")
	return app._rulebook


func _book_opened() -> String:
	# 翻开再合上,返回默认翻开的是哪本
	var book := _open()
	var id := book.current_book()
	book.close()
	return id
