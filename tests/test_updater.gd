extends GutTest
# Updater 的检查流程:后台检查进行中又来的检查要排队接着查,不能被悄悄丢掉。
# 用一个独立的 Updater 实例(不是自动加载)和本机回环上的空文件服务(所有路径 404)。


const UpdaterScript := preload("res://src/update/updater.gd")
const PORT_BASE := 48000

var updater: Node
var server: UpdateServer
var port: int


func before_each():
	updater = UpdaterScript.new()
	add_child_autofree(updater)
	server = UpdateServer.new()
	add_child_autofree(server)
	port = PORT_BASE + randi() % 90
	assert_eq(server.start(port, {}), OK)


func after_each():
	server.stop()


func _source() -> String:
	return "http://127.0.0.1:%d/macos/" % port


func test_check_requested_during_background_check_still_runs():
	updater.check(_source(), "网络", true)
	assert_eq(updater.state, UpdaterScript.State.CHECKING)
	updater.check(_source(), "房主 老王")
	await wait_until(func(): return updater.state == UpdaterScript.State.FAILED, 10.0)
	assert_eq(updater.state, UpdaterScript.State.FAILED, "后台检查静默结束后,玩家点的那次接着查并报告结果")
	assert_string_contains(updater.message, "房主 老王")


func test_quiet_check_alone_stays_silent():
	updater.check(_source(), "网络", true)
	await wait_until(func(): return updater.state != UpdaterScript.State.CHECKING, 10.0)
	assert_eq(updater.state, UpdaterScript.State.IDLE)


func test_restart_drops_the_no_update_flag():
	# 带 -- --no-update 启动的游戏装好更新后点「重启」:不能把这个参数带过去,否则刚装好的更新被当场丢掉
	var args := UpdaterScript.restart_args(PackedStringArray(["--path", "x"]), PackedStringArray(["--no-update", "--name=甲"]))
	assert_eq(args, PackedStringArray(["--path", "x", "--", "--name=甲"]))
	var only_flag := UpdaterScript.restart_args(PackedStringArray(), PackedStringArray(["--no-update"]))
	assert_eq(only_flag, PackedStringArray(), "只有这个参数时连 -- 也不要")


func test_restart_keeps_other_arguments():
	var args := UpdaterScript.restart_args(PackedStringArray(["--fullscreen"]), PackedStringArray(["--name=乙"]))
	assert_eq(args, PackedStringArray(["--fullscreen", "--", "--name=乙"]))
	assert_eq(UpdaterScript.NO_UPDATE_ARG, preload("res://src/update/update_boot.gd").SKIP_ARG, "两边的参数名要一致")
