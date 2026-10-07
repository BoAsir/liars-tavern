class_name UpdateStore
# 更新包在本机的存放:user://updates/ 下 b<build>.pck 与它的清单/签名,current.json 指向要叠加的那个
# (格式由安装包里的 UpdateBoot 读取,字段只能增不能改)。
# 房主转发的也是"自己正在运行的那份":叠加了更新包就转发更新包,否则转发安装包自带的 pck 与发布时附上的清单。


const INSTALLER_MANIFEST := "update_manifest.json"
const INSTALLER_SIGNATURE := "update_manifest.sig"


static func pck_name(build: int) -> String:
	return "b%d.pck" % build


static func install(dir: String, manifest: Dictionary, text: String, sig: PackedByteArray, downloaded: String,
		keep_build := 0) -> String:
	# 核对下载好的 pck 与清单一致后装好,下次启动生效。返回错误说明,成功返回空串。
	# keep_build:正在运行的更新包,Windows 上它的文件被占用,不去删它
	if FileAccess.get_size(downloaded) != manifest["pck_size"]:
		return "下载的文件大小不对"
	if FileAccess.get_sha256(downloaded) != manifest["pck_sha256"]:
		return "下载的文件校验不通过"
	DirAccess.make_dir_recursive_absolute(dir)
	var build: int = manifest["build"]
	var pck := dir.path_join(pck_name(build))
	DirAccess.remove_absolute(pck)
	if DirAccess.rename_absolute(downloaded, pck) != OK:
		return "无法保存更新包"
	if not _write(dir.path_join("b%d.json" % build), text.to_utf8_buffer()) \
			or not _write(dir.path_join("b%d.sig" % build), sig):
		return "无法保存更新清单"
	var record := {"build": build, "base_build": manifest["base_build"], "version": manifest["version"],
		"pck": pck_name(build), "sha256": manifest["pck_sha256"], "attempts": 0}
	if not _write(dir.path_join("current.json"), JSON.stringify(record, "\t").to_utf8_buffer()):
		return "无法写入更新记录"
	_remove_others(dir, [build, keep_build])
	return ""


static func _remove_others(dir: String, keep: Array) -> void:
	for file in DirAccess.get_files_at(dir):
		var stem := file.get_basename()
		if not stem.begins_with("b") or not stem.trim_prefix("b").is_valid_int():
			continue
		if not keep.has(int(stem.trim_prefix("b"))):
			DirAccess.remove_absolute(dir.path_join(file))


static func relay_from_update(dir: String, build: int) -> Dictionary:
	return _bundle(dir.path_join("b%d.json" % build), dir.path_join("b%d.sig" % build), [dir.path_join(pck_name(build))])


static func relay_from_installer(dirs: Array) -> Dictionary:
	# 发布脚本把清单与签名放在安装包的 pck 旁边;pck 按清单里的 SHA-256 认,不靠文件名
	for dir in dirs:
		var manifest_path: String = dir.path_join(INSTALLER_MANIFEST)
		if not FileAccess.file_exists(manifest_path):
			continue
		var pcks := []
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() == "pck":
				pcks.append(dir.path_join(file))
		return _bundle(manifest_path, dir.path_join(INSTALLER_SIGNATURE), pcks)
	return {}


static func installer_dirs() -> Array:
	# 安装包 pck 所在目录:macOS 在 .app/Contents/Resources,其他平台在可执行文件旁
	var exe_dir := OS.get_executable_path().get_base_dir()
	return [exe_dir.path_join("../Resources").simplify_path(), exe_dir]


static func _bundle(manifest_path: String, sig_path: String, pck_candidates: Array) -> Dictionary:
	# 返回 {"text", "sig", "manifest", "pck_path"};清单解析不了或找不到对得上的 pck 时返回空
	if not FileAccess.file_exists(manifest_path) or not FileAccess.file_exists(sig_path):
		return {}
	var text := FileAccess.get_file_as_string(manifest_path)
	var manifest := UpdateManifest.parse(text)
	if manifest.is_empty():
		return {}
	for pck in pck_candidates:
		if FileAccess.file_exists(pck) and FileAccess.get_size(pck) == manifest["pck_size"] \
				and FileAccess.get_sha256(pck) == manifest["pck_sha256"]:
			return {"text": text, "sig": FileAccess.get_file_as_bytes(sig_path), "manifest": manifest, "pck_path": pck}
	return {}


static func _write(path: String, data: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(data)
	return true
