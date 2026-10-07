extends Node
# 启动引导(自动加载,排在第一个):在其他自动加载与主场景载入之前,把已下载并核验过的更新包叠加进来,
# 之后载入的脚本、场景、新增的 class_name 都来自更新包。
# 这个脚本属于安装包本身、不会被更新包替换:除了公钥(UpdateKey,只有一个常量)不引用其他脚本类,
# 且 current.json 的格式要永远兼容。每次启动都重新验签名:current.json 本身没签名,它记的校验值必须和签过名的清单一致。
# 更新包连续 MAX_ATTEMPTS 次没能正常跑起来(Updater 跑稳后会调 mark_healthy),就丢弃它回到安装包自带的内容;
# 启动参数带 -- --no-update 也会丢弃(更新后的版本能启动但有毛病时的退路)。


const DIR := "user://updates"
const CURRENT := "current.json"
const MAX_ATTEMPTS := 2
const APPLY := "apply"
# 只在导出的游戏里生效;源码运行(编辑器、测试)与安装包共用 user:// 目录,不能叠加到源码上
const FORCE_ENV := "LIARS_UPDATE_BOOT"
const SKIP_ARG := "--no-update"

var installer := {}     # 安装包自带的 build.json:{"build", "version", "base_build"}
var active_build := 0   # 叠加了的更新包 build;0 = 运行的是安装包自带的内容
var note := ""          # 本次启动为什么没叠加(丢弃原因),便于排查


func _init() -> void:
	installer = read_build(FileAccess.get_file_as_string("res://build.json"))
	if OS.get_cmdline_user_args().has(SKIP_ARG):
		note = "skipped_by_user"
		discard(DIR)
	elif OS.has_feature("template") or OS.has_environment(FORCE_ENV):
		boot(DIR)


static func read_build(text: String) -> Dictionary:
	var data := _read_json_text(text)
	return {"build": int(data.get("build", 0)), "version": str(data.get("version", "dev")),
		"base_build": int(data.get("base_build", 0))}


static func decide(installer_info: Dictionary, current: Dictionary, file_ok: bool) -> String:
	# 返回 APPLY、空串(没有更新包)或丢弃原因
	if current.is_empty():
		return ""
	if not _is_pck_name(current.get("pck")):
		return "bad_record"
	if int(current.get("build", 0)) <= installer_info["build"]:
		return "installer_is_newer"
	if installer_info["build"] < int(current.get("base_build", 1 << 30)):
		return "needs_installer"
	if int(current.get("attempts", 0)) >= MAX_ATTEMPTS:
		return "failed_to_start"
	if not file_ok:
		return "corrupt"
	return APPLY


func boot(dir: String) -> void:
	var current := _read_json(dir.path_join(CURRENT))
	var pck := ""
	var file_ok := false
	if _is_pck_name(current.get("pck")):
		pck = dir.path_join(current["pck"])
		file_ok = FileAccess.file_exists(pck) and signed_record(dir, current, UpdateKey.PUBLIC_PEM) \
			and FileAccess.get_sha256(pck) == current.get("sha256")
	var verdict := decide(installer, current, file_ok)
	if verdict == "":
		return
	if verdict != APPLY:
		note = verdict
		discard(dir)
		return
	# 先记一次尝试再加载:叠加后的内容若在启动途中崩溃,下次启动就能看出来
	current["attempts"] = int(current.get("attempts", 0)) + 1
	if not _write_json(dir.path_join(CURRENT), current):
		note = "record_unwritable"   # 记不下尝试次数就没法在崩溃后回退:宁可不叠加
		return
	if ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pck), true):
		active_build = int(current["build"])
	else:
		note = "load_failed"
		discard(dir)


func mark_healthy(dir := DIR) -> void:
	# 更新后的内容已正常跑起来:清零尝试次数
	var path := dir.path_join(CURRENT)
	var current := _read_json(path)
	if current.is_empty() or int(current.get("build", 0)) != active_build:
		return
	current["attempts"] = 0
	_write_json(path, current)


static func signed_record(dir: String, current: Dictionary, public_pem: String) -> bool:
	# 记录里的校验值、build、base_build 必须和同目录下签过名的清单一致
	var build := int(current.get("build", 0))
	var text := FileAccess.get_file_as_string(dir.path_join("b%d.json" % build))
	var sig := FileAccess.get_file_as_bytes(dir.path_join("b%d.sig" % build))
	if text == "" or sig.is_empty() or not public_pem.begins_with("-----BEGIN PUBLIC KEY-----"):
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_pem, true) != OK:
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	if not Crypto.new().verify(HashingContext.HASH_SHA256, ctx.finish(), sig, key):
		return false
	var signed := _read_json_text(text)
	return int(signed.get("build", -1)) == build and signed.get("pck_sha256") == current.get("sha256") \
		and int(signed.get("base_build", -1)) == int(current.get("base_build", -2))


static func discard(dir: String) -> void:
	# 删掉记录与所有更新包文件(Windows 上此时还没加载,不会被占用)
	DirAccess.remove_absolute(dir.path_join(CURRENT))
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("b") and file.get_extension() in ["pck", "json", "sig"]:
			DirAccess.remove_absolute(dir.path_join(file))


static func _is_pck_name(value) -> bool:
	# 记录里的文件名只能是 b<数字>.pck,防止被改成指向别处的路径
	if not value is String or not value.begins_with("b") or not value.ends_with(".pck"):
		return false
	return value.trim_prefix("b").trim_suffix(".pck").is_valid_int()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return _read_json_text(FileAccess.get_file_as_string(path))


static func _read_json_text(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data


static func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入更新记录 %s:%s" % [path, error_string(FileAccess.get_open_error())])
		return false
	return file.store_string(JSON.stringify(data, "\t"))
