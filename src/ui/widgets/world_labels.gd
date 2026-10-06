class_name WorldLabels
extends Control
# 3D 锚定的 2D 控件:每帧把控件投影到世界坐标点上方(铭牌、对话气泡)。
# 锚点在相机背后或屏幕外时隐藏。


var camera: Camera3D
var _entries := {}   # key -> {"node": Control, "anchor": Callable, "offset": Vector2}


func _init(p_camera: Camera3D) -> void:
	camera = p_camera


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func track(key: String, node: Control, anchor: Callable, offset := Vector2.ZERO) -> void:
	untrack(key)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	_entries[key] = {"node": node, "anchor": anchor, "offset": offset}
	_place(_entries[key])


func untrack(key: String) -> void:
	if _entries.has(key):
		var node: Control = _entries[key]["node"]
		if is_instance_valid(node):
			node.queue_free()
		_entries.erase(key)


func get_node_for(key: String) -> Control:
	return _entries[key]["node"] if _entries.has(key) else null


func clear() -> void:
	for key in _entries.keys():
		untrack(key)


func _process(_delta: float) -> void:
	for key in _entries.keys():
		var entry: Dictionary = _entries[key]
		if not is_instance_valid(entry["node"]):
			_entries.erase(key)
			continue
		_place(entry)


func _place(entry: Dictionary) -> void:
	var node: Control = entry["node"]
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
	node.position = (pos - Vector2(node.size.x / 2.0, node.size.y) + entry["offset"]).round()
