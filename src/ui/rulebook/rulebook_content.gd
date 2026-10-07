class_name RulebookContent
# 说明书内容:按章节组织的纯数据,由 Rulebook 渲染。
# 文案中的数字全部取自规则常量(牌堆、手牌、出牌张数、左轮、限时),规则改动时说明书自动跟随。
# 块类型:lead 引言 / text 正文 / bullets 要点 / note 提示条 / cards 牌堆 / pair 二选一对照 /
#        odds 左轮中弹概率 / keys 操作键位。pair 的 tone 取 brass / truth / lie。


const BLOCK_TYPES := ["lead", "text", "bullets", "note", "cards", "pair", "odds", "keys"]
# 翻开说明书的快捷键。放在纯数据模块里,HUD 等引用它时不会把 Rulebook 依赖的自动加载单例拖进来
const HOTKEY := KEY_F1


static func sections() -> Array[Dictionary]:
	return [_goal(), _deck(), _turn(), _reveal(), _revolver(), _rounds(), _controls()]


static func find(section_id: String) -> Dictionary:
	for section in sections():
		if section["id"] == section_id:
			return section
	return {}


static func hit_chance(shots_fired: int) -> float:
	# 已空响 shots_fired 次后,下一枪中弹的概率
	return 1.0 / maxi(Revolver.CHAMBERS - shots_fired, 1)


# —— 章节 ——

static func _goal() -> Dictionary:
	return {
		"id": "goal",
		"title": "怎么赢",
		"tagline": "活到最后的人赢",
		"blocks": [
			{"type": "lead", "text": "轮流把牌盖着打出,声称它们全是本局的目标牌——可以说真话,也可以吹牛。"},
			{"type": "text", "text": "%d–%d 人围坐一桌。下家不信你,就翻牌验证:你说谎被抓,你对自己扣一次左轮扳机;冤枉了你,扣扳机的就是他。"
				% [Protocol.MIN_PLAYERS, Protocol.MAX_PLAYERS]},
			{"type": "bullets", "items": [
				"中弹即出局,最后一个活着的人获胜。",
				"每次开枪后重新洗牌发牌,开始新的一局。",
				"左轮整场只装一发子弹:扣得越多,下一枪越危险。",
			]},
		],
	}


static func _deck() -> Dictionary:
	var items := []
	for kind in Deck.COMPOSITION:
		items.append({
			"kind": kind,
			"count": Deck.COMPOSITION[kind],
			"caption": "万能牌" if kind == Card.JOKER else "",
		})
	return {
		"id": "deck",
		"title": "牌堆",
		"tagline": "%d 张牌,一个目标" % Deck.build().size(),
		"blocks": [
			{"type": "cards", "items": items},
			{"type": "text", "text": "牌堆共 %d 张。每局开始时洗牌,给每位存活玩家发 %d 张。"
				% [Deck.build().size(), Deck.HAND_SIZE]},
			{"type": "bullets", "items": [
				"每局从 %s 中随机抽一种作为目标牌,立在桌心,也显示在屏幕左上角。" % _target_names(),
				"鬼牌是万能牌:翻牌验证时视同任何目标牌。",
			]},
			{"type": "note", "text": "手牌只有你自己看得见,别人只知道你还剩几张。"},
		],
	}


static func _turn() -> Dictionary:
	return {
		"id": "turn",
		"title": "轮到你时",
		"tagline": "出牌,或者质疑",
		"blocks": [
			{"type": "lead", "text": "轮到你时,二选一:"},
			{"type": "pair", "items": [
				{"title": "出牌", "tone": "brass",
					"body": "选 %d–%d 张手牌盖着打出,等于宣称「这些全是目标牌」。牌可以是真的,也可以是假的。"
						% [Rules.MIN_PLAY, Rules.MAX_PLAY]},
				{"title": "质疑!", "tone": "lie",
					"body": "只能翻上家刚打出的那一组,不信就当场验证。每局的第一手没有牌可质疑,只能出牌。"},
			]},
			{"type": "bullets", "items": [
				"出牌后轮到下一位还有手牌的玩家;手牌打光的人本局不再行动。",
				"每回合限时 %d 秒,超时会自动替你打出第一张手牌。" % int(Protocol.TURN_TIMEOUT),
			]},
			{"type": "note", "text": "不是你的回合时也可以先点选手牌,轮到你时直接出牌。"},
		],
	}


static func _reveal() -> Dictionary:
	return {
		"id": "reveal",
		"title": "翻牌验证",
		"tagline": "谁说谎,谁扣扳机",
		"blocks": [
			{"type": "lead", "text": "质疑时当众翻开上家那组牌:"},
			{"type": "pair", "items": [
				{"title": "真话", "tone": "truth",
					"body": "翻开的牌全是目标牌或鬼牌。", "result": "质疑者扣扳机"},
				{"title": "假话", "tone": "lie",
					"body": "只要有一张不是目标牌。", "result": "出牌者扣扳机"},
			]},
			{"type": "note", "text": "鬼牌也算目标牌:一组牌里混着鬼牌,甚至全是鬼牌,都是真话。"},
		],
	}


static func _revolver() -> Dictionary:
	var odds := []
	for fired in Revolver.CHAMBERS:
		odds.append({"shot": fired + 1, "chance": hit_chance(fired)})
	return {
		"id": "revolver",
		"title": "左轮",
		"tagline": "越往后越危险",
		"blocks": [
			{"type": "text", "text": "每人面前一把 %d 膛左轮,整场只装一发子弹,膛位随机。每次空响,弹巢就转到下一格;子弹不会重装,扣过的次数会一直带到终局:"
				% Revolver.CHAMBERS},
			{"type": "odds", "items": odds},
			{"type": "bullets", "items": ["中弹即出局;空响则活下来,继续游戏。"]},
			{"type": "note", "text": "屏幕左下角是你的弹巢:暗掉的圆点是已经空响过的膛位。"},
		],
	}


static func _rounds() -> Dictionary:
	return {
		"id": "rounds",
		"title": "新一局与特殊情况",
		"tagline": "开枪之后",
		"blocks": [
			{"type": "lead", "text": "每次翻牌之后,不论有没有人中弹,都会收走所有牌、抽新的目标牌,开始新的一局。"},
			{"type": "bullets", "items": [
				"新一局由刚才扣扳机的人先出牌;他若中弹出局,由他的下家先出。",
				"只剩一个人还有手牌时,他打出的牌会被系统强制翻开验证:说谎由他扣扳机;说真话则无人开枪,直接开新一局。",
				"中途离开牌桌或断线视为出局;房主离开则整桌解散。",
				"出局后可以留在桌边观战到终局。",
			]},
			{"type": "note", "text": "对局结束后,房主可以带所有人回等待厅,再来一局。"},
		],
	}


static func _controls() -> Dictionary:
	return {
		"id": "controls",
		"title": "操作",
		"tagline": "鼠标与快捷键",
		"blocks": [
			{"type": "keys", "items": [
				{"action": "选牌(最多 %d 张)" % Rules.MAX_PLAY, "mouse": "点击手牌",
					"keys": ["1–%d" % Deck.HAND_SIZE]},
				{"action": "出牌", "mouse": "「出牌」按钮", "keys": ["Enter"]},
				{"action": "质疑上家", "mouse": "「质疑!」按钮", "keys": ["C", "空格"]},
				{"action": "转头张望", "mouse": "移动鼠标", "keys": []},
				{"action": "伸长脖子探头(松开弹回)", "mouse": "", "keys": ["W", "A", "S", "D"]},
				{"action": "翻开说明书", "mouse": "「规则」按钮", "keys": [OS.get_keycode_string(HOTKEY)]},
				{"action": "说明书翻页", "mouse": "左侧目录", "keys": ["←", "→"]},
				{"action": "离开 / 合上", "mouse": "", "keys": ["Esc"]},
			]},
			{"type": "note", "text": "看说明书时对局不会暂停,回合计时照常进行;轮到你时屏幕上方会有提示。"},
		],
	}


static func _target_names() -> String:
	return " / ".join(Deck.TARGETS.map(func(kind): return Card.NAMES[kind]))
