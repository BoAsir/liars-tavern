extends GutTest
# WorldLabels 的条目可能指向已释放的控件(对话气泡淡出后自行释放),查找/替换/清理都不能报错。


var labels: WorldLabels


func before_each():
	labels = WorldLabels.new(null)
	add_child_autofree(labels)


func _anchor() -> Vector3:
	return Vector3.ZERO


func test_retracking_a_key_after_its_node_freed_itself():
	# 气泡已自行释放、_process 还没清掉旧条目时,同一个人又说了一句话
	var first := Label.new()
	labels.track("bubble:2", first, _anchor)
	first.free()
	var second := Label.new()
	labels.track("bubble:2", second, _anchor)
	assert_eq(labels.get_node_for("bubble:2"), second)


func test_lookup_of_a_freed_node_returns_null():
	var node := Label.new()
	labels.track("plate:3", node, _anchor)
	node.free()
	assert_null(labels.get_node_for("plate:3"))


func test_untrack_and_clear_skip_freed_nodes():
	var gone := Label.new()
	var kept := Label.new()
	labels.track("bubble:2", gone, _anchor)
	labels.track("plate:2", kept, _anchor)
	gone.free()
	labels.untrack("bubble:2")
	assert_null(labels.get_node_for("bubble:2"))
	labels.clear()
	assert_null(labels.get_node_for("plate:2"))
	assert_true(kept.is_queued_for_deletion())


func test_process_drops_entries_whose_node_is_gone():
	var node := Label.new()
	labels.track("bubble:4", node, _anchor)
	node.free()
	labels._process(0.016)
	assert_false(labels._entries.has("bubble:4"))


func test_untrack_leaves_other_screens_keys_alone():
	# 牌桌退场只收自己的铭牌,不能连带等待厅刚挂好的铭牌
	var lobby_plate := Label.new()
	var table_plate := Label.new()
	labels.track("lobby:1", lobby_plate, _anchor)
	labels.track("plate:1", table_plate, _anchor)
	labels.untrack("plate:1")
	assert_eq(labels.get_node_for("lobby:1"), lobby_plate)
	assert_null(labels.get_node_for("plate:1"))
