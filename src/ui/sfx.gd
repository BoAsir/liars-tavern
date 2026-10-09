extends Node
# 程序化音效(autoload "Sfx"):运行时合成全部音效,无需音频文件。
# 启动后逐帧预热生成,首次播放未生成的音效时即时生成。SFX 总线带轻微房间混响。


const RATE := 22050
const POOL_SIZE := 12
const BUS := "SFX"
const AMBIENCE_SECONDS := 6.0
const AMBIENCE_CROSSFADE := 0.4
const VOLUMES := {
	"deal": -10.0, "slide": -8.0, "slap": -6.0, "flip": -8.0, "sweep": -9.0, "slam": -2.0,
	"bell": -6.0, "cock": -4.0, "spin": -5.0, "click": -2.0, "bang": 0.0, "heartbeat": -3.0,
	"ui_click": -14.0, "ui_hover": -22.0, "whoosh": -12.0, "sting_lie": -6.0, "sting_truth": -8.0,
	"win": -6.0, "join": -10.0, "thud": -4.0,
	"chips": -9.0, "chips_push": -7.0, "fold": -14.0,   # 德州:筹码碰撞 / 全下推筹码 / 轻推牌(规格 §6.7)
	"quip": -11.0,                                      # 快捷对话:轻快的两声「啵」
}
const CHIP_CLATTER_COUNT := 4         # 一次下注落下几枚筹码的碰撞声
const CHIP_PUSH_COUNT := 14           # 全下推一整摞
const CHIP_CLICK_SECONDS := 0.035
const CHIP_FREQ := Vector2(1900.0, 3400.0)   # 筹码是硬塑料:比金属咔哒低、比牌纸脆

var muted := false
var _headless := false
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_setup_bus()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -20.0
	add_child(_ambience)
	if DisplayServer.get_name() == "headless":
		# 无头模式没有音频输出(哑驱动也不回收回放对象),始终静音并跳过合成
		_headless = true
		muted = true
		return
	_warm_up()


func shutdown() -> void:
	# 退出前调用:停止播放并释放音频流。音频线程异步回收回放对象,调用方需再等两帧再退出
	for player in _players + [_ambience]:
		player.stop()
		player.stream = null
	_cache = {}


func play(sound: String, pitch_jitter := 0.04) -> void:
	if muted:
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _stream(sound)
	player.volume_db = VOLUMES.get(sound, -6.0)
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func start_ambience() -> void:
	if _ambience.playing or muted:
		return
	_ambience.stream = _stream("ambience")
	_ambience.play()


func set_muted(value: bool) -> void:
	# 无头模式忽略取消静音。静音启动时环境音没开过,取消静音时补上
	muted = value or _headless
	AudioServer.set_bus_mute(0, muted)
	if not muted:
		start_ambience()


func _setup_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.45
	reverb.damping = 0.6
	reverb.wet = 0.16
	reverb.dry = 0.95
	AudioServer.add_bus_effect(idx, reverb)


func _warm_up() -> void:
	for sound in VOLUMES.keys() + ["ambience"]:
		await get_tree().process_frame
		_stream(sound)


func _stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _synth(sound)
	return _cache[sound]


# —— 合成 ——

func _synth(sound: String) -> AudioStreamWAV:
	match sound:
		"deal":
			return _wav(_noise_burst(0.07, 0.25, 0.004))
		"slide":
			return _wav(_noise_burst(0.16, 0.18, 0.03))
		"slap":
			return _wav(_mix([_noise_burst(0.05, 0.5, 0.001), _thump(130.0, 0.08, 0.7)]))
		"flip":
			return _wav(_mix([_noise_burst(0.05, 0.35, 0.002), _offset(_noise_burst(0.03, 0.5, 0.001), 0.04)]))
		"sweep":
			return _wav(_noise_burst(0.35, 0.12, 0.08))
		"slam":
			return _wav(_mix([_thump(70.0, 0.3, 1.0), _noise_burst(0.12, 0.6, 0.001), _rattle(0.35)]))
		"bell":
			return _wav(_bell(880.0, 1.6))
		"cock":
			return _wav(_mix([_metal_click(0.6), _offset(_metal_click(0.8), 0.09)]))
		"spin":
			return _wav(_ratchet(1.0))
		"click":
			return _wav(_mix([_metal_click(1.0), _thump(300.0, 0.04, 0.4)]))
		"bang":
			return _wav(_gunshot())
		"heartbeat":
			return _wav(_mix([_thump(52.0, 0.14, 1.0), _offset(_thump(46.0, 0.16, 0.8), 0.2)]))
		"ui_click":
			return _wav(_metal_click(0.4))
		"ui_hover":
			return _wav(_thump(900.0, 0.03, 0.3))
		"whoosh":
			return _wav(_whoosh(0.5))
		"sting_lie":
			return _wav(_mix([_saw_note(110.0, 0.35, 0.6), _offset(_saw_note(98.0, 0.7, 0.7), 0.3)]))
		"sting_truth":
			return _wav(_mix([_bell(523.0, 0.8), _offset(_bell(659.0, 0.8), 0.1), _offset(_bell(784.0, 1.0), 0.2)]))
		"win":
			return _wav(_mix([_bell(523.0, 1.2), _offset(_bell(659.0, 1.2), 0.15), _offset(_bell(784.0, 1.2), 0.3),
				_offset(_bell(1046.0, 1.6), 0.45)]))
		"join":
			return _wav(_mix([_bell(659.0, 0.6), _offset(_bell(988.0, 0.7), 0.08)]))
		"thud":
			return _wav(_mix([_thump(60.0, 0.35, 1.0), _noise_burst(0.2, 0.2, 0.01)]))
		"chips":
			return _wav(_mix([_chip_clatter(CHIP_CLATTER_COUNT, 0.22), _thump(180.0, 0.05, 0.3)]))
		"chips_push":
			# 推筹码:一摞筹码在绒布上滑过(闷噪声)+ 密集的碰撞
			return _wav(_mix([_noise_burst(0.45, 0.1, 0.08), _offset(_chip_clatter(CHIP_PUSH_COUNT, 0.5), 0.05)]))
		"fold":
			return _wav(_noise_burst(0.11, 0.2, 0.02))
		"quip":
			return _wav(_mix([_thump(520.0, 0.05, 0.4), _offset(_bell(1175.0, 0.3), 0.04), _offset(_bell(1568.0, 0.25), 0.1)]))
		"ambience":
			return _ambience_stream()
	push_warning("未知音效:" + sound)
	return _wav(PackedFloat32Array([0.0]))


func _ambience_stream() -> AudioStreamWAV:
	var loop := _ambience_loop(AMBIENCE_SECONDS)
	var wav := _wav(loop)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = loop.size()  # 末尾已交叉淡化进开头并截掉:整段采样正好一圈
	return wav


func _noise_burst(duration: float, cutoff: float, attack: float) -> PackedFloat32Array:
	# cutoff 为一阶低通系数(0..1):越小越闷
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / maxf(attack, 0.0001), 1.0) * pow(1.0 - float(i) / n, 2.0)
		y += cutoff * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * env * 1.6
	return out


func _thump(freq: float, duration: float, gain: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := freq * (1.0 + (1.0 - t) * 0.6)
		phase += TAU * f / RATE
		out[i] = sin(phase) * exp(-t * 5.0) * gain
	return out


func _metal_click(gain: float) -> PackedFloat32Array:
	var n := int(0.05 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 140.0)
		out[i] = (sin(TAU * 3100.0 * t) * 0.6 + sin(TAU * 5200.0 * t) * 0.3 + _rng.randf_range(-1, 1) * 0.5) * env * gain
	return out


func _ratchet(duration: float) -> PackedFloat32Array:
	# 转轮:间隔渐长的棘轮咔哒声
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var t := 0.0
	var gap := 0.035
	while t < duration - 0.05:
		var click := _metal_click(0.5)
		var start := int(t * RATE)
		for i in click.size():
			if start + i < out.size():
				out[start + i] += click[i]
		t += gap
		gap *= 1.16
	return out


func _chip_clatter(count: int, duration: float) -> PackedFloat32Array:
	# 几枚筹码先后落下:每枚一声短促的双音敲击,时间与音高都带一点随机
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var click_len := int(CHIP_CLICK_SECONDS * RATE)
	for k in count:
		var start := int(_rng.randf_range(0.0, duration - CHIP_CLICK_SECONDS) * RATE)
		var freq := _rng.randf_range(CHIP_FREQ.x, CHIP_FREQ.y)
		var gain := _rng.randf_range(0.35, 0.7)
		for i in click_len:
			if start + i < out.size():
				var t := float(i) / RATE
				out[start + i] += (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 1.9 * t) * 0.3) * exp(-t * 160.0) * gain
	return out


func _bell(freq: float, duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[1.0, 1.0], [2.0, 0.5], [2.76, 0.35], [5.4, 0.15]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * freq * p[0] * t) * p[1] * exp(-t * (2.2 + p[0] * 0.9))
		out[i] = v * 0.4 * minf(t * 400.0, 1.0)
	return out


func _saw_note(freq: float, duration: float, gain: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(t * freq, 1.0) * 2.0 - 1.0 + (fmod(t * freq * 1.006, 1.0) * 2.0 - 1.0)
		y += 0.08 * (saw - y)
		var env := minf(t * 30.0, 1.0) * exp(-t * 2.5)
		out[i] = y * env * gain
	return out


func _rattle(duration: float) -> PackedFloat32Array:
	# 拍桌时杯瓶轻颤
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	for k in 5:
		var start := int(_rng.randf_range(0.02, duration - 0.06) * RATE)
		var freq := _rng.randf_range(2200.0, 4200.0)
		for i in int(0.04 * RATE):
			if start + i < out.size():
				var t := float(i) / RATE
				out[start + i] += sin(TAU * freq * t) * exp(-t * 90.0) * 0.15
	return out


func _gunshot() -> PackedFloat32Array:
	var n := int(1.6 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var tail := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 38.0)
		phase += TAU * (40.0 + 110.0 * exp(-t * 9.0)) / RATE
		var boom := sin(phase) * exp(-t * 4.5) * 0.9
		tail += 0.04 * (_rng.randf_range(-1.0, 1.0) - tail)
		var rumble := tail * exp(-t * 2.2) * 2.2
		y = crack * 1.1 + boom + rumble
		out[i] = clampf(y, -1.0, 1.0)
	return out


func _whoosh(duration: float) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := 0.03 + 0.12 * sin(t * PI)
		y += cutoff * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * sin(t * PI) * 1.5
	return out


func _ambience_loop(duration: float) -> PackedFloat32Array:
	# 房间底噪(褐噪声)+ 壁炉噼啪,再做成首尾无缝的循环
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	for i in n:
		brown = clampf(brown + _rng.randf_range(-1.0, 1.0) * 0.02, -1.0, 1.0)
		out[i] = brown * 0.35
	for k in int(duration * 9):
		var start := _rng.randi_range(0, n - 400)
		var length := _rng.randi_range(60, 380)
		var gain := _rng.randf_range(0.15, 0.6)
		for i in length:
			out[start + i] += _rng.randf_range(-1.0, 1.0) * gain * pow(1.0 - float(i) / length, 3.0)
	return seamless_loop(out, int(AMBIENCE_CROSSFADE * RATE))


static func seamless_loop(samples: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	# 把末尾 fade 个采样交叉淡化进开头,再截掉末尾:播完最后一个采样跳回开头时,
	# 开头正是原本紧接着的那个采样,循环点没有跳变(否则每圈都会咔哒一声)
	var n := samples.size()
	var overlap := clampi(fade, 0, floori(n / 2.0))
	var out := samples.duplicate()
	for i in overlap:
		var w := float(i) / overlap
		out[i] = samples[i] * w + samples[n - overlap + i] * (1.0 - w)
	out.resize(n - overlap)
	return out


func _offset(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	pad.append_array(samples)
	return pad


func _mix(layers: Array) -> PackedFloat32Array:
	var n := 0
	for layer in layers:
		n = maxi(n, layer.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for layer in layers:
		for i in layer.size():
			out[i] += layer[i]
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
