class_name PotBuilder
# 底池的纯函数(规格 §2.4 未跟注退回、§2.5 边池与分池)。金额都是筹码单位的整数倍。


static func build(committed: Dictionary, folded: Dictionary, seat_order: Array) -> Array:
	# committed:{pid: 本手累计投入}(含已弃牌、已离开者);folded:{pid: true} 是不能赢的人(死钱留在池里)。
	# 按没弃牌者的投入额分层,每层的有资格者 = 投入 ≥ 该层且没弃牌的人;相邻两层有资格者相同就合并。
	# → [{"amount", "eligible": [按座位顺序]}],主池在前
	var pids := _in_seat_order(committed.keys(), seat_order)
	var pots := []
	var dead := 0
	var floor_amount := 0
	for level in _levels(committed, folded):
		var amount := 0
		var eligible := []
		for pid in pids:
			amount += clampi(committed[pid] - floor_amount, 0, level - floor_amount)
			if not folded.get(pid, false) and committed[pid] >= level:
				eligible.append(pid)
		floor_amount = level
		if eligible.is_empty():
			# 只有死钱的层:有资格者随层数只减不增,它上面也全是死钱,一起并入下面最近的底池
			if pots.is_empty():
				dead += amount
			else:
				pots.back()["amount"] += amount
		elif not pots.is_empty() and pots.back()["eligible"] == eligible:
			pots.back()["amount"] += amount
		else:
			pots.append({"amount": amount, "eligible": eligible})
	if dead > 0:
		# 没弃牌的人一分都没投(其他人都断线离开了):死钱归他们
		pots.append({"amount": dead, "eligible": pids.filter(func(pid): return not folded.get(pid, false))})
	return pots


static func uncalled(bets: Dictionary) -> Dictionary:
	# 一轮结束时,本轮下注最高者超出第二高下注(含已弃牌、已离开者)的部分退回给他 → {"pid", "amount"} 或 {}
	var top_pid: Variant = null
	var top := 0
	var second := 0
	for pid in bets:
		var amount: int = bets[pid]
		if amount > top:
			second = top
			top = amount
			top_pid = pid
		elif amount > second:
			second = amount
	if top_pid == null or top == second:
		return {}
	return {"pid": top_pid, "amount": top - second}


static func split(amount: int, winners: Array, unit: int) -> Dictionary:
	# 平分:按 unit 为单位分,零头从第一位赢家开始依次多给一个单位(winners 已按按钮之后顺时针排好)
	@warning_ignore("integer_division")
	var units := amount / unit
	@warning_ignore("integer_division")
	var base := units / winners.size()
	var extra := units % winners.size()
	var shares := {}
	for i in winners.size():
		shares[winners[i]] = (base + (1 if i < extra else 0)) * unit
	# 不足一个单位的余数(金额都是单位的倍数,正常不会有)也给第一位,保证筹码守恒
	shares[winners[0]] += amount - units * unit
	return shares


static func _levels(committed: Dictionary, folded: Dictionary) -> Array:
	# 分层的界:各个没弃牌者的投入额;弃牌者投入比所有有资格者都多时,最上面补一层装死钱
	var levels := []
	var top := 0
	for pid in committed:
		var amount: int = committed[pid]
		top = maxi(top, amount)
		if amount > 0 and not folded.get(pid, false) and not levels.has(amount):
			levels.append(amount)
	levels.sort()
	if top > 0 and (levels.is_empty() or levels.back() < top):
		levels.append(top)
	return levels


static func _in_seat_order(pids: Array, seat_order: Array) -> Array:
	var out := []
	for pid in seat_order:
		if pids.has(pid):
			out.append(pid)
	for pid in pids:
		if not out.has(pid):
			out.append(pid)
	return out
