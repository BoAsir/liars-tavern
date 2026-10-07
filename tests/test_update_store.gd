extends GutTest
# 更新包的本机存放:核对后装好、写出启动引导能读的记录、清理旧包;房主转发时找出对得上清单的那份 pck。


const BootScript := preload("res://src/update/update_boot.gd")

var dir: String
var pck_bytes := PackedByteArray()


func before_each():
	dir = "user://test_updates_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)
	pck_bytes = ("假装是游戏内容包" + str(randi())).to_utf8_buffer()


func after_each():
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _download() -> String:
	var path := dir.path_join("download.part")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(pck_bytes)
	file.close()
	return path


func _manifest(build := 7) -> Dictionary:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pck_bytes)
	return {"build": build, "base_build": 2, "version": "0.7.0", "engine": BuildInfo.engine(),
		"platform": BuildInfo.platform(), "pck_sha256": ctx.finish().hex_encode(), "pck_size": pck_bytes.size(), "notes": ""}


func test_install_writes_a_record_the_boot_loader_accepts():
	var m := _manifest()
	var err := UpdateStore.install(dir, m, JSON.stringify(m), PackedByteArray([9, 9]), _download())
	assert_eq(err, "")
	assert_true(FileAccess.file_exists(dir.path_join("b7.pck")))
	assert_false(FileAccess.file_exists(dir.path_join("download.part")), "下载的临时文件被移走")
	var record = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("current.json")))
	var installer := {"build": 3, "version": "0.3.0", "base_build": 1}
	assert_eq(BootScript.decide(installer, record, true), BootScript.APPLY)


func test_install_rejects_a_tampered_download():
	var m := _manifest()
	m["pck_sha256"] = "00".repeat(32)
	assert_ne(UpdateStore.install(dir, m, JSON.stringify(m), PackedByteArray(), _download()), "")
	assert_false(FileAccess.file_exists(dir.path_join("current.json")))


func test_install_removes_older_packages_but_keeps_the_running_one():
	for build in [4, 5, 6]:
		var old := FileAccess.open(dir.path_join("b%d.pck" % build), FileAccess.WRITE)
		old.store_string("旧")
		old.close()
	var m := _manifest()
	UpdateStore.install(dir, m, JSON.stringify(m), PackedByteArray(), _download(), 5)
	assert_false(FileAccess.file_exists(dir.path_join("b4.pck")))
	assert_true(FileAccess.file_exists(dir.path_join("b5.pck")), "正在运行的那份(Windows 上被占用)不删")
	assert_false(FileAccess.file_exists(dir.path_join("b6.pck")))


func test_relay_returns_the_installed_update():
	var m := _manifest()
	var text := JSON.stringify(m)
	UpdateStore.install(dir, m, text, PackedByteArray([1, 2, 3]), _download())
	var bundle := UpdateStore.relay_from_update(dir, 7)
	assert_eq(bundle["text"], text)
	assert_eq(bundle["sig"], PackedByteArray([1, 2, 3]))
	assert_eq(bundle["pck_path"], dir.path_join("b7.pck"))


func test_relay_from_installer_finds_the_pck_matching_the_manifest():
	var m := _manifest()
	var wrong := FileAccess.open(dir.path_join("aaa.pck"), FileAccess.WRITE)
	wrong.store_string("别的包")
	wrong.close()
	var right := FileAccess.open(dir.path_join("骗子酒馆.pck"), FileAccess.WRITE)
	right.store_buffer(pck_bytes)
	right.close()
	var manifest_file := FileAccess.open(dir.path_join(UpdateStore.INSTALLER_MANIFEST), FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify(m))
	manifest_file.close()
	var sig_file := FileAccess.open(dir.path_join(UpdateStore.INSTALLER_SIGNATURE), FileAccess.WRITE)
	sig_file.store_buffer(PackedByteArray([5]))
	sig_file.close()
	var bundle := UpdateStore.relay_from_installer(["user://no_such_dir_here", dir])
	assert_eq(bundle["pck_path"], dir.path_join("骗子酒馆.pck"))
	assert_eq(bundle["manifest"]["build"], 7)


func test_relay_is_empty_without_files():
	assert_true(UpdateStore.relay_from_update(dir, 3).is_empty())
	assert_true(UpdateStore.relay_from_installer([dir]).is_empty())
