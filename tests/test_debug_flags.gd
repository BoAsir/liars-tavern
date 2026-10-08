extends GutTest
# DebugFlags.parse_user_args:命令行 --key=value 解析(调试开关与工具脚本共用)。


func test_parses_values_and_bare_flags():
	var opts := DebugFlags.parse_user_args(PackedStringArray(["--autohost=3", "--bot", "--room=甲=乙", "--fast"]))
	assert_eq_deep(opts, {"autohost": "3", "bot": "true", "room": "甲=乙", "fast": "true"})


func test_later_values_win():
	var opts := DebugFlags.parse_user_args(PackedStringArray(["--port=1", "--port=47811"]))
	assert_eq(opts["port"], "47811")


func test_empty_keys_are_ignored():
	assert_eq_deep(DebugFlags.parse_user_args(PackedStringArray(["--", "--=x"])), {})


func test_no_args_gives_no_flags():
	assert_eq_deep(DebugFlags.parse_user_args(PackedStringArray()), {})


# —— --species=<id>:只覆盖本次运行(不写设置);联机冒烟比对各进程打印的形象表 ——

func test_species_override_reads_a_known_id():
	assert_eq(DebugFlags.species_override(PackedStringArray(["--species=crocodile"])), 7)
	assert_eq(DebugFlags.species_override(PackedStringArray(["--bot"])), Species.UNASSIGNED, "没给就不覆盖")


func test_unknown_species_override_is_ignored():
	assert_eq(DebugFlags.species_override(PackedStringArray(["--species=dragon"])), Species.UNASSIGNED)
	assert_eq(DebugFlags.species_override(PackedStringArray(["--species"])), Species.UNASSIGNED)


func test_species_line_lists_ids_in_seat_order():
	var entries := [{"pid": 1, "species": 7}, {"pid": 2034, "species": 0}, {"pid": 99, "species": -1},
		{"pid": 5, "species": "x"}]
	assert_eq(DebugFlags.species_line(entries), "[debug] species {1: crocodile, 2034: fox, 99: -, 5: -}")
