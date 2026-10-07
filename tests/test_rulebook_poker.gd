extends GutTest
# 德州那本说明书:章节齐全、文案里的数字取自规则常量、不出现花色符号;
# 牌型表(hands 块)的名次与 PokerRules 一致,只高亮短牌对调的同花/葫芦,示例牌在长短牌里都名副其实。


const POKER := RulebookContent.BOOK_POKER
const HAND_SIZE := 5


func test_sections_have_unique_ids_titles_and_blocks():
	var ids := {}
	for section in RulebookContent.sections(POKER):
		assert_false(ids.has(section["id"]), "重复的章节 id:" + section["id"])
		ids[section["id"]] = true
		assert_ne(section["title"], "")
		assert_false(section["blocks"].is_empty(), section["id"] + " 没有内容")


func test_every_block_type_is_known():
	for section in RulebookContent.sections(POKER):
		for block in section["blocks"]:
			assert_has(RulebookContent.BLOCK_TYPES, block["type"])


func test_covers_play_hands_betting_and_controls():
	# 规格 §6.6 的四部分(怎么玩、牌型、下注、操作);一手的流程、底池、筹码与散局各自成章
	for id in ["play", "hand", "hands", "betting", "pots", "session", "controls"]:
		assert_eq(RulebookContent.find(id, POKER).get("id"), id)


func test_text_follows_rule_constants():
	var text := _book_text()
	assert_string_contains(text, "%d–%d 人" % [PokerRules.MIN_PLAYERS, PokerRules.MAX_SEATS])
	assert_string_contains(text, "领 %d 筹码" % PokerRules.STARTING_STACK)
	assert_string_contains(text, "再领 %d" % PokerRules.STARTING_STACK)
	assert_string_contains(text, "盲注 %d/%d" % [PokerRules.SMALL_BLIND, PokerRules.BIG_BLIND])
	assert_string_contains(text, "%d 秒" % int(Protocol.TURN_TIMEOUT))
	assert_string_contains(text, "%d 张" % PokerRules.deck_size(false))
	assert_string_contains(text, "%d 张" % PokerRules.deck_size(true))


func test_text_has_no_suit_symbols():
	# 规格 §6.1:界面字体里没有花色字形(系统回退可能变成彩色 emoji),具体的牌一律画成小牌
	var text := _book_text()
	for symbol in PokerCard.SUIT_SYMBOLS:
		assert_false(text.contains(symbol), "文案里出现了花色符号 " + symbol)


func test_hands_rows_run_from_strongest_to_weakest_in_the_long_deck():
	var items: Array = _hands()["items"]
	assert_eq(items.size(), PokerRules.LONG_DECK_ORDER.size(), "单列 9 行")
	for i in items.size():
		assert_eq(items[i]["long"], i + 1)
		assert_eq(items[i]["category"], PokerRules.LONG_DECK_ORDER[-1 - i])
		assert_eq(items[i]["name"], PokerRules.CATEGORY_NAMES[items[i]["category"]])


func test_hands_ranks_follow_category_order_in_both_decks():
	for item in _hands()["items"]:
		for short_deck in [false, true]:
			var order := PokerRules.category_order(short_deck)
			var expected := order.size() - order.find(item["category"])   # 名次 1 最大
			assert_eq(item["short" if short_deck else "long"], expected, item["name"])


func test_only_the_flush_full_house_swap_is_highlighted():
	var highlighted := []
	for item in _hands()["items"]:
		assert_eq(item["highlight"], item["long"] != item["short"], item["name"])
		if item["highlight"]:
			highlighted.append(item["category"])
	highlighted.sort()
	assert_eq(highlighted, [PokerRules.Category.FLUSH, PokerRules.Category.FULL_HOUSE])


func test_example_hands_are_what_they_claim_in_both_decks():
	for item in _hands()["items"]:
		var cards: Array = item["cards"]
		assert_eq(cards.size(), HAND_SIZE, item["name"])
		var seen := {}
		for card in cards:
			assert_true(PokerCard.is_card(card), item["name"])
			assert_gte(PokerCard.rank(card), PokerRules.SHORT_DECK_MIN_RANK, "示例牌在短牌里也要有:" + item["name"])
			assert_false(seen.has(card), "示例牌重复:" + item["name"])
			seen[card] = true
		for short_deck in [false, true]:
			assert_eq(_category_of(cards, short_deck), item["category"], item["name"])


func test_every_row_explains_its_category():
	for item in _hands()["items"]:
		assert_ne(item.get("caption", ""), "", item["name"])


func test_hands_note_names_both_lowest_straights_and_the_royal_flush():
	var note: String = _hands()["note"]
	assert_string_contains(note, "A-2-3-4-5")
	assert_string_contains(note, "A-6-7-8-9")
	assert_string_contains(note, PokerRules.ROYAL_FLUSH_NAME)


func test_controls_list_the_poker_hotkeys():
	# 规格 §6.2:F 弃牌、C/空格 过牌跟注、R/回车 下注加注、↑↓ 一个大盲、1–5 预设;WASD 探头;F1 说明书
	var keys := []
	for block in RulebookContent.find("controls", POKER)["blocks"]:
		if block["type"] == "keys":
			for item in block["items"]:
				keys.append_array(item["keys"])
	for key in ["F", "C", "空格", "R", "Enter", "↑", "↓", "1–5", "W", "Esc", OS.get_keycode_string(RulebookContent.HOTKEY)]:
		assert_has(keys, key)


func _hands() -> Dictionary:
	for block in RulebookContent.find("hands", POKER).get("blocks", []):
		if block["type"] == "hands":
			return block
	fail_test("牌型那章没有 hands 块")
	return {"items": [], "note": ""}


func _book_text() -> String:
	return "".join(RulebookContent.sections(POKER).map(_text_of))


func _text_of(value: Variant) -> String:
	# 递归收集章节里的全部文字,用于检查文案中的数字
	match typeof(value):
		TYPE_STRING:
			return value + "\n"
		TYPE_ARRAY:
			return "".join(value.map(_text_of))
		TYPE_DICTIONARY:
			return "".join(value.values().map(_text_of))
	return ""


func _category_of(cards: Array, short_deck: bool) -> int:
	# 五张牌的牌型(只为核对示例,独立于规则引擎):按点数分组 + 同花 + 顺子(含 A 当最小牌)
	var counts := {}
	for card in cards:
		counts[PokerCard.rank(card)] = counts.get(PokerCard.rank(card), 0) + 1
	var groups: Array = counts.values()
	groups.sort()
	groups.reverse()
	var flush := cards.all(func(card): return PokerCard.suit(card) == PokerCard.suit(cards[0]))
	var straight := _is_straight(counts.keys(), short_deck)
	if straight and flush:
		return PokerRules.Category.STRAIGHT_FLUSH
	if groups[0] == 4:
		return PokerRules.Category.FOUR_OF_A_KIND
	if groups == [3, 2]:
		return PokerRules.Category.FULL_HOUSE
	if flush:
		return PokerRules.Category.FLUSH
	if straight:
		return PokerRules.Category.STRAIGHT
	if groups[0] == 3:
		return PokerRules.Category.THREE_OF_A_KIND
	if groups == [2, 2, 1]:
		return PokerRules.Category.TWO_PAIR
	return PokerRules.Category.ONE_PAIR if groups[0] == 2 else PokerRules.Category.HIGH_CARD


func _is_straight(ranks: Array, short_deck: bool) -> bool:
	if ranks.size() != HAND_SIZE:
		return false
	var sorted := ranks.duplicate()
	sorted.sort()
	if sorted[-1] - sorted[0] == HAND_SIZE - 1:
		return true
	var low := PokerRules.min_rank(short_deck)
	return sorted == [low, low + 1, low + 2, low + 3, PokerCard.ACE]
