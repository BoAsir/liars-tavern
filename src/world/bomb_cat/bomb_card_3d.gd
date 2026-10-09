class_name BombCard3D
extends Card3D
# 炸弹猫的 3D 牌:沿用 Card3D 的圆角薄片网格、飞行 / 翻面 / 高亮 / 射线拾取,
# 材质换成 BombCatFaces 的那一份共享材质(所有炸弹猫的牌共用,不 duplicate),牌型走实例参数 face。
# 牌 id 是字符串(BombCatCard);"" = 牌背(别人的牌、牌堆),两面都是牌背层。不要调用 Card3D.set_kind(那是骗子酒馆 / 德州的牌型)。


var card_id := BombCatFaces.BACK


func _init(id := BombCatFaces.BACK) -> void:
	super()
	_mesh.material_override = BombCatFaces.material()
	set_card(id)


func set_card(id: String) -> void:
	card_id = id if BombCatCard.is_valid(id) else BombCatFaces.BACK
	_mesh.set_instance_shader_parameter("face", BombCatFaces.layer(card_id))


func is_back() -> bool:
	return card_id == BombCatFaces.BACK
