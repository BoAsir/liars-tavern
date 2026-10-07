extends GutTest


const LIARS := RulebookContent.BOOK_LIARS
const POKER := RulebookContent.BOOK_POKER

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


# —— 两本书 ——

func test_opens_on_the_liars_book_by_default():
	assert_eq(book.current_book(), LIARS)
	assert_true(book._tabs[LIARS].button_pressed)
	assert_false(book._tabs[POKER].button_pressed)


func test_opens_the_requested_book_with_its_own_chapters():
	var poker: Rulebook = add_child_autofree(Rulebook.new(false, POKER))
	assert_eq(poker.current_book(), POKER)
	assert_eq(_title(poker), RulebookContent.sections(POKER)[0]["title"])
	_assert_nav_matches(poker, POKER)
	assert_true(poker._tabs[POKER].button_pressed)
	assert_false(poker._tabs[LIARS].button_pressed)


func test_unknown_book_falls_back_to_liars():
	var other: Rulebook = add_child_autofree(Rulebook.new(false, "chess"))
	assert_eq(other.current_book(), LIARS)
	_assert_nav_matches(other, LIARS)


func test_every_poker_section_renders_its_blocks():
	book.show_book(POKER)
	var sections := RulebookContent.sections(POKER)
	for i in sections.size():
		book.show_section(i)
		assert_eq(_title(), sections[i]["title"])
		assert_eq(_content().get_child_count(), sections[i]["blocks"].size(), sections[i]["id"])


func test_switching_books_rebuilds_nav_and_redraws_from_page_zero():
	# 两本都停在第 0 页:不复位的话 show_section(0) 会当作没换页,正文还是上一本的
	book.show_book(POKER)
	var sections := RulebookContent.sections(POKER)
	assert_eq(book.current_book(), POKER)
	assert_eq(book.current_section(), 0)
	assert_eq(_title(), sections[0]["title"])
	assert_eq(_content().get_child_count(), sections[0]["blocks"].size())
	_assert_nav_matches(book, POKER)
	assert_eq(book._page_label.text, "1 / %d" % sections.size())
	assert_true(book._tabs[POKER].button_pressed)
	assert_false(book._tabs[LIARS].button_pressed)


func test_switching_books_frees_the_old_chapter_buttons_at_once():
	# 旧目录按钮当场释放:留到帧末的话,同一帧里还挂着一批移出树的孤儿按钮
	var old := book._nav_buttons.duplicate()
	book.show_book(POKER)
	for button in old:
		assert_false(is_instance_valid(button))


func test_page_turning_stays_within_the_current_book():
	book.show_book(POKER)
	for i in RulebookContent.sections(POKER).size() + 2:
		book.turn_page(1)
	assert_eq(book.current_section(), RulebookContent.sections(POKER).size() - 1)
	assert_true(book._next.disabled)


func test_each_book_keeps_its_own_page():
	book.show_section(3)
	book.show_book(POKER)
	assert_eq(book.current_section(), 0, "第一次翻开德州那本从头读")
	book.show_section(2)
	book.show_book(LIARS)
	assert_eq(book.current_section(), 3)
	book.show_book(POKER)
	assert_eq(book.current_section(), 2)
	assert_eq(book.bookmarks(), {LIARS: 3, POKER: 2})


func test_opens_at_remembered_pages_and_clamps_stale_ones():
	var pages := {POKER: 2, LIARS: 99}
	var other: Rulebook = add_child_autofree(Rulebook.new(false, POKER, pages))
	assert_eq(other.current_section(), 2)
	other.show_book(LIARS)
	assert_eq(other.current_section(), RulebookContent.sections(LIARS).size() - 1, "越界的页码夹到最后一页")
	other.show_section(1)
	assert_eq(pages, {POKER: 2, LIARS: 99}, "不改调用方传进来的字典")


func test_tabs_switch_books():
	book._tabs[POKER].pressed.emit()
	assert_eq(book.current_book(), POKER)
	assert_true(book._tabs[POKER].button_pressed)
	assert_false(book._tabs[LIARS].button_pressed)
	book._tabs[LIARS].pressed.emit()
	assert_eq(book.current_book(), LIARS)
	assert_eq(_title(), RulebookContent.sections(LIARS)[0]["title"])


func test_announces_every_book_it_shows():
	# 德州牌面在后台生成的触发点(规格 §5.2):翻开时与每次切书各报一次
	var other := Rulebook.new(false, POKER)
	watch_signals(other)
	add_child_autofree(other)
	assert_signal_emitted_with_parameters(other, "book_shown", [POKER])
	other.show_book(LIARS)
	other.show_book(LIARS)
	assert_signal_emit_count(other, "book_shown", 2, "切到正在看的这本不算")
	assert_signal_emitted_with_parameters(other, "book_shown", [LIARS])


func test_refresh_card_faces_reloads_the_example_cards_on_the_page():
	# 牌面生成完之前取到的是占位纹理;刷新入口把当前页的示例小牌重新取一遍
	book.show_book(POKER)
	book.show_section(_index_of(POKER, "hands"))
	var faces := _content().find_children("*", "TextureRect", true, false)
	assert_eq(faces.size(), RulebookPoker.hands_block()["items"].size() * RulebookPoker.STRAIGHT_LENGTH)
	for face in faces:
		face.texture = null
	book.refresh_card_faces()
	for face in faces:
		assert_not_null(face.texture)


func test_every_page_fits_the_fixed_book_width():
	# 不换行的文字(牌型表、键位表)太宽会把整本书撑宽:两本书的每一页都要放得下
	for book_id in RulebookContent.BOOKS:
		book.show_book(book_id)
		for i in RulebookContent.sections(book_id).size():
			book.show_section(i)
			assert_lte(book._panel.get_combined_minimum_size().x, Rulebook.PANEL_SIZE.x, "%s 第 %d 页" % [book_id, i + 1])


func _assert_nav_matches(rulebook: Rulebook, book_id: String) -> void:
	var sections := RulebookContent.sections(book_id)
	assert_eq(rulebook._nav_buttons.size(), sections.size())
	assert_eq(rulebook._nav.get_child_count(), sections.size(), "旧目录要移出")
	for i in mini(sections.size(), rulebook._nav_buttons.size()):
		assert_string_ends_with(rulebook._nav_buttons[i].text, sections[i]["title"])
	assert_true(rulebook._nav_buttons[rulebook.current_section()].button_pressed)


func _index_of(book_id: String, section_id: String) -> int:
	var sections := RulebookContent.sections(book_id)
	for i in sections.size():
		if sections[i]["id"] == section_id:
			return i
	return -1


func _content(rulebook: Rulebook = book) -> Control:
	return rulebook.find_child("Content", true, false)


func _probes_around_book() -> Array:
	# _unhandled_input 按树序倒着分发:[0] 排在说明书之前(像牌桌一样后收到),[1] 排在之后(先收到)
	var behind: KeyProbe = add_child_autofree(KeyProbe.new())
	move_child(behind, book.get_index())
	var front: KeyProbe = add_child_autofree(KeyProbe.new())
	return [behind, front]


func _title(rulebook: Rulebook = book) -> String:
	return (rulebook.find_child("SectionTitle", true, false) as Label).text


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
