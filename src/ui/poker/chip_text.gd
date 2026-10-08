class_name ChipText
# 筹码数额的文字格式:千分位(「1,240」)与带正负号的盈亏(「+1,240」「-360」)。
# HUD、下注控件、铭牌与结算共用,数字的写法只在这里定。


const GROUP := 3


static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % GROUP == 0 and i > 0:
			out = "," + out
	return ("-" if amount < 0 else "") + out


static func signed(amount: int) -> String:
	# 盈亏:正数带「+」,0 不带号
	if amount > 0:
		return "+" + format(amount)
	return format(amount)
