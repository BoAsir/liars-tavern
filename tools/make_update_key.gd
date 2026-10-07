extends SceneTree
# 生成更新签名密钥:私钥写到仓库之外(默认 ~/.config/liarstavern/update_signing_key.pem,权限 600),
# 公钥写进 src/update/update_key.gd 随游戏发布。已有私钥时拒绝覆盖——换钥匙意味着已装的游戏再也认不出新更新。
# 用法:godot --headless --path . -s tools/make_update_key.gd [-- --key=路径]


const KEY_SCRIPT := "res://src/update/update_key.gd"


func _initialize() -> void:
	var key_path := default_key_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--key="):
			key_path = arg.trim_prefix("--key=")
	if FileAccess.file_exists(key_path):
		push_error("私钥已存在:%s。不覆盖(换钥匙后已安装的游戏会拒收新更新)" % key_path)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(key_path.get_base_dir())
	# 先建空文件并收紧权限,再写入内容:私钥任何时候都不会以默认权限落盘
	var placeholder := FileAccess.open(key_path, FileAccess.WRITE)
	if placeholder == null:
		push_error("无法创建私钥文件:%s" % key_path)
		quit(1)
		return
	placeholder.close()
	if OS.execute("chmod", ["600", key_path]) != 0:
		push_error("无法收紧私钥文件权限:%s" % key_path)
		DirAccess.remove_absolute(key_path)
		quit(1)
		return
	var key := Crypto.new().generate_rsa(2048)
	var file := FileAccess.open(key_path, FileAccess.WRITE)
	if file == null or not file.store_string(key.save_to_string(false)):
		push_error("写入私钥失败")
		quit(1)
		return
	file.close()
	var script := FileAccess.open(KEY_SCRIPT, FileAccess.WRITE)
	script.store_string("class_name UpdateKey\n# 更新签名公钥(tools/make_update_key.gd 生成)。私钥只在发布者电脑上,不进仓库。\n\n\n"
		+ "const PUBLIC_PEM := \"\"\"%s\"\"\"\n" % key.save_to_string(true).strip_edges())
	script.close()
	print("私钥 -> ", key_path, "(请备份;丢了就只能发完整安装包)")
	print("公钥 -> ", KEY_SCRIPT)
	quit(0)


static func default_key_path() -> String:
	return OS.get_environment("HOME").path_join(".config/liarstavern/update_signing_key.pem")
