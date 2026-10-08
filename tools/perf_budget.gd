extends RefCounted
# 性能预算:按机位列出各项统计的上限(设计文档 §4.1 / §6.5,当前为子项目①完成后的数字),
# 性能探针 --assert-budget 据此核对。tools/ 不进导出包,所以不声明 class_name,用 preload 取用。

const FRAME_MS := 9.7     # M3、1080p、游戏实际渲染配置(RenderBudget)
const CPU_MS := 0.9       # CPU 渲染线程
const MAX_LIGHTS := 16
const OTHER_VIEW_DRAW_CALLS := 800

const LIMITS := {
	"seat": {"draw_calls": 650, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"menu": {"draw_calls": 700, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"opponent": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"closeup": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"gun": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"bar": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"window": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"fireplace": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"overhead": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
	"selfshot": {"draw_calls": OTHER_VIEW_DRAW_CALLS, "frame_ms": FRAME_MS, "cpu_ms": CPU_MS, "lights": MAX_LIGHTS},
}


static func violations(view: String, stats: Dictionary) -> PackedStringArray:
	# 超出的每项一条说明;探针没测到的统计项不算超标,不认识的机位返回空
	var out := PackedStringArray()
	var limits: Dictionary = LIMITS.get(view, {})
	for key in limits:
		if stats.has(key) and stats[key] > limits[key]:
			out.append("%s 机位 %s = %s,超出上限 %s" % [view, key, _fmt(stats[key]), _fmt(limits[key])])
	return out


static func _fmt(value: Variant) -> String:
	return "%.2f" % value if value is float else str(value)
