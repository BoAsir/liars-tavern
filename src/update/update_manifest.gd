class_name UpdateManifest
# 更新清单:描述一个签过名的游戏内容包(pck)。来源不可信(局域网里任何人都能冒充房主),
# 所以先验签名再信内容:签名是发布者私钥对清单原文的 RSA-SHA256,公钥嵌在游戏里(UpdateKey)。
# 清单里记着 pck 的 SHA-256 与大小,下载完再逐字节核对。


const MAX_PCK_SIZE := 64 * 1024 * 1024
const MAX_TEXT := 40
const MAX_NOTES := 200
const MAX_MANIFEST_BYTES := 16 * 1024
const PLATFORMS := ["macos", "windows", "linux"]
# 更新源里 pck 的文件名:默认 game.pck;发布时按 build 命名(game-b<build>.pck),
# 网上的缓存不会把新清单和旧 pck 配在一起
const DEFAULT_PCK_FILE := "game.pck"

# blocker() 的结果:空串表示可以更新
const NOT_NEWER := "not_newer"
const NEEDS_INSTALLER := "needs_installer"
const OTHER_PLATFORM := "other_platform"


static func parse(text: String) -> Dictionary:
	if text.length() > MAX_MANIFEST_BYTES:
		return {}
	var json := JSON.new()   # 实例解析:坏数据只返回错误码,不往日志里报错
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	var out := {}
	for field in ["build", "base_build", "pck_size"]:
		var value = data.get(field)
		if not (value is float or value is int) or value != floorf(value):
			return {}
		out[field] = int(value)
	for field in ["version", "engine", "platform", "pck_sha256"]:
		var value = data.get(field)
		if not value is String or value.length() > maxi(MAX_TEXT, 64):
			return {}
		out[field] = value
	if out["build"] < 1 or out["base_build"] < 1 or out["base_build"] > out["build"]:
		return {}
	if out["pck_size"] < 1 or out["pck_size"] > MAX_PCK_SIZE:
		return {}
	if not PLATFORMS.has(out["platform"]) or out["version"].length() > MAX_TEXT or out["engine"].length() > MAX_TEXT:
		return {}
	if not _is_sha256(out["pck_sha256"]):
		return {}
	var notes = data.get("notes", "")
	out["notes"] = Protocol.sanitize_text(notes, MAX_NOTES) if notes is String else ""
	var pck_file = data.get("pck_file", DEFAULT_PCK_FILE)
	if not is_pck_file_name(pck_file):
		return {}
	out["pck_file"] = pck_file
	return out


static func is_pck_file_name(value) -> bool:
	# 只能是 game.pck 或 game-b<数字>.pck:文件名会拼进下载地址和房主的文件服务路径
	if not value is String:
		return false
	if value == DEFAULT_PCK_FILE:
		return true
	return value.begins_with("game-b") and value.ends_with(".pck") \
		and value.trim_prefix("game-b").trim_suffix(".pck").is_valid_int()


static func _is_sha256(text: String) -> bool:
	if text.length() != 64:
		return false
	for c in text:
		if not "0123456789abcdef".contains(c):
			return false
	return true


static func sign(text: String, private_key: CryptoKey) -> PackedByteArray:
	return Crypto.new().sign(HashingContext.HASH_SHA256, _digest(text), private_key)


static func verify(text: String, signature: PackedByteArray, public_pem: String) -> bool:
	if not public_pem.begins_with("-----BEGIN PUBLIC KEY-----"):
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_pem, true) != OK:
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, _digest(text), signature, key)


static func _digest(text: String) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish()


static func blocker(manifest: Dictionary, here: Dictionary) -> String:
	# here: {"installer_build", "running_build", "engine", "platform"}
	# 平台不同的 pck 不能用;引擎版本不同、或安装包旧于 base_build(改过项目设置)只能重装完整安装包
	if manifest["platform"] != here["platform"]:
		return OTHER_PLATFORM
	if manifest["build"] <= here["running_build"]:
		return NOT_NEWER
	if manifest["engine"] != here["engine"] or here["installer_build"] < manifest["base_build"]:
		return NEEDS_INSTALLER
	return ""
