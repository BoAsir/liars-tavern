extends GutTest
# AI 设置(房主本机)与请求的组装 / 回答的解析:地址补全、两种接口、存取不碰玩家设置、HTTP 错误给人看得懂的说明。


var PATH := OS.get_temp_dir().path_join("liars_tavern_ai_gut_%d.cfg" % OS.get_process_id())


func before_each():
	_remove()


func after_each():
	_remove()


func _remove():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _config(url := "https://api.deepseek.com/v1", enabled := true) -> Dictionary:
	return {AiSettings.KEY_URL: url, AiSettings.KEY_API_KEY: "sk-test", AiSettings.KEY_MODEL: "deepseek-chat",
		AiSettings.KEY_ENABLED: enabled}


# —— 设置 ——

func test_missing_file_gives_defaults():
	assert_eq(AiSettings.load_config(PATH), AiSettings.defaults())


func test_round_trip_keeps_player_settings():
	Settings.set_value(Settings.KEY_NAME, "老王", PATH)
	assert_eq(AiSettings.save_config(_config(" https://api.deepseek.com/v1 "), PATH), OK)
	var loaded := AiSettings.load_config(PATH)
	assert_eq(loaded[AiSettings.KEY_URL], "https://api.deepseek.com/v1", "去掉首尾空白")
	assert_true(loaded[AiSettings.KEY_ENABLED])
	assert_eq(Settings.get_string(Settings.KEY_NAME, "", PATH), "老王", "玩家设置还在")


func test_wrong_types_fall_back():
	var config := ConfigFile.new()
	config.set_value(AiSettings.SECTION, AiSettings.KEY_ENABLED, "yes")
	config.set_value(AiSettings.SECTION, AiSettings.KEY_MODEL, 42)
	config.save(PATH)
	var loaded := AiSettings.load_config(PATH)
	assert_false(loaded[AiSettings.KEY_ENABLED])
	assert_eq(loaded[AiSettings.KEY_MODEL], "")


func test_active_needs_switch_url_and_model():
	assert_true(AiSettings.is_active(_config()))
	assert_false(AiSettings.is_active(_config("https://api.deepseek.com/v1", false)))
	assert_false(AiSettings.is_active(_config("api.deepseek.com")), "要带 http(s)://")
	assert_false(AiSettings.is_active(_config().merged({AiSettings.KEY_MODEL: " "}, true)))
	assert_true(AiSettings.is_active(_config("http://127.0.0.1:11434/v1").merged({AiSettings.KEY_API_KEY: ""}, true)),
		"本机模型可以不填 Key")


func test_endpoints_are_completed():
	assert_eq(AiSettings.endpoint("https://api.deepseek.com/v1"), "https://api.deepseek.com/v1/chat/completions")
	assert_eq(AiSettings.endpoint("https://api.openai.com/v1/chat/completions/"),
		"https://api.openai.com/v1/chat/completions")
	assert_eq(AiSettings.endpoint("https://api.anthropic.com"), "https://api.anthropic.com/v1/messages")
	assert_eq(AiSettings.endpoint("https://api.anthropic.com/v1"), "https://api.anthropic.com/v1/messages")
	assert_eq(AiSettings.endpoint("https://llm.example.com/"), "https://llm.example.com/v1/chat/completions",
		"只填域名补 /v1")
	assert_eq(AiSettings.endpoint("https://openrouter.ai/api/v1"), "https://openrouter.ai/api/v1/chat/completions")
	assert_eq(AiSettings.endpoint("http://127.0.0.1:11434"), "http://127.0.0.1:11434/v1/chat/completions")
	assert_eq(AiSettings.kind("https://proxy.example.com/v1/messages"), AiSettings.KIND_ANTHROPIC)
	assert_eq(AiSettings.kind("https://openrouter.ai/api/v1"), AiSettings.KIND_OPENAI)


# —— 请求与回答 ——

func test_openai_request_shape():
	var req := AiChat.build_request(_config(), "系统", "问题")
	assert_eq(req["url"], "https://api.deepseek.com/v1/chat/completions")
	assert_true(Array(req["headers"]).has("Authorization: Bearer sk-test"))
	var body: Dictionary = JSON.parse_string(req["body"])
	assert_eq(body["model"], "deepseek-chat")
	assert_eq(body["messages"][0], {"role": "system", "content": "系统"})
	assert_eq(body["messages"][1]["content"], "问题")


func test_anthropic_request_shape():
	var req := AiChat.build_request(_config("https://api.anthropic.com").merged(
		{AiSettings.KEY_MODEL: "claude-sonnet-5-5"}, true), "系统", "问题")
	var headers := Array(req["headers"])
	assert_true(headers.has("x-api-key: sk-test"))
	assert_true(headers.has("anthropic-version: " + AiChat.ANTHROPIC_VERSION))
	assert_false(headers.any(func(h: String) -> bool: return h.begins_with("Authorization")))
	var body: Dictionary = JSON.parse_string(req["body"])
	assert_eq(body["system"], "系统")
	assert_true(body.has("max_tokens"))


func test_no_key_no_auth_header():
	var req := AiChat.build_request(_config().merged({AiSettings.KEY_API_KEY: ""}, true), "s", "u")
	assert_false(Array(req["headers"]).any(func(h: String) -> bool: return h.begins_with("Authorization")))


func test_parses_both_answer_shapes():
	var openai := JSON.stringify({"choices": [{"message": {"role": "assistant", "content": "{\"action\":\"call\"}"}}]})
	assert_eq(AiChat.parse_response(AiSettings.KIND_OPENAI, 200, openai), {"ok": true, "text": "{\"action\":\"call\"}"})
	var anthropic := JSON.stringify({"content": [{"type": "thinking", "thinking": "嗯"}, {"type": "text", "text": "OK"}]})
	assert_eq(AiChat.parse_response(AiSettings.KIND_ANTHROPIC, 200, anthropic), {"ok": true, "text": "OK"})


func test_bad_answers_explain_themselves():
	var unauthorized := AiChat.parse_response(AiSettings.KIND_OPENAI, 401, "{\"error\": \"bad key\"}")
	assert_false(unauthorized["ok"])
	assert_string_contains(unauthorized["error"], "API Key")
	assert_string_contains(unauthorized["error"], "401")
	assert_false(AiChat.parse_response(AiSettings.KIND_OPENAI, 200, "<html>")["ok"])
	assert_false(AiChat.parse_response(AiSettings.KIND_OPENAI, 200, "{\"choices\": []}")["ok"])
	assert_false(AiChat.parse_response(AiSettings.KIND_OPENAI, 200,
		JSON.stringify({"choices": [{"message": {"content": null}}]}))["ok"])
	assert_string_contains(AiChat.transport_error(HTTPRequest.RESULT_TIMEOUT), "秒")


func test_ask_with_a_bad_config_fails_without_a_request():
	var chat: AiChat = autofree(AiChat.new())
	add_child(chat)
	watch_signals(chat)
	var id := chat.ask(_config("ftp://nope"), "s", "u")
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(chat, "answered", [id, false, "接口地址要以 http:// 或 https:// 开头"])
	assert_eq(chat.get_child_count(), 0, "没发请求")
