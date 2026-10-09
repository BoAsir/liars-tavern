class_name Quips
# 快捷对话(类似炉石的表情):牌桌上点「对话」或按 T 选一句,说话人头顶冒气泡。三种玩法(骗子酒馆、德州、炸弹猫)共用。
# 网络上只传编号;编号来自不可信对端,先用 is_valid 校验。文案 2026-10-09 经用户审定(不用花色与 emoji 字形)。


const LINES := [
	"你好呀!",
	"打得不错",
	"谢谢",
	"我很抱歉",
	"哇哦!",
	"哎呀……",
	"快点吧,我等到花儿都谢了",
	"给阿姨倒一杯卡布奇诺",
	"17 张牌你能秒我?",
]
# 开关九宫格的键。放在这个纯数据模块里:HUD 引用它时不会把 QuipController 依赖的自动加载单例(Net)拖进来,
# tools/shot.gd(不带自动加载编译)才不报「Identifier not found: Net」
const TOGGLE_KEY := KEY_T
const COOLDOWN := 3.0          # 秒:每人说完一句后多久才能再说(客户端本地;房主另有略宽的限速)
const BUBBLE_SECONDS := 2.5    # 气泡停留多久(不含弹出与淡出)


static func is_valid(index: Variant) -> bool:
	return index is int and index >= 0 and index < LINES.size()


static func text(index: Variant) -> String:
	return LINES[index] if is_valid(index) else ""
