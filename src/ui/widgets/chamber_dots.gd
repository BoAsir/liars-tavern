class_name ChamberDots
extends Control
# 六膛弹巢指示:已扣过扳机的膛位画成空心暗格,其余为黄铜实心;出局后整体变红叉。


var fired := 0:
	set(value):
		fired = clampi(value, 0, Revolver.CHAMBERS)
		queue_redraw()
var dead := false:
	set(value):
		dead = value
		queue_redraw()
var dot_radius := 5.0


func _init(p_radius := 5.0) -> void:
	dot_radius = p_radius
	custom_minimum_size = Vector2(dot_radius * 2.6 * Revolver.CHAMBERS, dot_radius * 2.4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var step := dot_radius * 2.6
	var cy := size.y / 2.0
	for i in Revolver.CHAMBERS:
		var center := Vector2(dot_radius * 1.3 + i * step, cy)
		if i < fired:
			draw_circle(center, dot_radius, Color(0, 0, 0, 0.55))
			draw_arc(center, dot_radius, 0, TAU, 20, Color(UiTheme.BRASS, 0.45), 1.2, true)
		else:
			draw_circle(center, dot_radius, UiTheme.BRASS)
			draw_circle(center + Vector2(-dot_radius * 0.3, -dot_radius * 0.3), dot_radius * 0.35, Color(1, 0.95, 0.75, 0.6))
	if dead:
		var w := step * Revolver.CHAMBERS
		draw_line(Vector2(0, cy - dot_radius), Vector2(w, cy + dot_radius), UiTheme.LIE, 2.0, true)
