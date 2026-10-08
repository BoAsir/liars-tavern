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


func test_contains_blacklist_chars_detects_banned_characters():
	# 测试黑名单字检测:笑、晓、马、飞、火、狐、楚、储
	for ch in ["笑", "晓", "马", "飞", "火", "狐", "楚", "储"]:
		assert_true(Protocol.contains_blacklist_chars(ch), "单字 '%s' 应在黑名单" % ch)
		assert_true(Protocol.contains_blacklist_chars("名字%s字" % ch), "'%s' 在中间应检测" % ch)
		assert_true(Protocol.contains_blacklist_chars("%s开头" % ch), "'%s' 在开头应检测" % ch)
		assert_true(Protocol.contains_blacklist_chars("结尾%s" % ch), "'%s' 在结尾应检测" % ch)


func test_validate_name_rejects_blacklist():
	var fail_msg := "昵称不能含有敏感字"
	assert_false(Protocol.validate_name("")["ok"], "空昵称应被拒绝")
	var blacklist_check := ["笑", "晓", "马", "飞", "火", "狐", "楚", "储"]
	for ch in blacklist_check:
		var result := Protocol.validate_name("名字%s字" % ch)
		assert_false(result["ok"], "含 '%s' 应被拒绝" % ch)
		assert_eq(result.get("error", ""), fail_msg, "'%s' 错误提示" % ch)


func test_validate_name_accepts_legit_names():
	assert_true(Protocol.validate_name("阿杰")["ok"], "合法昵称应通过")
	assert_true(Protocol.validate_name("一二三四")["ok"], "普通中文应通过")
	assert_true(Protocol.validate_name("Fj").get("ok", true), "不含黑名单字应通过")
	# sanitize 后再校验:前后空白与控制字符不应绕过黑名单
	assert_false(Protocol.validate_name(Protocol.sanitize_name("  火狐  "))["ok"])
	assert_false(Protocol.validate_name(Protocol.sanitize_name("楚\n天"))["ok"])
	# 确保不含黑名单的字不会误报
	assert_false(Protocol.contains_blacklist_chars("一二三四五六"), "不含黑名单字应返回 false")


func test_absolute_player_cap_covers_every_mode():
	# MAX_PLAYERS 是所有玩法的绝对上限(传输层槽位、发现报文校验);各玩法自己的上限看 GameMode
	for mode in GameMode.ALL:
		assert_lte(GameMode.max_players(mode), Protocol.MAX_PLAYERS, mode)
	assert_eq(Protocol.MAX_PLAYERS, GameMode.max_players(GameMode.HOLDEM))
	assert_gt(Protocol.MAX_TRANSPORT_CLIENTS, Protocol.MAX_PLAYERS, "满员时还要能握手并收到「房间已满」")


func test_legacy_discovery_cap_is_what_released_v3_clients_accept():
	# 已发布的 v3 客户端丢弃 max > 4 的发现报文:这个值冻结,不随玩法上限变
	assert_eq(Protocol.LEGACY_MAX_PLAYERS, 4)
	assert_lte(Protocol.LEGACY_MAX_PLAYERS, Protocol.MAX_PLAYERS)
