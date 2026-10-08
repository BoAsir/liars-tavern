extends GutTest
# 德州新增的程序化音效(规格 §6.7):chips(筹码碰撞)、chips_push(全下推筹码)、fold(轻推牌)
# 都能合成出非空、不削波的采样,且有音量表项(否则落到默认音量)。


const SfxScript := preload("res://src/ui/sfx.gd")
const POKER_SOUNDS := ["chips", "chips_push", "fold"]

var sfx: Node


func before_each():
	sfx = autofree(SfxScript.new())


func _samples(wav: AudioStreamWAV) -> int:
	return int(wav.data.size() / 2.0)   # 16 位单声道


func test_poker_sounds_have_volume_entries():
	for sound in POKER_SOUNDS:
		assert_true(SfxScript.VOLUMES.has(sound), sound)


func test_poker_sounds_synthesize_non_empty_audio():
	for sound in POKER_SOUNDS:
		var wav: AudioStreamWAV = sfx._synth(sound)
		assert_gt(_samples(wav), int(0.05 * SfxScript.RATE), "%s 至少 50 毫秒" % sound)
		var peak := 0
		for i in range(0, wav.data.size(), 2):
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
		assert_gt(peak, 2000, "%s 不是静音" % sound)
		assert_true(peak <= 32000, "%s 不削波" % sound)


func test_all_in_push_is_longer_than_a_single_chip_clatter():
	assert_gt(_samples(sfx._synth("chips_push")), _samples(sfx._synth("chips")))


func test_fold_is_quieter_than_chips():
	assert_lt(SfxScript.VOLUMES["fold"], SfxScript.VOLUMES["chips"])
