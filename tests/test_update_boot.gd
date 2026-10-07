extends GutTest
# 启动引导的取舍:只叠加比安装包新、安装包够新、没连续启动失败、文件完好的更新包;否则丢弃记录。


const BootScript := preload("res://src/update/update_boot.gd")
const INSTALLER := {"build": 3, "version": "0.3.0", "base_build": 1}

var dir: String


func before_each():
	dir = "user://test_boot_%d" % randi()
	DirAccess.make_dir_recursive_absolute(dir)


func after_each():
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _record(overrides := {}) -> Dictionary:
	var r := {"build": 5, "base_build": 2, "version": "0.5.0", "pck": "b5.pck", "sha256": "ab".repeat(32), "attempts": 0}
	r.merge(overrides, true)
	return r


func test_decide():
	assert_eq(BootScript.decide(INSTALLER, {}, false), "", "没有更新包")
	assert_eq(BootScript.decide(INSTALLER, _record(), true), BootScript.APPLY)
	assert_eq(BootScript.decide(INSTALLER, _record({"build": 3}), true), "installer_is_newer", "重装了同版或更新的安装包")
	assert_eq(BootScript.decide(INSTALLER, _record({"base_build": 4}), true), "needs_installer")
	assert_eq(BootScript.decide(INSTALLER, _record({"attempts": BootScript.MAX_ATTEMPTS}), true), "failed_to_start")
	assert_eq(BootScript.decide(INSTALLER, _record(), false), "corrupt")
	assert_eq(BootScript.decide(INSTALLER, _record({"pck": "../../evil.pck"}), true), "bad_record", "文件名不能指向别处")


func test_boot_discards_a_corrupt_package():
	var record := FileAccess.open(dir.path_join("current.json"), FileAccess.WRITE)
	record.store_string(JSON.stringify(_record()))
	record.close()
	var pck := FileAccess.open(dir.path_join("b5.pck"), FileAccess.WRITE)
	pck.store_string("内容和记录里的校验值对不上")
	pck.close()
	var boot: Node = BootScript.new()
	boot.installer = INSTALLER
	boot.boot(dir)
	assert_eq(boot.active_build, 0)
	assert_eq(boot.note, "corrupt")
	assert_false(FileAccess.file_exists(dir.path_join("current.json")), "坏记录删掉,下次直接用安装包")
	boot.free()


func test_mark_healthy_resets_attempts_for_the_running_build():
	var record := FileAccess.open(dir.path_join("current.json"), FileAccess.WRITE)
	record.store_string(JSON.stringify(_record({"attempts": 1})))
	record.close()
	var boot: Node = BootScript.new()
	boot.active_build = 5
	boot.mark_healthy(dir)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("current.json")))
	assert_eq(int(saved["attempts"]), 0)
	boot.free()


func test_source_runs_do_not_overlay_updates():
	# 测试进程本身就是源码运行:不能把 user:// 里的更新包叠加到源码上
	assert_eq(UpdateBoot.active_build, 0)


func _signed_files(key: CryptoKey, record: Dictionary, manifest_overrides := {}) -> void:
	var manifest := {"build": record["build"], "base_build": record["base_build"], "pck_sha256": record["sha256"]}
	manifest.merge(manifest_overrides, true)
	var text := JSON.stringify(manifest)
	var f := FileAccess.open(dir.path_join("b%d.json" % record["build"]), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var s := FileAccess.open(dir.path_join("b%d.sig" % record["build"]), FileAccess.WRITE)
	s.store_buffer(UpdateManifest.sign(text, key))
	s.close()


func test_record_must_match_a_signed_manifest():
	var key := Crypto.new().generate_rsa(2048)
	var pem := key.save_to_string(true)
	var record := _record()
	_signed_files(key, record)
	assert_true(BootScript.signed_record(dir, record, pem))
	assert_false(BootScript.signed_record(dir, record.merged({"sha256": "cd".repeat(32)}, true), pem),
		"有人改了 current.json 里的校验值,想让别的 pck 混进来")
	assert_false(BootScript.signed_record(dir, record.merged({"base_build": 1}, true), pem), "改了 base_build")
	var other := Crypto.new().generate_rsa(2048)
	assert_false(BootScript.signed_record(dir, record, other.save_to_string(true)), "不是官方公钥签的")
	assert_false(BootScript.signed_record(dir, _record({"build": 6}), pem), "没有对应清单")


func test_discard_removes_record_and_packages():
	for file in ["current.json", "b5.pck", "b5.json", "b5.sig", "b4.pck"]:
		var f := FileAccess.open(dir.path_join(file), FileAccess.WRITE)
		f.store_string("x")
		f.close()
	BootScript.discard(dir)
	assert_eq(DirAccess.get_files_at(dir).size(), 0)
