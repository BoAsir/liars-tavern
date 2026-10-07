extends GutTest


func _info(id := "r1", room := "老王的酒馆") -> Dictionary:
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


func test_encode_decode_roundtrip_normalizes_numbers():
	var decoded := RoomList.decode(RoomList.encode(_info()))
	assert_eq(decoded["id"], "r1")
	assert_eq(decoded["room"], "老王的酒馆")
	assert_eq(typeof(decoded["players"]), TYPE_INT)
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
	# 人数/上限会驱动主菜单的座位圆点:越界报文(伪造或故障)整包丢弃
	var bad_counts := [
		[-1, 4], [5, 4], [3, 2], [0, 1], [2, 5], [2, 0], [-3, 99999999],
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
		assert_eq(decoded.get("players"), counts[0], str(counts))
		assert_eq(decoded.get("max"), counts[1], str(counts))


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
