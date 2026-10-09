extends GutTest
# Settings:玩家本地设置的读写(用临时文件,不碰真正的 user://settings.cfg)。


# 每个进程一个文件、放在系统临时目录:并行跑两份测试不会互相覆盖,也不会落在玩家的存档目录里
var PATH := OS.get_temp_dir().path_join("liars_tavern_settings_gut_%d.cfg" % OS.get_process_id())


func before_each():
	_remove()


func after_each():
	_remove()


func _remove():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_missing_file_returns_fallbacks():
	assert_eq(Settings.get_string(Settings.KEY_NAME, "无名", PATH), "无名")
	assert_false(Settings.get_bool(Settings.KEY_MUTED, false, PATH))
	assert_true(Settings.get_bool(Settings.KEY_MUTED, true, PATH))


func test_values_round_trip_without_clobbering_other_keys():
	assert_eq(Settings.set_value(Settings.KEY_NAME, "老王", PATH), OK)
	assert_eq(Settings.set_value(Settings.KEY_MUTED, true, PATH), OK)
	assert_eq(Settings.set_value(Settings.KEY_LAST_IP, "192.168.1.8", PATH), OK)
	assert_eq(Settings.get_string(Settings.KEY_NAME, "", PATH), "老王")
	assert_true(Settings.get_bool(Settings.KEY_MUTED, false, PATH))
	assert_eq(Settings.get_string(Settings.KEY_LAST_IP, "", PATH), "192.168.1.8")


func test_values_live_in_the_player_section():
	Settings.set_value(Settings.KEY_MUTED, true, PATH)
	var config := ConfigFile.new()
	assert_eq(config.load(PATH), OK)
	assert_eq(config.get_value("player", "muted"), true)


func test_values_of_the_wrong_type_fall_back():
	var config := ConfigFile.new()
	config.set_value("player", "name", 42)
	config.set_value("player", "muted", "yes")
	config.save(PATH)
	assert_eq(Settings.get_string(Settings.KEY_NAME, "无名", PATH), "无名")
	assert_false(Settings.get_bool(Settings.KEY_MUTED, false, PATH))


func test_unreadable_file_is_replaced_on_next_save():
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[player\nthis is not a config file = = =")
	file.close()
	assert_eq(Settings.get_string(Settings.KEY_NAME, "无名", PATH), "无名")
	assert_eq(Settings.set_value(Settings.KEY_NAME, "阿花", PATH), OK)
	assert_eq(Settings.get_string(Settings.KEY_NAME, "", PATH), "阿花")
	# ConfigFile 自己会打印解析错误:读取一次、保存前回读一次;覆盖后再读就正常了
	assert_engine_error_count(2, "坏文件只在被替换前解析失败两次")


func test_last_mode_defaults_until_a_room_is_opened_and_then_round_trips():
	assert_eq(Settings.last_mode(PATH), GameMode.DEFAULT)
	assert_eq(Settings.set_value(Settings.KEY_LAST_MODE, GameMode.SHORT_DECK, PATH), OK)
	assert_eq(Settings.last_mode(PATH), GameMode.SHORT_DECK)


func test_unknown_or_mistyped_last_mode_falls_back_to_the_default():
	# 手改的设置文件、更新版本留下的新玩法:主菜单照常打开,用默认玩法
	for junk in ["mahjong", "", 7, true]:
		Settings.set_value(Settings.KEY_LAST_MODE, junk, PATH)
		assert_eq(Settings.last_mode(PATH), GameMode.DEFAULT, str(junk))
