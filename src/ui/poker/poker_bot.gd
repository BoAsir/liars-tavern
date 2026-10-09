class_name PokerBot
extends RefCounted
# 德州调试 bot(规格 §8.1):只看公共视图里的合法动作挑一个,经 PokerScreen.submit 走与按钮、快捷键相同的路径。
# choose 是纯函数(两个随机数从外面给),概率表可以单测;act 每次轮到自己时由 DebugFlags 调用一次。

const CHECK_CHANCE := 0.55        # 能免费过牌时:过牌 55% / 下注(最小或 ½ 池)35% / 全下 10%
const BET_CHANCE := 0.35
const FOLD_CHANCE := 0.15         # 要跟注时:弃牌 15% / 跟注 60% / 加注预设 15% / 全下 10%
const CALL_CHANCE := 0.60
const RAISE_CHANCE := 0.15
const BET_PRESETS := [0, 1]       # 下注只用「最小」「½ 池」
const RAISE_PRESETS := [0, 1, 2, 3]   # 加注用前 4 个预设(全下另算)


static func choose(legal: Dictionary, presets: Array, roll: float, pick: float) -> Dictionary:
	# roll 选动作类别,pick 选预设;不能加注 / 全下时退回过牌或跟注(这样永远是一个合法的下注动作)
	if legal.is_empty():
		return {}
	var can_check: bool = legal.get("can_check", false)
	var passive := PokerRules.CHECK if can_check else PokerRules.CALL
	if not can_check and roll < FOLD_CHANCE:
		return _pick(PokerRules.FOLD)
	var passive_until := CHECK_CHANCE if can_check else FOLD_CHANCE + CALL_CHANCE
	var raise_until := passive_until + (BET_CHANCE if can_check else RAISE_CHANCE)
	if roll < passive_until:
		return _pick(passive)
	if roll < raise_until:
		if not legal.get("can_raise", false):
			return _pick(passive)
		var choices: Array = BET_PRESETS if can_check else RAISE_PRESETS
		return _pick(PokerRules.RAISE, _preset(presets, choices, pick, legal))
	return _pick(PokerRules.ALLIN if legal.get("can_allin", false) else passive)


static func _preset(presets: Array, choices: Array, pick: float, legal: Dictionary) -> int:
	var index: int = choices[mini(floori(pick * choices.size()), choices.size() - 1)]
	if index < presets.size() and presets[index] is int:
		return presets[index]
	return legal.get("min_raise_to", PokerRules.BIG_BLIND)


static func _pick(action: String, amount := 0) -> Dictionary:
	return {"action": action, "amount": amount}


static func act(screen: Node) -> bool:
	# 轮到自己:按视图算预设(与下注控件同一公式)再挑动作
	var legal: Dictionary = screen.legal()
	var presets := BetControls.preset_amounts(BetControls.situation(screen.state.pub, screen.my_pid))
	var choice := choose(legal, presets, randf(), randf())
	return not choice.is_empty() and screen.submit(choice["action"], choice["amount"])
