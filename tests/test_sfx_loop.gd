extends GutTest
# Sfx 环境音循环:首尾交叉淡化后截掉末尾,循环点无跳变。


const SfxScript := preload("res://src/ui/sfx.gd")


func _ramp(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		out.append(float(i))
	return out


func test_loop_drops_the_crossfaded_tail():
	assert_eq(SfxScript.seamless_loop(_ramp(100), 10).size(), 90)


func test_loop_point_continues_where_the_tail_left_off():
	var loop := SfxScript.seamless_loop(_ramp(100), 10)
	# 播完最后一个采样(原第 89 个)跳回开头:开头正是原本紧接着的第 90 个采样
	assert_eq(loop[loop.size() - 1], 89.0)
	assert_eq(loop[0], 90.0)


func test_head_blends_tail_into_original():
	var loop := SfxScript.seamless_loop(_ramp(100), 10)
	assert_almost_eq(loop[5], 5.0 * 0.5 + 95.0 * 0.5, 0.0001)
	assert_eq(loop[10], 10.0)


func test_input_is_left_untouched():
	var samples := _ramp(20)
	SfxScript.seamless_loop(samples, 4)
	assert_eq(samples.size(), 20)
	assert_eq(samples[0], 0.0)


func test_oversized_fade_is_clamped():
	assert_eq(SfxScript.seamless_loop(_ramp(10), 50).size(), 5)


func test_ambience_stream_loops_over_all_of_its_data():
	var sfx: Node = autofree(SfxScript.new())
	var wav: AudioStreamWAV = sfx._synth("ambience")
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(wav.loop_end, int(wav.data.size() / 2.0), "16 位单声道:每个采样 2 字节")
