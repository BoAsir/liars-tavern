class_name Species
# 酒客物种目录(纯逻辑,网络层与场景层共用)。下标就是网络上传的值,协议 v5 起冻结:
# 以后加物种只能追加到末尾,而且要升协议版本。外观在 PatronParts / 物种配方里。

const IDS := ["fox", "bear", "pig", "cat", "turtle", "alpaca", "monkey", "crocodile"]
const LABELS := ["狐狸", "熊", "猪", "猫", "乌龟", "羊驼", "猴子", "鳄鱼"]
const UNASSIGNED := -1


static func count() -> int:
	return IDS.size()


static func is_valid(value: Variant) -> bool:
	# 来自网络或设置文件的值不可信:必须是整数且在范围内
	return typeof(value) == TYPE_INT and value >= 0 and value < IDS.size()


static func sanitize(value: Variant) -> int:
	return value if is_valid(value) else UNASSIGNED


static func index_of(id: String) -> int:
	return IDS.find(id)


static func first_free(taken: Array) -> int:
	# 同桌不撞脸:取第一个没人用的;全被占(人数超过物种数)时才轮流重复
	for i in IDS.size():
		if not taken.has(i):
			return i
	return posmod(taken.size(), IDS.size())
