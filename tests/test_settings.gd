extends GutTest
# Settings:玩家本地设置的读写(用临时文件,不碰真正的 user://settings.cfg)。


const PATH := "user://test_settings_gut.cfg"


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
