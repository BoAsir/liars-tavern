extends GutTest
# 牌桌退场只收走自己挂的铭牌/气泡:切屏时新屏幕先 _ready、旧屏幕帧末才 _exit_tree,
# 再来一局回到等待厅时,等待厅刚挂好的 lobby:* 铭牌必须留着。


const TableScreenScript := preload("res://src/ui/table/table_screen.gd")


class StubApp:
	extends Node
	var labels: WorldLabels


var app: StubApp
var screen: Node


func before_each():
	app = StubApp.new()
	add_child_autofree(app)
	app.labels = WorldLabels.new(null)
	app.add_child(app.labels)
	screen = TableScreenScript.new(app)
	screen.names = {1: "房主", 2: "客人"}


func _anchor() -> Vector3:
	return Vector3.ZERO


func test_exit_tree_untracks_only_table_keys():
	app.labels.track("lobby:1", Label.new(), _anchor)
	app.labels.track("lobby:2", Label.new(), _anchor)
	app.labels.track(TableScreenScript.PLATE_KEY % 2, Label.new(), _anchor)
	app.labels.track(TableDirector.BUBBLE_KEY % 2, Label.new(), _anchor)
	screen._exit_tree()
	assert_not_null(app.labels.get_node_for("lobby:1"), "等待厅的铭牌不能被牌桌退场清掉")
	assert_not_null(app.labels.get_node_for("lobby:2"))
	assert_null(app.labels.get_node_for(TableScreenScript.PLATE_KEY % 2))
	assert_null(app.labels.get_node_for(TableDirector.BUBBLE_KEY % 2))
	screen.free()
