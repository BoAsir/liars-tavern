extends SceneTree
# 截图对比:逐个比较两个目录里同名的 PNG,打印平均差异与明显变化(任一通道差 > 阈值)的像素占比。
# 用于确认重构没有改变画面,或量化改动影响了画面多大范围。可以 --headless 运行。
# 用法:godot --headless --path . -s tools/image_diff.gd -- --a=<目录> --b=<目录> [--threshold=0.1]


func _initialize() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var threshold := float(opts.get("threshold", "0.1"))
	for file in DirAccess.get_files_at(opts["a"]):
		if not file.ends_with(".png") or not FileAccess.file_exists(opts["b"] + "/" + file):
			continue
		var a := Image.load_from_file(opts["a"] + "/" + file)
		var b := Image.load_from_file(opts["b"] + "/" + file)
		if a.get_size() != b.get_size():
			print("%-16s size differs %s vs %s" % [file, a.get_size(), b.get_size()])
			continue
		var total := 0.0
		var changed := 0
		for y in range(0, a.get_height(), 2):
			for x in range(0, a.get_width(), 2):
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
				total += d
				if d > threshold:
					changed += 1
		var samples := (a.get_width() / 2) * (a.get_height() / 2)
		print("%-16s mean diff %.4f  changed %5.2f%%" % [file, total / samples, 100.0 * changed / samples])
	quit()
