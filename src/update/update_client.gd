class_name UpdateClient
extends Node
# 从一个更新源(房主的局域网文件服务,或互联网上的静态目录)取清单、验签名、下载 pck。
# 更新源的布局:<base>manifest.json、<base>manifest.sig、<base><清单里的 pck_file>。都是 await 调用。


signal progress(ratio: float)

const MANIFEST_TIMEOUT := 8.0
const DOWNLOAD_TIMEOUT := 180.0
const MAX_SIGNATURE_BYTES := 1024

var public_pem: String = UpdateKey.PUBLIC_PEM   # 测试里换成临时公钥


func fetch_manifest(base_url: String) -> Dictionary:
	# 返回 {"ok", "error", "text", "sig", "manifest"}
	var text_res := await _http_get(base_url + "manifest.json", UpdateManifest.MAX_MANIFEST_BYTES, MANIFEST_TIMEOUT)
	if not text_res["ok"]:
		return {"ok": false, "error": text_res["error"]}
	var sig_res := await _http_get(base_url + "manifest.sig", MAX_SIGNATURE_BYTES, MANIFEST_TIMEOUT)
	if not sig_res["ok"]:
		return {"ok": false, "error": sig_res["error"]}
	var text: String = text_res["body"].get_string_from_utf8()
	if not UpdateManifest.verify(text, sig_res["body"], public_pem):
		return {"ok": false, "error": "签名对不上,不是官方发布的更新包"}
	var manifest := UpdateManifest.parse(text)
	if manifest.is_empty():
		return {"ok": false, "error": "更新清单格式不对"}
	return {"ok": true, "error": "", "text": text, "sig": sig_res["body"], "manifest": manifest}


func download(base_url: String, manifest: Dictionary, dest_path: String) -> String:
	# 下载到 dest_path;返回错误说明,成功返回空串(内容核对由 UpdateStore.install 负责)
	DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
	var http := _make_request(manifest["pck_size"], DOWNLOAD_TIMEOUT)
	http.download_file = dest_path
	var err := http.request(base_url + manifest["pck_file"])
	if err != OK:
		http.queue_free()
		return "无法发起下载(%s)" % error_string(err)
	var outcome: Array = await _completion(http, func():
		progress.emit(clampf(float(http.get_downloaded_bytes()) / manifest["pck_size"], 0.0, 1.0)))
	progress.emit(1.0)
	return _describe(outcome[0], outcome[1])


func _http_get(url: String, limit: int, timeout: float) -> Dictionary:
	var http := _make_request(limit, timeout)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "无法连接更新源(%s)" % error_string(err)}
	var r: Array = await _completion(http, Callable())
	var problem := _describe(r[0], r[1])
	return {"ok": problem == "", "error": problem, "body": r[2]}


func _completion(http: HTTPRequest, each_frame: Callable) -> Array:
	# 回调里只记下结果,下一帧再继续:直接 await request_completed 会在信号发射途中释放协程状态
	var outcome := []
	http.request_completed.connect(func(result, code, _headers, body): outcome.append_array([result, code, body]),
		CONNECT_ONE_SHOT)
	while outcome.is_empty():
		if each_frame.is_valid():
			each_frame.call()
		await get_tree().process_frame
	http.queue_free()
	return outcome


func _make_request(limit: int, timeout: float) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.body_size_limit = limit
	http.timeout = timeout
	http.use_threads = true
	http.max_redirects = 0   # 地址来自可伪造的局域网报文:不跟着跳到别处
	add_child(http)
	return http


static func _describe(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "" if code == 200 else "更新源没有这个文件(HTTP %d)" % code
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "更新文件比清单里说的大,已停止下载"
		HTTPRequest.RESULT_TIMEOUT:
			return "连接更新源超时"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "连不上更新源"
		_:
			return "下载失败(错误 %d)" % result
