class_name BombCatCard
# 炸弹猫的牌(规格 §1.2):牌 id 是字符串,网络事件、视图与界面共用。名字与说明全部原创。
# 纯数据,不依赖网络与场景;来自不可信对端的牌 id 先用 is_valid 校验。


const BOMB := "bomb"
const DEFUSE := "defuse"
const SKIP := "skip"
const PASS_TURNS := "pass_turns"
const PEEK := "peek"
const SHUFFLE := "shuffle"
const BEG := "beg"
const NOPE := "nope"
const SNACK_FISH := "snack_fish"
const SNACK_YARN := "snack_yarn"
const SNACK_CARROT := "snack_carrot"
const SNACK_BANANA := "snack_banana"
const SNACK_CACTUS := "snack_cactus"

const SNACKS := [SNACK_FISH, SNACK_YARN, SNACK_CARROT, SNACK_BANANA, SNACK_CACTUS]
# 自己回合里可以单张主动打出的功能牌(不行! 只在反应窗口里打;炸弹、拆弹不能主动打;零食要成对)
const ACTIONS := [SKIP, PASS_TURNS, PEEK, SHUFFLE, BEG]
# 全部牌 id:界面画卡面、说明书列牌按这个顺序
const ALL := [BOMB, DEFUSE, SKIP, PASS_TURNS, PEEK, SHUFFLE, BEG, NOPE,
	SNACK_FISH, SNACK_YARN, SNACK_CARROT, SNACK_BANANA, SNACK_CACTUS]

const _NAMES := {
	BOMB: "炸弹",
	DEFUSE: "拆弹",
	SKIP: "溜了",
	PASS_TURNS: "甩锅",
	PEEK: "偷看",
	SHUFFLE: "洗牌",
	BEG: "讨要",
	NOPE: "不行!",
	SNACK_FISH: "鱼干",
	SNACK_YARN: "毛线球",
	SNACK_CARROT: "胡萝卜",
	SNACK_BANANA: "香蕉",
	SNACK_CACTUS: "仙人掌",
}
const _SNACK_TEXT := "零食:两张一样的抽一张,三张一样的点名要牌"
const _DESCRIPTIONS := {
	BOMB: "摸到它又没有拆弹就炸飞出局,不能主动打出",
	DEFUSE: "摸到炸弹时自动用掉,再把炸弹偷偷塞回牌堆",
	SKIP: "结束本回合,不用摸牌",
	PASS_TURNS: "结束本回合不摸牌,下家要连走两回合",
	PEEK: "偷偷看牌堆顶上的 3 张",
	SHUFFLE: "把牌堆洗乱",
	BEG: "点一位玩家,他自己挑一张牌给你",
	NOPE: "随时打出,取消刚打出的一张牌或一组零食",
	SNACK_FISH: _SNACK_TEXT,
	SNACK_YARN: _SNACK_TEXT,
	SNACK_CARROT: _SNACK_TEXT,
	SNACK_BANANA: _SNACK_TEXT,
	SNACK_CACTUS: _SNACK_TEXT,
}
const UNKNOWN_NAME := "?"


static func is_valid(id: Variant) -> bool:
	return id is String and ALL.has(id)


static func display_name(id: String) -> String:
	return _NAMES.get(id, UNKNOWN_NAME)


static func description(id: String) -> String:
	return _DESCRIPTIONS.get(id, "")


static func is_snack(id: String) -> bool:
	return SNACKS.has(id)


static func is_playable(id: String) -> bool:
	# 能否在自己回合单张主动打出
	return ACTIONS.has(id)


static func needs_target(id: String) -> bool:
	# 单张里只有讨要要选人(零食组合也要选人,见 BombCatState)
	return id == BEG


static func can_be_named(id: Variant) -> bool:
	# 三张零食点名要牌:能出现在手里的牌都能点(炸弹永远不在手里)
	return is_valid(id) and id != BOMB
