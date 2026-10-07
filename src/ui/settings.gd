class_name Settings
# 本机玩家设置(user://settings.cfg 的 [player] 段):名号、上次直连地址、静音、上次选的玩法。
# 启动流程与主菜单共用这组键。设置文件是外部数据:读不出或类型不对时回退默认值并告警。


const PATH := "user://settings.cfg"
const SECTION := "player"
const KEY_NAME := "name"
const KEY_LAST_IP := "last_ip"
const KEY_MUTED := "muted"
const KEY_LAST_MODE := "last_mode"


static func get_string(key: String, fallback := "", path := PATH) -> String:
	var value: Variant = _read(key, fallback, path)
	if value is String:
		return value
	_warn_type(key, value, path)
	return fallback


static func get_bool(key: String, fallback := false, path := PATH) -> bool:
	var value: Variant = _read(key, fallback, path)
	if value is bool:
		return value
	_warn_type(key, value, path)
	return fallback


static func set_value(key: String, value: Variant, path := PATH) -> Error:
	# 先读回已有内容再写,保留其他键;文件坏了就以新文件覆盖(坏文件里的值本来也读不出来)
	var config := ConfigFile.new()
	var err := config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("设置文件 %s 无法读取(%s),将重新创建" % [path, error_string(err)])
		config = ConfigFile.new()
	config.set_value(SECTION, key, value)
	err = config.save(path)
	if err != OK:
		push_warning("保存设置 %s 失败:%s" % [key, error_string(err)])
	return err


static func _read(key: String, fallback: Variant, path: String) -> Variant:
	var config := ConfigFile.new()
	var err := config.load(path)
	if err == ERR_FILE_NOT_FOUND:
		return fallback  # 首次启动还没有设置文件
	if err != OK:
		push_warning("读取设置文件 %s 失败:%s" % [path, error_string(err)])
		return fallback
	return config.get_value(SECTION, key, fallback)


static func _warn_type(key: String, value: Variant, path: String) -> void:
	push_warning("设置 %s 的值类型不对(%s,来自 %s),改用默认值" % [key, type_string(typeof(value)), path])
