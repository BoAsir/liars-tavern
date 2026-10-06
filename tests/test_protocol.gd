extends GutTest


func test_parse_plain_ip_uses_default_game_port():
	var addr := Protocol.parse_address("192.168.1.10")
	assert_true(addr["ok"])
	assert_eq(addr["ip"], "192.168.1.10")
	assert_eq(addr["port"], Protocol.GAME_PORT)


func test_parse_ip_with_port():
	var addr := Protocol.parse_address(" 10.0.0.7:47812 ")
	assert_true(addr["ok"])
	assert_eq(addr["ip"], "10.0.0.7")
	assert_eq(addr["port"], 47812)


func test_parse_localhost_maps_to_loopback():
	var addr := Protocol.parse_address("localhost")
	assert_true(addr["ok"])
	assert_eq(addr["ip"], "127.0.0.1")


func test_parse_accepts_full_width_punctuation_and_digits():
	# 中文输入法的全角冒号/句号/数字与夹在中间的空格(含全角空格)都按半角处理
	var ideographic_space := String.chr(0x3000)
	var cases := {
		"192.168.1.8：47811": ["192.168.1.8", 47811],
		"192。168。1。8": ["192.168.1.8", Protocol.GAME_PORT],
		"１９２．１６８．１．８：４７８１２": ["192.168.1.8", 47812],
		" 192.168.1.8 : 47811 ": ["192.168.1.8", 47811],
		ideographic_space + "192.168.1.8" + ideographic_space: ["192.168.1.8", Protocol.GAME_PORT],
	}
	for text in cases:
		var addr := Protocol.parse_address(text)
		assert_true(addr["ok"], "should accept '%s'" % text)
		assert_eq(addr.get("ip"), cases[text][0], text)
		assert_eq(addr.get("port"), cases[text][1], text)


func test_parse_normalizes_ip_and_localhost_case():
	assert_eq(Protocol.parse_address("192.168.001.008")["ip"], "192.168.1.8")
	assert_eq(Protocol.parse_address("LocalHost")["ip"], "127.0.0.1")


func test_parse_rejects_empty_garbage_and_bad_ports():
	for text in ["", "   ", "abc", "1.2.3", "300.1.1.1", "1.2.3.4:", "1.2.3.4:0",
			"1.2.3.4:70000", "1.2.3.4:abc", "1.2.3.4:1:2", "::1"]:
		var addr := Protocol.parse_address(text)
		assert_false(addr["ok"], "should reject '%s'" % text)
		assert_ne(addr.get("error", ""), "", "error message for '%s'" % text)


func test_format_address_omits_default_port():
	assert_eq(Protocol.format_address("192.168.1.10", Protocol.GAME_PORT), "192.168.1.10")
	assert_eq(Protocol.format_address("192.168.1.10", 47813), "192.168.1.10:47813")


func test_discovery_ports_do_not_overlap_game_ports():
	var discovery := Protocol.discovery_ports()
	assert_eq(discovery.size(), Protocol.DISCOVERY_PORT_COUNT)
	for i in Protocol.GAME_PORT_ATTEMPTS:
		assert_false(discovery.has(Protocol.GAME_PORT + i))


func test_sanitize_name_trims_and_limits_length():
	assert_eq(Protocol.sanitize_name("  阿杰  "), "阿杰")
	assert_eq(Protocol.sanitize_name("一二三四五六七八九十甲乙丙丁").length(), Protocol.MAX_NAME_LENGTH)
	assert_eq(Protocol.sanitize_name("a\nb\tc"), "abc")
	assert_eq(Protocol.sanitize_text("房间\u0001名 ", Protocol.MAX_ROOM_NAME_LENGTH), "房间名")


func test_sanitize_huge_input_is_fast_and_truncated():
	# 不可信输入:百万字符的昵称/房名(含夹在中间的大量控制字符)也只做与 max_length 成正比的工作。
	# 旧实现逐字拼接是 O(n²)(64k 字符就要 140 ms);只在输出够长时停下的循环遇到控制字符洪泛仍要 60 ms
	var huge := "x".repeat(1_000_000)
	var control_flood := "阿" + "\u0001".repeat(1_000_000) + "杰"
	var started := Time.get_ticks_usec()
	var cleaned := Protocol.sanitize_name(huge)
	var flooded := Protocol.sanitize_text(control_flood, Protocol.MAX_ROOM_NAME_LENGTH)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	assert_eq(cleaned, "x".repeat(Protocol.MAX_NAME_LENGTH))
	assert_eq(flooded, "阿")
	assert_lt(elapsed_ms, 20.0, "sanitize took %.2f ms" % elapsed_ms)


func test_raw_join_name_limit_leaves_room_for_any_legit_name():
	# 正常客户端只发清洗后的短昵称;房主在 RPC 入口按这个上限直接拒绝超长昵称
	assert_gt(Protocol.MAX_RAW_NAME_LENGTH, Protocol.MAX_NAME_LENGTH)
