extends GutTest
# 房主的局域网文件服务 + 客户端下载,走真实的本机回环:取清单、验签名、下载并核对 pck;
# 被篡改的清单、伪造的签名、不在白名单的路径都拿不到东西。


const PORT_BASE := 47900

var key: CryptoKey
var server: UpdateServer
var client: UpdateClient
var port: int
var pck := PackedByteArray()
var text: String


func before_all():
	key = Crypto.new().generate_rsa(2048)


func before_each():
	for i in 4000:
		pck.append(i % 251)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(pck)
	text = JSON.stringify({"build": 9, "base_build": 1, "version": "0.9.0", "engine": BuildInfo.engine(),
		"platform": "macos", "pck_sha256": ctx.finish().hex_encode(), "pck_size": pck.size(), "notes": "测试"})
	server = UpdateServer.new()
	add_child_autofree(server)
	client = UpdateClient.new()
	client.public_pem = key.save_to_string(true)
	add_child_autofree(client)
	port = PORT_BASE + randi() % 90
	assert_eq(server.start(port, _files(UpdateManifest.sign(text, key))), OK)


func after_each():
	server.stop()
	pck = PackedByteArray()


func _files(sig: PackedByteArray, manifest_text := "") -> Dictionary:
	return {"/macos/manifest.json": (manifest_text if manifest_text != "" else text).to_utf8_buffer(),
		"/macos/manifest.sig": sig, "/macos/game.pck": pck}


func _base() -> String:
	return "http://127.0.0.1:%d/macos/" % port


func test_fetch_verify_and_download():
	var fetched: Dictionary = await client.fetch_manifest(_base())
	assert_true(fetched["ok"], fetched.get("error", ""))
	assert_eq(fetched["manifest"]["build"], 9)
	var dest := "user://test_download_%d.part" % randi()
	var err: String = await client.download(_base(), fetched["manifest"], dest)
	assert_eq(err, "")
	assert_eq(FileAccess.get_file_as_bytes(dest), pck)
	DirAccess.remove_absolute(dest)


func test_signature_from_another_key_is_rejected():
	var forger := Crypto.new().generate_rsa(2048)
	server.start(port, _files(UpdateManifest.sign(text, forger)))
	var fetched: Dictionary = await client.fetch_manifest(_base())
	assert_false(fetched["ok"])
	assert_string_contains(fetched["error"], "签名")


func test_tampered_manifest_is_rejected():
	var sig := UpdateManifest.sign(text, key)
	server.start(port, _files(sig, text.replace("0.9.0", "9.9.9")))
	var fetched: Dictionary = await client.fetch_manifest(_base())
	assert_false(fetched["ok"])


func test_unknown_path_is_404():
	var fetched: Dictionary = await client.fetch_manifest("http://127.0.0.1:%d/windows/" % port)
	assert_false(fetched["ok"])
	assert_string_contains(fetched["error"], "404")


func test_oversized_download_is_cut_off():
	var fetched: Dictionary = await client.fetch_manifest(_base())
	var lying: Dictionary = fetched["manifest"].duplicate()
	lying["pck_size"] = 100
	var dest := "user://test_download_%d.part" % randi()
	var err: String = await client.download(_base(), lying, dest)
	assert_ne(err, "", "比清单大就停")
	DirAccess.remove_absolute(dest)


func test_request_parsing():
	assert_eq(_status(server.respond_to("GET /macos/game.pck HTTP/1.1")), 200)
	assert_eq(_status(server.respond_to("POST /macos/game.pck HTTP/1.1")), 405)
	assert_eq(_status(server.respond_to("GET /../../etc/passwd HTTP/1.1")), 404)
	assert_eq(_status(server.respond_to("garbage")), 400)


func _status(response: Array) -> int:
	return response[0]
