extends GutTest
# ConfirmOverlay:模态确认框吞掉背后屏幕的按键;Esc 取消;只关闭一次;切屏收走时不发信号。


class KeyProbe extends Control:
	# 扮演确认框背后的屏幕(先加入场景树,晚于确认框收到未处理输入)
	var keys: Array = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			keys.append(event.keycode)


var probe: KeyProbe
var overlay: ConfirmOverlay


func before_each():
	probe = KeyProbe.new()
	add_child_autofree(probe)
	overlay = ConfirmOverlay.new("离开牌桌会被判出局,确定吗?", "离开")
	add_child_autofree(overlay)
	await wait_process_frames(1)


func _tap(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()


func test_table_shortcuts_do_not_reach_the_screen_behind():
	_tap(KEY_C)
	_tap(KEY_1)
	_tap(KEY_SPACE)
	assert_eq(probe.keys, [])


func test_escape_cancels():
	watch_signals(overlay)
	_tap(KEY_ESCAPE)
	assert_signal_emit_count(overlay, "cancelled", 1)
	assert_signal_not_emitted(overlay, "confirmed")
	assert_eq(probe.keys, [], "Esc 也不能漏到背后(牌桌会再弹一个离开确认)")


func test_closes_only_once():
	watch_signals(overlay)
	overlay._close(true)
	overlay._close(true)
	overlay._close(false)
	assert_signal_emit_count(overlay, "confirmed", 1)
	assert_signal_not_emitted(overlay, "cancelled")


func test_dismiss_is_silent():
	watch_signals(overlay)
	overlay.dismiss()
	overlay._close(true)
	assert_signal_not_emitted(overlay, "confirmed")
	assert_signal_not_emitted(overlay, "cancelled")
	assert_true(overlay.is_queued_for_deletion())


func test_keys_reach_the_screen_again_once_closed():
	overlay._close(false)
	await wait_process_frames(2)
	_tap(KEY_C)
	assert_eq(probe.keys, [KEY_C])
