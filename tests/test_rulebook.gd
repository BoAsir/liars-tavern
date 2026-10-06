extends GutTest


var book: Rulebook


func before_each():
	book = Rulebook.new()
	add_child_autofree(book)


func test_opens_on_first_section():
	assert_eq(book.current_section(), 0)
	assert_eq(_title(), RulebookContent.sections()[0]["title"])


func test_every_section_renders_its_blocks():
	var sections := RulebookContent.sections()
	for i in sections.size():
		book.show_section(i)
		assert_eq(book.current_section(), i)
		assert_eq(_title(), sections[i]["title"])
		var content: Control = book.find_child("Content", true, false)
		assert_eq(content.get_child_count(), sections[i]["blocks"].size(), sections[i]["id"])


func test_page_turning_clamps_at_both_ends():
	book.turn_page(-1)
	assert_eq(book.current_section(), 0)
	for i in RulebookContent.sections().size() + 2:
		book.turn_page(1)
	assert_eq(book.current_section(), RulebookContent.sections().size() - 1)


func test_show_section_ignores_out_of_range_index():
	book.show_section(99)
	book.show_section(-1)
	assert_eq(book.current_section(), 0)


func test_arrow_keys_turn_pages():
	book._input(_key(KEY_RIGHT))
	assert_eq(book.current_section(), 1)
	book._input(_key(KEY_LEFT))
	assert_eq(book.current_section(), 0)


func test_escape_and_hotkey_close_the_book():
	watch_signals(book)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	book._input(cancel)
	assert_signal_emitted(book, "closed")
	var other: Rulebook = add_child_autofree(Rulebook.new())
	watch_signals(other)
	other._input(_key(Rulebook.HOTKEY))
	assert_signal_emitted(other, "closed")


func test_takes_keyboard_focus_from_widgets_underneath_and_returns_it():
	# 主菜单的昵称框、结算的按钮等聚焦控件不能在说明书背后收到按键
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	var other: Rulebook = add_child_autofree(Rulebook.new())
	assert_false(edit.has_focus())
	other.close()
	assert_true(edit.has_focus())


func test_swallows_table_hotkeys_while_open():
	var probes := _probes_around_book()
	get_viewport().push_input(_key(KEY_C))
	assert_eq(probes[1].keys, [KEY_C], "按键应当真的送达(说明书之前的节点能收到)")
	assert_eq(probes[0].keys, [], "说明书之后的牌桌不应收到快捷键")


func test_keeps_swallowing_keys_while_fading_out():
	# 合上动画期间再按 Esc 不能漏到牌桌(否则会弹出「离开牌桌」确认)
	var probes := _probes_around_book()
	book.close()
	get_viewport().push_input(_key(KEY_ESCAPE))
	assert_eq(probes[0].keys, [])


func test_close_only_emits_once():
	watch_signals(book)
	book.close()
	book.close()
	assert_signal_emit_count(book, "closed", 1)


func _probes_around_book() -> Array:
	# _unhandled_input 按树序倒着分发:[0] 排在说明书之前(像牌桌一样后收到),[1] 排在之后(先收到)
	var behind: KeyProbe = add_child_autofree(KeyProbe.new())
	move_child(behind, book.get_index())
	var front: KeyProbe = add_child_autofree(KeyProbe.new())
	return [behind, front]


func _title() -> String:
	return (book.find_child("SectionTitle", true, false) as Label).text


func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


class KeyProbe extends Node:
	var keys := []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			keys.append(event.keycode)
