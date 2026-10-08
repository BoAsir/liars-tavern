class_name WorldLabels
extends Control
# 3D 锚定的 2D 控件:每帧把控件投影到世界坐标点上方(铭牌、对话气泡)。
# 锚点在相机背后或屏幕外时隐藏。
# 条目里的控件可能已自行释放(气泡淡出后 queue_free):取出时先用无类型变量判有效,
# 已释放的实例赋给 Control 类型变量或作为 Control 返回值本身就是脚本错误。


const EDGE_MARGIN := 4.0   # 控件离屏幕边缘的最小距离

var camera: Camera3D
var _entries := {}   # key -> {"node": Control, "anchor": Callable, "offset": Vector2 或返回 Vector2 的 Callable}


func _init(p_camera: Camera3D) -> void:
	camera = p_camera


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func track(key: String, node: Control, anchor: Callable, offset: Variant = Vector2.ZERO) -> void:
	# offset 可以是每帧现算的 Callable(快捷语气泡叠在铭牌、声称气泡之上,高度跟着它们变)
	untrack(key)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	_entries[key] = {"node": node, "anchor": anchor, "offset": offset}
	_place(node, _entries[key])


func untrack(key: String) -> void:
	if not _entries.has(key):
		return
	var node = _entries[key]["node"]
	_entries.erase(key)
	if is_instance_valid(node):
		node.queue_free()


func anchor_of(key: String) -> Callable:
	# 某个条目的世界锚点(没有时返回空 Callable):快捷语气泡挂在铭牌的同一个锚点上(德州铭牌按座位错开高度)
	if not _entries.has(key) or not is_instance_valid(_entries[key]["node"]):
		return Callable()
	return _entries[key]["anchor"]


func get_node_for(key: String) -> Control:
	if not _entries.has(key):
		return null
	var node = _entries[key]["node"]
	return node if is_instance_valid(node) else null


func clear() -> void:
	for key in _entries.keys():
		untrack(key)


func _process(_delta: float) -> void:
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		var node = entry["node"]
		if not is_instance_valid(node):
			_entries.erase(key)
			continue
		_place(node, entry)


func _place(node: Control, entry: Dictionary) -> void:
	var anchor: Callable = entry["anchor"]
	if not anchor.is_valid() or camera == null or not camera.is_inside_tree():
		node.visible = false
		return
	var world_pos: Vector3 = anchor.call()
	if camera.is_position_behind(world_pos):
		node.visible = false
		return
	var screen := camera.unproject_position(world_pos)
	# unproject 返回视口坐标;换算到本控件所在画布层的本地坐标
	var pos := get_global_transform_with_canvas().affine_inverse() * screen
	node.visible = get_rect().grow(80).has_point(pos)
	var offset: Variant = entry["offset"]
	if offset is Callable:
		offset = offset.call() if offset.is_valid() else Vector2.ZERO
	var top_left: Vector2 = pos - Vector2(node.size.x / 2.0, node.size.y) + offset
	# 贴边时收进屏幕内(画面上缘的对手气泡不被裁掉)
	var limit := (size - node.size - Vector2(EDGE_MARGIN, EDGE_MARGIN)).max(Vector2(EDGE_MARGIN, EDGE_MARGIN))
	node.position = top_left.clamp(Vector2(EDGE_MARGIN, EDGE_MARGIN), limit).round()
