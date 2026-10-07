extends SceneTree
# 给导出的游戏内容包(pck)写更新清单并签名:清单记 build/版本/引擎/平台/pck 的 SHA-256 与大小,
# 签名用发布者私钥(仓库之外)。输出 <out>/manifest.json 与 <out>/manifest.sig。
# 用法:godot --headless --path . -s tools/sign_update.gd -- --pck=路径 --platform=macos --out=目录
#       [--pck-file=更新源里的 pck 文件名] [--notes=说明] [--key=私钥]


func _initialize() -> void:
	var opts := {"key": OS.get_environment("HOME").path_join(".config/liarstavern/update_signing_key.pem"), "notes": "",
		"pck-file": UpdateManifest.DEFAULT_PCK_FILE}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			opts[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	for required in ["pck", "platform", "out"]:
		if not opts.has(required):
			return _fail("缺少参数 --%s" % required)
	var key := CryptoKey.new()
	if key.load(opts["key"]) != OK:
		return _fail("读不了签名私钥 %s" % opts["key"])
	if not FileAccess.file_exists(opts["pck"]):
		return _fail("找不到 pck:%s" % opts["pck"])
	var info := BuildInfo.info()
	var manifest := {
		"build": info["build"], "base_build": info["base_build"], "version": info["version"],
		"engine": BuildInfo.engine(), "platform": opts["platform"],
		"pck_sha256": FileAccess.get_sha256(opts["pck"]), "pck_size": FileAccess.get_size(opts["pck"]),
		"notes": opts["notes"], "pck_file": opts["pck-file"],
	}
	var text := JSON.stringify(manifest, "\t")
	if UpdateManifest.parse(text).is_empty():
		return _fail("生成的清单不合法:%s" % text)
	DirAccess.make_dir_recursive_absolute(opts["out"])
	_write(opts["out"].path_join("manifest.json"), text.to_utf8_buffer())
	_write(opts["out"].path_join("manifest.sig"), UpdateManifest.sign(text, key))
	print("已签名 %s v%s (build %d) -> %s" % [opts["platform"], info["version"], info["build"], opts["out"]])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _write(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(data)
