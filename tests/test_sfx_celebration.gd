extends GutTest
# 结算庆祝的程序化音效(规格 2026-10-09-winner-celebration):礼炮「砰」+ 纸屑、开场小号、掌声都能合成出非空、
# 几乎不削波、结尾收干净的采样,且有音量表项;掌声比礼炮轻。


const SfxScript := preload("res://src/ui/sfx.gd")
# 音效 -> [最短秒数, 最长秒数]
const SOUNDS := {"cannon_pop": [0.5, 1.2], "fanfare": [1.0, 2.0], "applause": [2.0, 3.5]}

var sfx: Node


func before_each():
	sfx = autofree(SfxScript.new())


func test_celebration_sounds_have_volume_entries():
	for sound in SOUNDS:
		assert_true(SfxScript.VOLUMES.has(sound), sound)
	assert_lt(SfxScript.VOLUMES["applause"], SfxScript.VOLUMES["cannon_pop"], "掌声垫在底下")


func test_celebration_sounds_are_audible_and_not_clipping():
	for sound in SOUNDS:
		var wav: AudioStreamWAV = sfx._synth(sound)
		var samples := int(wav.data.size() / 2.0)
		var span: Array = SOUNDS[sound]
		assert_between(samples, int(span[0] * SfxScript.RATE), int(span[1] * SfxScript.RATE), "%s 时长" % sound)
		var peak := 0
		var clipped := 0
		for i in range(0, wav.data.size(), 2):
			var v := absi(wav.data.decode_s16(i))
			peak = maxi(peak, v)
			if v >= 32000:
				clipped += 1
		assert_gt(peak, 3000, "%s 不是静音" % sound)
		assert_lt(float(clipped) / samples, 0.002, "%s 几乎不削波" % sound)
		assert_lt(absi(wav.data.decode_s16(wav.data.size() - 2)), 600, "%s 结尾收干净" % sound)
