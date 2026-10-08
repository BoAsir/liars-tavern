class_name RoomTextures
# 房间的两张运行时贴图(墙地噪声 SurfaceNoise、墙饰图集 DecorAtlas)一起烘焙与释放。
# 两者都是「同一份 ImageTexture 原地换图」:材质先绑回退图,烘好后自动生效,调用方可以不 await。


static func build(host: Node) -> void:
	# 协程:两张图并行烘焙(协程不 await 就是并行启动,各自等同样的几帧),都好了才返回
	SurfaceNoise.build(host)
	DecorAtlas.build(host)
	while not is_built():
		if not is_instance_valid(host) or not host.is_inside_tree():
			return
		await host.get_tree().process_frame


static func is_built() -> bool:
	return SurfaceNoise.is_built() and DecorAtlas.is_built()


static func clear() -> void:
	SurfaceNoise.clear()
	DecorAtlas.clear()
