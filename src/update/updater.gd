extends Node
# 在线更新的调度(自动加载 Updater):检查更新源 → 验签名 → 下载 → 装好 → 重启生效;
# 开房时把自己正在运行的那份签名更新包放到局域网文件服务上,版本旧的玩家可以直接从房主这里更新。
# 这个脚本随更新包替换(启动引导 UpdateBoot 不替换),界面通过 changed 信号跟随状态。


signal changed

enum State { IDLE, CHECKING, AVAILABLE, BLOCKED, DOWNLOADING, READY, FAILED }

const HEALTHY_FRAMES := 3      # 主场景先跑过这么多帧(主菜单已经画出来)
const HEALTHY_SECONDS := 2.0   # 再稳稳跑这么久(真实时间,不受加速影响),才算更新后的内容启动成功
const DOWNLOAD_PART := "download.part"

var state := State.IDLE
var manifest := {}       # 发现的新版本清单(AVAILABLE 之后有效)
var source := ""         # 更新来自哪里,显示用:"房主 老王" / "网络"
var message := ""        # BLOCKED / FAILED 时给玩家看的说明
var progress := 0.0

var _base_url := ""
var _text := ""
var _sig := PackedByteArray()
var _client: UpdateClient
var _server: UpdateServer
var _feed_checked := false
var _queued: Array = []   # 检查进行中又来的检查请求 [网址, 来源, quiet]:等这次查完再查(只留最新一个)


func _ready() -> void:
	_client = UpdateClient.new()
	add_child(_client)
	_client.progress.connect(func(ratio: float):
		progress = ratio
		changed.emit())
	_server = UpdateServer.new()
	add_child(_server)
	_confirm_healthy()


func _confirm_healthy() -> void:
	# 主菜单画出来后再跑一小会儿:太短抓不到菜单里的崩溃,太长则"打开就关"会被误判成启动失败
	for i in HEALTHY_FRAMES:
		await get_tree().process_frame
	await get_tree().create_timer(HEALTHY_SECONDS, true, false, true).timeout
	UpdateBoot.mark_healthy()


func here() -> Dictionary:
	return {"installer_build": UpdateBoot.installer["build"], "running_build": BuildInfo.build(),
		"engine": BuildInfo.engine(), "platform": BuildInfo.platform()}


static func lan_source(ip: String, port: int) -> String:
	# 端口总写明:更新服务跟着游戏端口走,format_address 省略默认端口的写法在这里不适用
	return "http://%s:%d/%s/" % [ip, port, BuildInfo.platform()]


func is_busy() -> bool:
	return state in [State.CHECKING, State.DOWNLOADING, State.READY]


# —— 检查 ——

func check(base_url: String, source_label: String, quiet := false) -> void:
	# quiet:后台检查(如启动时查网络更新源),失败或没有新版本都不打扰玩家。
	# 正在检查时(如启动时的后台检查)点了房间的"更新":排队,查完这次接着查,不能悄悄丢掉
	if state == State.CHECKING:
		_queued = [base_url, source_label, quiet]
		return
	if is_busy():
		return
	await _check_now(base_url, source_label, quiet)
	if not _queued.is_empty() and state != State.AVAILABLE:
		var next := _queued
		_queued = []
		check(next[0], next[1], next[2])
	_queued = []


func _check_now(base_url: String, source_label: String, quiet: bool) -> void:
	_set_state(State.CHECKING)
	var fetched: Dictionary = await _client.fetch_manifest(base_url)
	if not fetched["ok"]:
		_finish_check(State.IDLE if quiet else State.FAILED, "没能从%s那里取到更新:%s" % [source_label, fetched["error"]])
		return
	var found: Dictionary = fetched["manifest"]
	var blocker := UpdateManifest.blocker(found, here())
	if blocker == UpdateManifest.NOT_NEWER:
		_finish_check(State.IDLE if quiet else State.BLOCKED,
			"%s的版本 v%s 不比你的新,请让对方更新" % [source_label, found["version"]])
		return
	if blocker != "":
		_finish_check(State.BLOCKED, blocked_message(blocker, found))
		return
	manifest = found
	source = source_label
	_base_url = base_url
	_text = fetched["text"]
	_sig = fetched["sig"]
	_set_state(State.AVAILABLE)


func check_feed() -> void:
	# 互联网更新源(BuildInfo.FEED_URL)每次启动只查一次
	if BuildInfo.FEED_URL == "" or _feed_checked:
		return
	_feed_checked = true
	check(BuildInfo.FEED_URL + BuildInfo.platform() + "/", "网络", true)


static func blocked_message(blocker: String, found: Dictionary) -> String:
	if blocker == UpdateManifest.OTHER_PLATFORM:
		return "新版本 v%s 是别的系统用的,请向发布者要完整安装包" % found["version"]
	return "新版本 v%s 需要重新下载完整安装包" % found["version"]


func _finish_check(next: State, text: String) -> void:
	message = text
	_set_state(next)


func dismiss() -> void:
	if state in [State.BLOCKED, State.FAILED, State.AVAILABLE]:
		_set_state(State.IDLE)


# —— 下载与生效 ——

func download() -> void:
	if state != State.AVAILABLE:
		return
	progress = 0.0
	_set_state(State.DOWNLOADING)
	var part := UpdateBoot.DIR.path_join(DOWNLOAD_PART)
	var err: String = await _client.download(_base_url, manifest, part)
	if err == "":
		err = UpdateStore.install(UpdateBoot.DIR, manifest, _text, _sig, part, UpdateBoot.active_build)
	DirAccess.remove_absolute(part)
	if err != "":
		_finish_check(State.FAILED, "更新失败:" + err)
		return
	_set_state(State.READY)


func restart() -> void:
	# 用同样的启动参数重开,启动引导会叠加刚装好的更新包
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		args.append("--")
		args.append_array(user_args)
	OS.set_restart_on_exit(true, args)
	get_tree().quit()


# —— 房主转发 ——

func start_serving(port: int) -> void:
	var bundle := relay_bundle()
	if bundle.is_empty():
		return   # 源码运行或缺少发布清单:没有可转发的签名包
	var root := "/%s/" % bundle["manifest"]["platform"]
	var pck := FileAccess.get_file_as_bytes(bundle["pck_path"])
	# pck 同时挂在清单里的文件名和 game.pck 下:不认 pck_file 的旧客户端也能取到(同一份数据,不复制)
	var files := {
		root + "manifest.json": bundle["text"].to_utf8_buffer(),
		root + "manifest.sig": bundle["sig"],
		root + UpdateManifest.DEFAULT_PCK_FILE: pck,
		root + bundle["manifest"]["pck_file"]: pck,
	}
	var err := _server.start(port, files)
	if err != OK:
		push_warning("更新文件服务没能在端口 %d 上启动(%s),其他人无法从这里更新" % [port, error_string(err)])


func stop_serving() -> void:
	_server.stop()


func is_serving() -> bool:
	return _server != null and _server.is_serving()


func relay_bundle() -> Dictionary:
	# 自己正在运行的那份,且签名有效(不转发自己都不认的东西)
	var bundle: Dictionary
	if UpdateBoot.active_build > 0:
		bundle = UpdateStore.relay_from_update(UpdateBoot.DIR, UpdateBoot.active_build)
	else:
		bundle = UpdateStore.relay_from_installer(UpdateStore.installer_dirs())
	if bundle.is_empty() or not UpdateManifest.verify(bundle["text"], bundle["sig"], UpdateKey.PUBLIC_PEM):
		return {}
	return bundle


func _set_state(next: State) -> void:
	state = next
	changed.emit()
