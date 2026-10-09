class_name RulebookBombCat
# 说明书的炸弹猫那本:按章节组织的纯数据,由 Rulebook 渲染,块类型见 RulebookContent。
# 牌名与一行说明取 BombCatCard.display_name / description,张数取 BombCatDeck,秒数取 BombCatState 与 Protocol.TURN_TIMEOUT:
# 规则改动时说明书自动跟随。卡名与文案全部原创。


const TIERS := [[2, 3], [4, 5], [6, 6]]   # 配牌表的三列(人数范围),同 BombCatDeck.tier


static func sections() -> Array[Dictionary]:
	return [_goal(), _turn(), _cards(), _nope(), _bomb(), _snacks(), _setup(), _controls()]


static func count_text(id: String) -> String:
	# 每种牌的张数说明:炸弹 n − 1、拆弹每人 1 张加牌堆里的;功能牌与零食按 2–3 / 4–5 / 6 人三档
	match id:
		BombCatCard.BOMB:
			return "人数 − 1 张"
		BombCatCard.DEFUSE:
			return "每人 1 张,牌堆里再放 %d 张(5 人以上 %d 张)" % [BombCatDeck.defuse_total(2) - 2, BombCatDeck.defuse_total(5) - 5]
	var parts := []
	for tier in TIERS:
		var n: int = tier[0]
		var label := "%d 人" % n if tier[0] == tier[1] else "%d–%d 人" % tier
		parts.append("%s %d" % [label, BombCatDeck.action_counts(n).get(id, 0)])
	return " · ".join(parts)


static func cards_block() -> Dictionary:
	var items := []
	for id in BombCatCard.ALL:
		items.append({"id": id, "name": BombCatCard.display_name(id), "count": count_text(id), "text": BombCatCard.description(id)})
	return {"type": "bomb_cards", "items": items}


# —— 章节 ——

static func _goal() -> Dictionary:
	return {
		"id": "goal",
		"title": "怎么赢",
		"tagline": "别被炸飞",
		"blocks": [
			{"type": "lead", "text": "牌堆里藏着几颗炸弹。大家轮流行动,每回合最后都要摸一张牌——摸到炸弹又没有「拆弹」,就被炸飞出局。"},
			{"type": "text", "text": "%d–%d 人围坐一桌。最后一个没被炸飞的人获胜。" % [GameMode.min_players(GameMode.BOMB_CAT),
				GameMode.max_players(GameMode.BOMB_CAT)]},
			{"type": "bullets", "items": [
				"炸弹数 = 人数 − 1:总会剩下一个人。",
				"开局每人 %d 张牌,外加 1 张「拆弹」。手牌只有自己看得见,别人只知道你还有几张。" % BombCatDeck.HAND_SIZE,
				"左上角随时显示牌堆还剩几张、场上还剩几颗炸弹。",
			]},
			{"type": "note", "text": "一局分出胜负就结算,房主可以带大家回等待厅再来一局。开打后不能中途加入。"},
		],
	}


static func _turn() -> Dictionary:
	return {
		"id": "turn",
		"title": "轮到你时",
		"tagline": "先出牌,最后摸一张",
		"blocks": [
			{"type": "lead", "text": "轮到你时,可以先打出任意张功能牌(一张不出也行),最后从牌堆顶摸一张结束回合。"},
			{"type": "pair", "items": [
				{"title": "出牌", "tone": "brass",
					"body": "选一张功能牌,或两三张一样的零食,按「出牌」。别人有 %d 秒可以「不行!」你。" % int(BombCatState.REACT_WINDOW)},
				{"title": "摸牌", "tone": "lie",
					"body": "从牌堆顶摸一张,回合结束。摸到炸弹就看你手里有没有「拆弹」了。"},
			]},
			{"type": "bullets", "items": [
				"「溜了」「甩锅」可以不摸牌就结束回合。",
				"被甩锅的人要连走两回合:每回合都要摸一张(或用溜了 / 甩锅抵掉)。",
				"每回合限时 %d 秒,超时会自动替你摸一张牌。" % int(Protocol.TURN_TIMEOUT),
			]},
			{"type": "note", "text": "不是你的回合时也可以先点选手牌,轮到你时直接出。"},
		],
	}


static func _cards() -> Dictionary:
	return {
		"id": "cards",
		"title": "所有的牌",
		"tagline": "%d 种牌" % BombCatCard.ALL.size(),
		"blocks": [
			cards_block(),
			{"type": "note", "text": "张数按人数分三档(2–3 人 / 4–5 人 / 6 人)。零食五种:鱼干、毛线球、胡萝卜、香蕉、仙人掌,单张没用,要凑对。"},
		],
	}


static func _nope() -> Dictionary:
	return {
		"id": "nope",
		"title": "不行!",
		"tagline": "谁都能拍桌",
		"blocks": [
			{"type": "lead", "text": "有人打出功能牌或零食组合后,有 %d 秒的反应窗口:所有还活着的人(包括出牌的人自己)都可以打「不行!」。"
				% int(BombCatState.REACT_WINDOW)},
			{"type": "bullets", "items": [
				"每打一张「不行!」,窗口重新计时 %d 秒。" % int(BombCatState.REACT_WINDOW),
				"可以「不行」掉别人的「不行!」:窗口结束时数一数,张数是单数原牌作废,双数照样生效。",
				"炸弹和拆弹不能被「不行!」。",
				"窗口期间出牌的人要等着,回合计时暂停,窗口结束后接着走。",
			]},
			{"type": "note", "text": "反应窗口里屏幕下方会出现红色倒计时条和大大的「不行!」按钮(快捷键 N)。手里有「不行!」才按得动。"},
		],
	}


static func _bomb() -> Dictionary:
	return {
		"id": "bomb",
		"title": "炸弹与拆弹",
		"tagline": "咔嚓,还是轰",
		"blocks": [
			{"type": "pair", "items": [
				{"title": "有拆弹", "tone": "truth",
					"body": "自动用掉一张「拆弹」,然后把炸弹偷偷塞回牌堆任意位置(别人看不到你塞在哪)。",
					"result": "活下来,回合结束"},
				{"title": "没拆弹", "tone": "lie",
					"body": "轰!被炸飞出局,手牌全部弃掉,这颗炸弹也不再回到牌堆。",
					"result": "出局,留在桌边观战"},
			]},
			{"type": "bullets", "items": [
				"塞回炸弹时拖动滑块选位置:最左是牌堆最上面(下一个摸牌的人就会摸到),最右是最底下。限时 %d 秒,超时随机塞。"
					% int(BombCatState.REINSERT_TIMEOUT),
				"出局的人仍然可以丢番茄、说快捷语。",
				"中途离开牌桌或断线视为出局;房主离开则整桌解散。",
			]},
		],
	}


static func _snacks() -> Dictionary:
	return {
		"id": "snacks",
		"title": "讨要与零食",
		"tagline": "从别人手里拿牌",
		"blocks": [
			{"type": "bullets", "items": [
				"「讨要」:选一个人,他自己挑一张牌给你。他有 %d 秒,超时随机给一张。" % int(BombCatState.GIVE_TIMEOUT),
				"两张一样的零食:选一个人,从他手里随机抽一张。",
				"三张一样的零食:选一个人、点名一种牌(炸弹除外),他有就必须给你一张,没有就落空。",
				"只能选还在场、手里有牌的人;出牌后在桌边点他的酒客,或从弹出的名单里选。",
			]},
			{"type": "note", "text": "拿牌的过程只有你们两个看得到是哪张牌,别人只看到一张牌背飞过去。"},
		],
	}


static func _setup() -> Dictionary:
	var items := []
	for tier in TIERS:
		var n: int = tier[1]
		var label := "%d 人" % n if tier[0] == tier[1] else "%d–%d 人" % tier
		items.append("%s:整副 %s 张,炸弹 %s 颗,拆弹 %s 张。" % [label, _range_text(tier, BombCatDeck.total_cards),
			_range_text(tier, BombCatDeck.bomb_count), _range_text(tier, BombCatDeck.defuse_total)])
	return {
		"id": "setup",
		"title": "配牌",
		"tagline": "按人数",
		"blocks": [
			{"type": "lead", "text": "先拿掉炸弹和拆弹洗匀,每人发 %d 张,再每人发 1 张拆弹;剩下的拆弹和炸弹混回牌堆再洗一次。"
				% BombCatDeck.HAND_SIZE},
			{"type": "bullets", "items": items},
		],
	}


static func _controls() -> Dictionary:
	return {
		"id": "controls",
		"title": "操作",
		"tagline": "鼠标与快捷键",
		"blocks": [
			{"type": "keys", "items": [
				{"action": "选牌(零食可以选两三张一样的)", "mouse": "点击下方手牌", "keys": ["1–9"]},
				{"action": "出牌", "mouse": "「出牌」按钮", "keys": ["Enter"]},
				{"action": "摸牌(结束回合)", "mouse": "「摸牌」按钮", "keys": ["空格"]},
				{"action": "不行!(反应窗口里)", "mouse": "「不行!」按钮", "keys": ["N"]},
				{"action": "选目标", "mouse": "点桌边的酒客 / 名单", "keys": []},
				{"action": "塞回炸弹:微调 / 确认", "mouse": "拖动滑块", "keys": ["←", "→", "Enter"]},
				{"action": "被讨要时给牌", "mouse": "点一张手牌", "keys": ["1–9"]},
				{"action": "转头张望", "mouse": "移动鼠标", "keys": []},
				{"action": "探头 / 缩回(脖子自动伸缩)", "mouse": "", "keys": ["W", "A", "S", "D"]},
				{"action": "切换视角(越肩 / 第一人称)", "mouse": "", "keys": ["V"]},
				RulebookContent.BANTER_KEYS[0],
				RulebookContent.BANTER_KEYS[1],
				RulebookContent.BANTER_KEYS[2],
				{"action": "翻开说明书", "mouse": "「规则」按钮", "keys": [OS.get_keycode_string(RulebookContent.HOTKEY)]},
				{"action": "说明书翻页", "mouse": "左侧目录", "keys": ["←", "→"]},
				{"action": "取消选目标 / 离开牌桌", "mouse": "", "keys": ["Esc"]},
			]},
			{"type": "note", "text": "看说明书时对局不会暂停,计时照常进行。快捷语面板开着时数字键只用来说话,不会选牌。"},
			{"type": "note", "text": RulebookContent.BANTER_NOTE},
			{"type": "note", "text": RulebookContent.SPECIES_NOTE},
		],
	}


static func _range_text(tier: Array, fn: Callable) -> String:
	var low: int = fn.call(tier[0])
	var high: int = fn.call(tier[1])
	return str(low) if low == high else "%d–%d" % [low, high]
