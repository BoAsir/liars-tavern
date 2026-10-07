extends GutTest
# 更新清单:解析不可信的 JSON、RSA 签名校验、能否叠加到本机安装包上。


var key: CryptoKey
var public_pem: String


func before_all():
	key = Crypto.new().generate_rsa(2048)
	public_pem = key.save_to_string(true)


func _manifest(overrides := {}) -> Dictionary:
	var m := {
		"build": 5, "base_build": 3, "version": "0.6.0", "engine": "4.7.1.stable", "platform": "macos",
		"pck_sha256": "ab".repeat(32), "pck_size": 470000, "notes": "修了些小毛病",
	}
	m.merge(overrides, true)
	return m


func _text(overrides := {}) -> String:
	return JSON.stringify(_manifest(overrides))


func test_parse_accepts_a_well_formed_manifest():
	var m := UpdateManifest.parse(_text())
	assert_eq(m["build"], 5)
	assert_eq(m["version"], "0.6.0")
	assert_eq(m["pck_size"], 470000)


func test_parse_rejects_bad_fields():
	var bad := [
		{"build": 0}, {"build": "5"}, {"base_build": 6}, {"base_build": 0},
		{"pck_sha256": "xyz"}, {"pck_sha256": "AB".repeat(31)}, {"pck_size": 0},
		{"pck_size": UpdateManifest.MAX_PCK_SIZE + 1}, {"platform": "amiga"}, {"engine": 4},
		{"version": "x".repeat(UpdateManifest.MAX_TEXT + 1)},
	]
	for overrides in bad:
		assert_true(UpdateManifest.parse(_text(overrides)).is_empty(), str(overrides))
	assert_true(UpdateManifest.parse("not json").is_empty())
	assert_true(UpdateManifest.parse("[1]").is_empty())


func test_notes_are_sanitized_and_truncated():
	var m := UpdateManifest.parse(_text({"notes": "第一行\n第二行" + "长".repeat(500)}))
	assert_false(m["notes"].contains("\n"))
	assert_lte(m["notes"].length(), UpdateManifest.MAX_NOTES)


func test_signature_round_trip():
	var text := _text()
	var sig := UpdateManifest.sign(text, key)
	assert_true(UpdateManifest.verify(text, sig, public_pem))


func test_signature_rejects_tampering_and_other_keys():
	var text := _text()
	var sig := UpdateManifest.sign(text, key)
	assert_false(UpdateManifest.verify(_text({"pck_sha256": "cd".repeat(32)}), sig, public_pem), "改了内容")
	var other := Crypto.new().generate_rsa(2048)
	assert_false(UpdateManifest.verify(text, UpdateManifest.sign(text, other), public_pem), "别人的私钥")
	assert_false(UpdateManifest.verify(text, PackedByteArray([1, 2, 3]), public_pem), "乱码签名")
	assert_false(UpdateManifest.verify(text, sig, "not a key"), "公钥坏了")


func test_applicability():
	var m := _manifest()
	var here := {"installer_build": 3, "running_build": 4, "engine": "4.7.1.stable", "platform": "macos"}
	assert_eq(UpdateManifest.blocker(m, here), "")
	assert_eq(UpdateManifest.blocker(m, here.merged({"running_build": 5}, true)), UpdateManifest.NOT_NEWER)
	assert_eq(UpdateManifest.blocker(m, here.merged({"installer_build": 2}, true)), UpdateManifest.NEEDS_INSTALLER)
	assert_eq(UpdateManifest.blocker(m, here.merged({"engine": "4.8.0.stable"}, true)), UpdateManifest.NEEDS_INSTALLER)
	assert_eq(UpdateManifest.blocker(m, here.merged({"platform": "windows"}, true)), UpdateManifest.OTHER_PLATFORM)


func test_pck_file_name_defaults_and_is_restricted():
	assert_eq(UpdateManifest.parse(_text())["pck_file"], "game.pck", "旧清单没有这个字段")
	assert_eq(UpdateManifest.parse(_text({"pck_file": "game-b12.pck"}))["pck_file"], "game-b12.pck")
	for bad in ["../game.pck", "game-b12.pck/../../x", "evil.pck", "game-bx.pck", "game-b1.exe", 5]:
		assert_true(UpdateManifest.parse(_text({"pck_file": bad})).is_empty(), str(bad))
