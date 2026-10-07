class_name Revolver
# 五膛左轮:整局装 1 发子弹于随机膛位,空枪后弹巢前进,第 5 枪必中。


const CHAMBERS := 5

var bullet_chamber: int
var next_chamber := 1


func _init(rng: RandomNumberGenerator) -> void:
	bullet_chamber = rng.randi_range(1, CHAMBERS)


func pull_trigger() -> bool:
	var hit := next_chamber == bullet_chamber
	next_chamber += 1
	return hit


func shots_fired() -> int:
	return next_chamber - 1
