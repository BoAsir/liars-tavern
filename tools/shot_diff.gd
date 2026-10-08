extends SceneTree
# 前后截图对比:两个目录里同名 PNG 逐张算差异比例(任一通道差超过容差的像素占比)。
# 用法:godot --headless --path . -s tools/shot_diff.gd -- --a=<目录> --b=<目录> [--tolerance=0.04] [--max=0.005]
# 任一张差异超过 --max(默认 0.5%)或缺图时退出码为 1。截图时加引擎参数 --fixed-fps 60 才可比。

const ImageStats := preload("res://tools/image_stats.gd")


func _initialize() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var tolerance := float(opts.get("tolerance", str(10.0 / 255.0)))
	var limit := float(opts.get("max", "0.005"))
	var failed := false
	for file in DirAccess.get_files_at(opts["a"]):
		if not file.ends_with(".png"):
			continue
		var a := Image.load_from_file("%s/%s" % [opts["a"], file])
		var b_path := "%s/%s" % [opts["b"], file]
		if not FileAccess.file_exists(b_path):
			print("MISSING ", b_path)
			failed = true
			continue
		var ratio := ImageStats.diff_ratio(a, Image.load_from_file(b_path), tolerance)
		var over := ratio > limit
		failed = failed or over
		print("%-16s diff %.4f%s" % [file, ratio, "  <-- 超出" if over else ""])
	quit(1 if failed else 0)
