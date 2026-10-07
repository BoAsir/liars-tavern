extends GutTest
# 牌型表块(hands)的渲染:每行 5 张不超过 40×58 的示例小牌(mipmap 过滤,记着牌值供刷新)、
# 长牌与短牌的名次两列,只有名次不同的两行高亮;表下注明 A 当最小牌的顺子。


const MAX_CARD_SIZE := Vector2(40, 58)   # 规格 §6.6

var block: Dictionary
var table: Control


func before_each():
	block = RulebookPoker.hands_block()
	table = RulebookBlocks.build(block)
	add_child_autofree(table)


func test_draws_the_example_cards_of_every_row_in_order():
	var faces := table.find_children("*", "TextureRect", true, false)
	var expected := []
	for item in block["items"]:
		expected.append_array(item["cards"])
	assert_eq(faces.map(func(face): return face.get_meta(RulebookBlocks.CARD_META)), expected)


func test_cards_are_small_mipmapped_and_textured():
	for face: TextureRect in table.find_children("*", "TextureRect", true, false):
		assert_lte(face.custom_minimum_size.x, MAX_CARD_SIZE.x)
		assert_lte(face.custom_minimum_size.y, MAX_CARD_SIZE.y)
		assert_eq(face.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "从大纹理缩小很多倍(规格 §5.3)")
		assert_not_null(face.texture, "牌面还没生成时也要有占位纹理")


func test_lists_both_places_and_highlights_only_the_rows_that_differ():
	var items: Array = block["items"]
	var long_cells := table.find_children("LongPlace", "Label", true, false)
	var short_cells := table.find_children("ShortPlace", "Label", true, false)
	assert_eq(long_cells.size(), items.size())
	assert_eq(short_cells.size(), items.size())
	for i in mini(items.size(), short_cells.size()):
		assert_eq(long_cells[i].text, str(items[i]["long"]))
		assert_string_starts_with(short_cells[i].text, str(items[i]["short"]))
		var highlighted: bool = short_cells[i].get_theme_color("font_color") == RulebookBlocks.HANDS_HIGHLIGHT
		assert_eq(highlighted, items[i]["highlight"], items[i]["name"])


func test_rows_show_the_category_name_and_caption():
	var texts := table.find_children("*", "Label", true, false).map(func(label): return label.text)
	for item in block["items"]:
		assert_has(texts, item["name"])
		assert_has(texts, item["caption"])


func test_header_names_both_decks_and_the_note_follows_the_table():
	var labels := table.find_children("*", "Label", true, false)
	var texts := labels.map(func(label): return label.text)
	assert_has(texts, "长牌名次")
	assert_has(texts, "短牌名次")
	assert_eq(labels[-1].text, block["note"])


func test_refresh_cards_reloads_every_example_card():
	var faces := table.find_children("*", "TextureRect", true, false)
	for face in faces:
		face.texture = null
	RulebookBlocks.refresh_cards(table)
	for face in faces:
		assert_not_null(face.texture)
