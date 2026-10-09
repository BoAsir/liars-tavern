extends GutTest
# 主菜单开房的玩法切换(ModePicker):每种可选玩法一个互斥的小号切换按钮,按 GameMode.menu_modes() 排、预选传入的玩法;
# 切到别的玩法只回调一次(被挤掉的那个按钮不回调);每种状态的样式都换成小内边距,键盘焦点只画一圈框;
# 四个按钮挤在「开一桌」标题行里也不撑宽主菜单面板。


const ModePicker := preload("res://src/ui/main_menu/mode_picker.gd")


var _selected: Array = []
var _picker: HBoxContainer


func before_each():
	_selected = []
	_picker = ModePicker.build(GameMode.SHORT_DECK, func(mode: String): _selected.append(mode))
	add_child_autofree(_picker)


func _buttons() -> Array:
	return _picker.get_children()


func test_one_toggle_per_mode_in_order_with_label_and_summary():
	var modes := GameMode.menu_modes()
	assert_eq(_buttons().size(), modes.size())
	for i in modes.size():
		var button: Button = _buttons()[i]
		assert_true(button.toggle_mode, "是切换按钮")
		assert_eq(button.text, GameMode.short_label(modes[i]))
		assert_eq(button.tooltip_text, GameMode.summary(modes[i]))


func test_only_the_given_mode_starts_pressed():
	var pressed := _buttons().filter(func(b: Button): return b.button_pressed)
	assert_eq(pressed.size(), 1)
	assert_eq(pressed[0].text, GameMode.short_label(GameMode.SHORT_DECK))
	assert_eq(_selected, [], "预选不算选择,不回调")


func test_pressing_another_mode_reports_it_once_and_unpresses_the_old_one():
	_buttons()[0].button_pressed = true
	assert_eq(_selected, [GameMode.LIARS])
	assert_false(_buttons()[GameMode.menu_modes().find(GameMode.SHORT_DECK)].button_pressed, "互斥:原来选中的被挤掉")
	_buttons()[0].button_pressed = true
	assert_eq(_selected, [GameMode.LIARS], "再点已选中的不重复回调")


func test_every_state_uses_the_small_padding_and_focus_is_only_a_ring():
	var button: Button = _buttons()[0]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state)
		assert_eq(Vector2(box.content_margin_left, box.content_margin_top), ModePicker.PADDING, state)
		assert_eq(Vector2(box.content_margin_right, box.content_margin_bottom), ModePicker.PADDING, state)
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
	assert_false(focus.draw_center, "焦点框不盖住底色")
	assert_true(button.get_theme_stylebox("normal").draw_center)
