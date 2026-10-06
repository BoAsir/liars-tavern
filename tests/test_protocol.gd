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
