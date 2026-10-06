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
