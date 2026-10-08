class_name Settings
# 本机玩家设置(user://settings.cfg 的 [player] 段):名号、上次直连地址、静音、上次开房选的玩法、形象。
# 启动流程与主菜单共用这组键。设置文件是外部数据:读不出或类型不对时回退默认值并告警。


const PATH := "user://settings.cfg"
const SECTION := "player"
const KEY_NAME := "name"
const KEY_LAST_IP := "last_ip"
const KEY_MUTED := "muted"
const KEY_LAST_MODE := "last_mode"
const KEY_SPECIES := "species"   # 存物种 id 字符串(不存下标):以后调整内部顺序也不会选错


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


static func last_mode(path := PATH) -> String:
	# 上次开房选的玩法(主菜单的玩法切换据此预选)。不认识的值(手改的文件、更新版本留下的新玩法)
	# 回退默认玩法:类型不对已由 get_string 告警,这里只补「是字符串但不是已知玩法」的告警
	var mode := get_string(KEY_LAST_MODE, GameMode.DEFAULT, path)
	if GameMode.is_valid(mode):
		return mode
	push_warning("设置 %s 的值「%s」不是已知玩法(来自 %s),改用默认玩法" % [KEY_LAST_MODE, mode, path])
	return GameMode.DEFAULT


static func get_species(path := PATH) -> int:
	# 本机想要的形象(物种下标);没设置过返回 UNASSIGNED,id 不认识或类型不对时告警并返回 UNASSIGNED
	var value: Variant = _read(KEY_SPECIES, null, path)
	if value == null:
		return Species.UNASSIGNED
	var index := Species.index_of(value) if value is String else Species.UNASSIGNED
	if index == Species.UNASSIGNED:
		push_warning("设置 %s 的值「%s」不是已知形象(来自 %s),重新挑一个" % [KEY_SPECIES, str(value), path])
	return index


static func ensure_species(path := PATH, rng: RandomNumberGenerator = null) -> int:
	# 首次启动(或存的值坏了):随机挑一个并立刻保存,让新物种也常出现;之后启动沿用
	var index := get_species(path)
	if index != Species.UNASSIGNED:
		return index
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	index = rng.randi_range(0, Species.count() - 1)
	set_value(KEY_SPECIES, Species.IDS[index], path)
	return index


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
