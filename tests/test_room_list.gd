extends GutTest


const V3_MAX_PLAYERS := 4   # 已发布的 v3 客户端在发现报文里接受的人数上限


func _info(id := "r1", room := "老王的酒馆") -> Dictionary:
	# 不带 v4 字段的报文(v3 房主):人数与上限只在 players/max 里
	return {
		"id": id,
		"room": room,
		"host": "老王",
		"players": 2,
		"max": 4,
		"version": Protocol.VERSION,
		"port": Protocol.GAME_PORT,
		"open": true,
	}


func _poker_info(seated: int, cap := GameMode.POKER_MAX_PLAYERS, mode := GameMode.HOLDEM) -> Dictionary:
	# v4 德州房间的报文:旧字段 players/max 压在 4 以内,真实人数与玩法上限在 seated/cap
	var legacy := mini(cap, Protocol.LEGACY_MAX_PLAYERS)
	return _info().merged({"players": mini(seated, legacy), "max": legacy, "seated": seated, "cap": cap,
		"mode": mode, "playing": true}, true)


static func v3_accepts(bytes: PackedByteArray) -> bool:
	# 已发布的 v3 客户端的报文校验(当时 RoomList.decode 的规则)。v4 房主的报文必须过得了它,
	# 否则旧玩家看不到德州房间,也就没法从房主那里更新
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return false
	var parsed: Dictionary = json.data
	for key in ["id", "room", "host"]:
		if not parsed.get(key) is String:
			return false
	for key in ["players", "max", "version", "port"]:
		var value = parsed.get(key)
		if not (value is float or value is int):
			return false
	var players := int(parsed["players"])
	var capacity := int(parsed["max"])
	var port := int(parsed["port"])
	if port < 1 or port > 65535 or capacity < Protocol.MIN_PLAYERS or capacity > V3_MAX_PLAYERS:
		return false
	if players < 0 or players > capacity or not parsed.get("open", true) is bool:
		return false
	var build = parsed.get("build", 0)
	return (build is float or build is int) and parsed.get("ver", "") is String \
		and parsed.get("update", false) is bool and parsed.get("plat", "") is String


func _decode(info: Dictionary) -> Dictionary:
	return RoomList.decode(RoomList.encode(info))


func test_encode_decode_roundtrip_normalizes_numbers():
	var decoded := RoomList.decode(RoomList.encode(_info()))
	assert_eq(decoded["id"], "r1")
	assert_eq(decoded["room"], "老王的酒馆")
	assert_eq(typeof(decoded["seated"]), TYPE_INT)
	assert_eq(decoded["port"], Protocol.GAME_PORT)
	assert_true(decoded["open"])


func test_decode_rejects_garbage_and_missing_fields():
	assert_true(RoomList.decode("not json".to_utf8_buffer()).is_empty())
	assert_true(RoomList.decode("[1,2]".to_utf8_buffer()).is_empty())
	var missing := _info()
	missing.erase("port")
	assert_true(RoomList.decode(RoomList.encode(missing)).is_empty())
	var bad_port := _info()
	bad_port["port"] = 99999
	assert_true(RoomList.decode(RoomList.encode(bad_port)).is_empty())


func test_decode_rejects_out_of_range_player_counts():
	# 人数/上限会驱动主菜单的座位显示:越界报文(伪造或故障)整包丢弃
	var bad_counts := [
		[-1, 4], [5, 4], [3, 2], [0, 1], [2, Protocol.MAX_PLAYERS + 1], [2, 0], [-3, 99999999],
		[2000000000, 4], [2147483647, 2147483647], [1, -4],
	]
	for counts in bad_counts:
		var info := _info()
		info["players"] = counts[0]
		info["max"] = counts[1]
		assert_true(RoomList.decode(RoomList.encode(info)).is_empty(), "players/max %s" % str(counts))


func test_decode_accepts_counts_within_limits():
	for counts in [[0, Protocol.MIN_PLAYERS], [1, 4], [4, 4], [2, 3]]:
		var info := _info()
		info["players"] = counts[0]
		info["max"] = counts[1]
		var decoded := RoomList.decode(RoomList.encode(info))
		assert_eq(decoded.get("seated"), counts[0], str(counts))
		assert_eq(decoded.get("cap"), counts[1], str(counts))


func test_v4_poker_packets_pass_the_released_v3_rules():
	for seated in range(GameMode.POKER_MAX_PLAYERS + 1):
		assert_true(v3_accepts(RoomList.encode(_poker_info(seated))), "seated %d" % seated)
	assert_false(v3_accepts(RoomList.encode(_info().merged({"max": 8}, true))), "对照:v3 规则确实丢弃 max 8")


func test_v4_parser_reads_cap_and_seated():
	var decoded := _decode(_poker_info(6))
	assert_eq(decoded["cap"], 8)
	assert_eq(decoded["seated"], 6)
	assert_eq(decoded["mode"], GameMode.HOLDEM)
	assert_true(decoded["playing"])
	assert_true(decoded["compatible"])
	assert_false(decoded.has("players"), "旧字段只是给 v3 解析器看的,解码后只留 seated/cap")
	assert_false(decoded.has("max"))


func test_cap_and_seated_are_range_checked_against_the_mode():
	var bad := [
		{"cap": 9}, {"cap": 1}, {"seated": 9}, {"seated": -1}, {"cap": 6, "seated": 7},
		{"mode": GameMode.LIARS, "cap": 5}, {"cap": "8"}, {"seated": true},
	]
	for change in bad:
		assert_true(_decode(_poker_info(3).merged(change, true)).is_empty(), str(change))
	assert_eq(_decode(_poker_info(3).merged({"mode": GameMode.LIARS, "cap": 4}, true)).get("cap"), 4)


func test_cap_and_seated_come_together():
	for key in ["cap", "seated"]:
		var info := _poker_info(3)
		info.erase(key)
		assert_true(_decode(info).is_empty(), "缺 %s" % key)


func test_without_cap_max_is_checked_against_the_mode():
	# 没有 cap 的报文按 max/players 与玩法上限校验:骗子酒馆报 max 5 照样丢弃,德州 8 人合法
	assert_true(_decode(_info().merged({"max": 5}, true)).is_empty())
	var poker := _decode(_info().merged({"players": 8, "max": 8, "mode": GameMode.SHORT_DECK}, true))
	assert_eq(poker.get("seated"), 8)
	assert_eq(poker.get("cap"), 8)


func test_mode_and_playing_default_for_old_hosts_and_are_type_checked():
	var old := _decode(_info())
	assert_eq(old["mode"], GameMode.LIARS)
	assert_false(old["playing"])
	for bad in [{"mode": 3}, {"mode": null}, {"mode": [GameMode.HOLDEM]}, {"playing": "yes"}, {"playing": 1}]:
		assert_true(_decode(_info().merged(bad, true)).is_empty(), str(bad))


func test_unknown_mode_is_listed_but_not_compatible():
	# 更新的版本可能带来新玩法:照样列出(好提示从房主更新),但标成不兼容;玩法 id 不信任长度
	var decoded := _decode(_poker_info(5, 6, "x".repeat(100)))
	assert_false(decoded.is_empty())
	assert_false(decoded["compatible"])
	assert_lte(decoded["mode"].length(), RoomList.MAX_TEXT)
	assert_eq(decoded["cap"], 6)
	assert_true(_decode(_poker_info(5, Protocol.MAX_PLAYERS + 1, "mahjong")).is_empty(), "绝对上限照样卡住")


func test_decode_truncates_long_text_fields():
	var info := _info("x".repeat(100), "房".repeat(100))
	var decoded := RoomList.decode(RoomList.encode(info))
	assert_lte(decoded["id"].length(), RoomList.MAX_TEXT)
	assert_lte(decoded["room"].length(), RoomList.MAX_TEXT)


func test_ingest_adds_room_with_sender_ip():
	var list := RoomList.new()
	assert_true(list.ingest(_info(), "192.168.1.20", 0.0))
	var rooms := list.rooms()
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0]["ip"], "192.168.1.20")
	assert_eq(rooms[0]["room"], "老王的酒馆")


func test_same_room_from_loopback_and_lan_dedupes_preferring_lan_ip():
	var list := RoomList.new()
	list.ingest(_info(), "127.0.0.1", 0.0)
	list.ingest(_info(), "192.168.1.20", 0.1)
	list.ingest(_info(), "127.0.0.1", 0.2)
	var rooms := list.rooms()
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0]["ip"], "192.168.1.20")


func test_repeated_identical_packet_is_not_a_change():
	var list := RoomList.new()
	list.ingest(_info(), "192.168.1.20", 0.0)
	assert_false(list.ingest(_info(), "192.168.1.20", 0.5))
	var updated := _info()
	updated["players"] = 3
	assert_true(list.ingest(updated, "192.168.1.20", 0.6))


func test_prune_removes_stale_rooms():
	var list := RoomList.new()
	list.ingest(_info("a"), "192.168.1.20", 0.0)
	list.ingest(_info("b", "B"), "192.168.1.21", 2.0)
	assert_false(list.prune(2.5))
	assert_true(list.prune(Protocol.ROOM_TTL + 0.1))
	var rooms := list.rooms()
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0]["id"], "b")


func test_rooms_sorted_by_name():
	var list := RoomList.new()
	list.ingest(_info("b", "乙"), "192.168.1.21", 0.0)
	list.ingest(_info("a", "Alpha"), "192.168.1.20", 0.0)
	var rooms := list.rooms()
	assert_eq(rooms[0]["room"], "Alpha")


func test_ingest_caps_number_of_rooms():
	# 伪造报文洪泛(每包一个新 id)不能让列表无限增长;已在列表里的房间照常刷新
	var list := RoomList.new()
	for i in RoomList.MAX_ROOMS:
		assert_true(list.ingest(_info("r%d" % i), "192.168.1.20", 0.0))
	assert_false(list.ingest(_info("flood"), "192.168.1.66", 0.1))
	assert_eq(list.rooms().size(), RoomList.MAX_ROOMS)
	var updated := _info("r0")
	updated["players"] = 3
	assert_true(list.ingest(updated, "192.168.1.20", 0.2))
	assert_true(list.prune(Protocol.ROOM_TTL + 0.1))
	assert_true(list.ingest(_info("late"), "192.168.1.30", Protocol.ROOM_TTL + 0.1))


func test_clear_empties_list():
	var list := RoomList.new()
	list.ingest(_info(), "192.168.1.20", 0.0)
	list.clear()
	assert_eq(list.rooms(), [])


func test_other_protocol_versions_are_kept_but_marked_incompatible():
	# 房主版本更新时也要列出来,界面据此提示从房主那里更新
	var newer := _info()
	newer["version"] = Protocol.VERSION + 1
	var decoded := RoomList.decode(RoomList.encode(newer))
	assert_false(decoded["compatible"])
	assert_true(RoomList.decode(RoomList.encode(_info()))["compatible"])


func test_build_fields_default_for_old_hosts_and_are_type_checked():
	var old := RoomList.decode(RoomList.encode(_info()))
	assert_eq(old["build"], 0)
	assert_eq(old["ver"], "")
	assert_false(old["update"])
	var info := _info()
	info.merge({"build": 12, "ver": "0.6.0\n", "update": true, "plat": "macos"})
	var decoded := RoomList.decode(RoomList.encode(info))
	assert_eq(decoded["build"], 12)
	assert_eq(decoded["ver"], "0.6.0")
	assert_true(decoded["update"])
	assert_eq(decoded["plat"], "macos")
	for bad in [{"build": "12"}, {"ver": 6}, {"update": "yes"}, {"plat": 1}]:
		var forged := _info()
		forged.merge(bad, true)
		assert_true(RoomList.decode(RoomList.encode(forged)).is_empty(), str(bad))
