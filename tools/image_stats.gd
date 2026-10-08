extends RefCounted
# 截图统计:削顶比例(过曝)、亮度标准差(墙面是不是一块平板)、两张图的差异比例(只降 draw call、不改外观的批次要求画面不变)。
# tools/ 不进导出包,所以不声明 class_name,用 preload 取用。


static func clipped_ratio(img: Image, rect: Rect2i, threshold := 0.98) -> float:
	# 区域内任一通道 ≥ threshold 的像素占比;区域先裁到图内,完全在图外返回 0
	var area := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if area.get_area() <= 0:
		return 0.0
	var clipped := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := img.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) >= threshold:
				clipped += 1
	return float(clipped) / area.get_area()


static func luma_stddev(img: Image, rect: Rect2i) -> float:
	# 区域内亮度(Rec.709 系数)的标准差,单位 0–255
	var area := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if area.get_area() <= 0:
		return 0.0
	var total := 0.0
	var total_sq := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := img.get_pixel(x, y)
			var luma := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			total += luma
			total_sq += luma * luma
	var n := float(area.get_area())
	var mean := total / n
	return sqrt(maxf(total_sq / n - mean * mean, 0.0))


static func diff_ratio(a: Image, b: Image, tolerance := 10.0 / 255.0) -> float:
	# 任一通道差值超过 tolerance 的像素占比;尺寸不同视为全部不同
	if a.get_size() != b.get_size():
		return 1.0
	var size := a.get_size()
	var differ := 0
	for y in size.y:
		for x in size.x:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > tolerance:
				differ += 1
	return float(differ) / (size.x * size.y)
