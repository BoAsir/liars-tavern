extends GutTest
# ImageStats:截图统计——削顶比例(过曝)、亮度标准差(墙面是否平板)、两张图的差异比例(只降 draw call 的批次要求画面不变)。

const ImageStats := preload("res://tools/image_stats.gd")


func _image(color: Color, size := Vector2i(10, 10)) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


func test_clipped_ratio_counts_pixels_with_a_saturated_channel():
	var img := _image(Color(0.5, 0.5, 0.5))
	for x in 5:
		img.set_pixel(x, 0, Color(1.0, 0.6, 0.6))   # 一个通道顶满也算削顶
	assert_almost_eq(ImageStats.clipped_ratio(img, Rect2i(0, 0, 10, 10)), 0.05, 0.0001)
	assert_almost_eq(ImageStats.clipped_ratio(img, Rect2i(0, 0, 10, 1)), 0.5, 0.0001)


func test_clipped_ratio_clamps_rect_to_image():
	var img := _image(Color.WHITE)
	assert_almost_eq(ImageStats.clipped_ratio(img, Rect2i(-5, -5, 100, 100)), 1.0, 0.0001)
	assert_eq(ImageStats.clipped_ratio(img, Rect2i(50, 50, 4, 4)), 0.0, "完全在图外")


func test_luma_stddev_is_zero_for_flat_and_in_0_255_units():
	assert_almost_eq(ImageStats.luma_stddev(_image(Color(0.3, 0.3, 0.3)), Rect2i(0, 0, 10, 10)), 0.0, 0.01)
	var img := _image(Color.BLACK, Vector2i(2, 1))
	img.set_pixel(1, 0, Color.WHITE)
	# 一半全黑一半全白:亮度 0 与 255,标准差 127.5
	assert_almost_eq(ImageStats.luma_stddev(img, Rect2i(0, 0, 2, 1)), 127.5, 0.5)


func test_diff_ratio_counts_pixels_beyond_tolerance():
	var a := _image(Color(0.5, 0.5, 0.5))
	var b := a.duplicate()
	b.set_pixel(0, 0, Color(0.5, 0.5, 0.52))   # 差 5/255,在容差内
	b.set_pixel(1, 0, Color(0.5, 0.7, 0.5))    # 明显不同
	assert_almost_eq(ImageStats.diff_ratio(a, b), 0.01, 0.0001)


func test_diff_ratio_of_different_sizes_is_total():
	assert_eq(ImageStats.diff_ratio(_image(Color.RED), _image(Color.RED, Vector2i(5, 5))), 1.0)
