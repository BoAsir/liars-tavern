class_name RenderBudget
# 3D 渲染预算:3D 最多按 MAX_3D_PIXELS 个像素渲染,窗口更大时降内部分辨率再用 FSR 放大,界面仍按原生分辨率绘制。
# 实测(Apple M3,tools/perf_probe.gd):全开特效时帧耗时与像素数成正比,4K 全屏约 55 毫秒/帧(18 fps);
# 内部 1080p + SMAA 后约 10 毫秒。MSAA 2x 在 1080p 下约 2.9 毫秒,换成 SMAA 画质相近、开销更低。


const MAX_3D_PIXELS := 1920 * 1080
const MIN_SCALE := 0.5   # FSR 1 的下限("性能"档),再低画面就糊了


static func scale_for(size: Vector2i) -> float:
	var pixels := float(size.x) * float(size.y)
	if pixels <= MAX_3D_PIXELS:
		return 1.0
	return maxf(sqrt(MAX_3D_PIXELS / pixels), MIN_SCALE)


static func apply(viewport: Viewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	viewport.scaling_3d_scale = scale_for(_pixel_size(viewport))


static func follow(window: Window) -> void:
	# 立即应用,并在窗口尺寸变化(切换全屏、拖到另一块屏幕)时重新计算
	apply(window)
	window.size_changed.connect(func(): apply(window))


static func _pixel_size(viewport: Viewport) -> Vector2i:
	# 3D 渲染目标的实际像素尺寸:Window 用窗口像素尺寸,SubViewport 用自身尺寸
	if viewport is Window:
		return (viewport as Window).size
	return (viewport as SubViewport).size
