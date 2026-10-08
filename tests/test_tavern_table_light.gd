extends GutTest
# 德州牌桌的灯光补丁(规格 §5.1、§9,在 Tavern 的接口桩里;合并时以模型重做分支为准):
# - 桌子放大时吊灯聚光放宽,桌面高度照到桌沿外约 0.15 米(1.45 米的桌子约 54°–58°);骗子酒馆桌保持原样;
# - 藏起烛台时留一盏暖色补光照桌沿与酒客的脸,复原时收起;反复调用不叠灯。


const EDGE_REACH := 0.15
const POKER_SPOT_RANGE := Vector2(54.0, 58.0)
const LIARS_SPOT_ANGLE := 52.0

var tavern: Tavern


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)


func _lamp_spot() -> SpotLight3D:
	for light in tavern.find_children("*", "SpotLight3D", true, false):
		if light.get_parent().name == "LampPivot":
			return light
	return null


func _reach_at_table_top(spot: SpotLight3D) -> float:
	# 聚光锥在桌面高度的半径(吊灯静止时)
	var drop := spot.global_position.y - SeatLayout.TABLE_TOP
	return drop * tan(deg_to_rad(spot.spot_angle))


func _rim_lights() -> Array:
	return tavern.find_children("TableRimLight", "OmniLight3D", true, false)


func test_liars_table_keeps_the_original_spot():
	tavern.set_table_radius(SeatLayout.TABLE_RADIUS)
	assert_almost_eq(_lamp_spot().spot_angle, LIARS_SPOT_ANGLE, 0.001)


func test_poker_table_widens_the_spot_past_the_table_edge():
	tavern.set_table_radius(SeatLayout.POKER_TABLE_RADIUS)
	var spot := _lamp_spot()
	assert_between(spot.spot_angle, POKER_SPOT_RANGE.x, POKER_SPOT_RANGE.y)
	assert_gte(_reach_at_table_top(spot), SeatLayout.POKER_TABLE_RADIUS + EDGE_REACH)
	tavern.set_table_radius(SeatLayout.TABLE_RADIUS)
	assert_almost_eq(spot.spot_angle, LIARS_SPOT_ANGLE, 0.001, "回到骗子酒馆桌时复原")


func test_hidden_candles_leave_a_warm_rim_light():
	assert_eq(_rim_lights().size(), 0, "骗子酒馆桌有烛台,不加灯")
	tavern.set_table_decor_visible(false)
	tavern.set_table_decor_visible(false)
	var rims := _rim_lights()
	assert_eq(rims.size(), 1, "反复调用不叠灯")
	var rim: OmniLight3D = rims[0]
	assert_true(rim.visible)
	assert_gt(rim.light_energy, 0.0)
	assert_gt(rim.light_color.r, rim.light_color.b, "暖色")
	assert_false(rim.shadow_enabled, "不投影:省一张阴影贴图")
	assert_gt(rim.omni_range, SeatLayout.seat_radius_for(SeatLayout.POKER_TABLE_RADIUS), "照得到 8 人桌的酒客")
	tavern.set_table_decor_visible(true)
	assert_false(rim.visible, "烛台回来了就收起")
