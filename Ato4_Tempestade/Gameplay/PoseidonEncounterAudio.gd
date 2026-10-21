extends Node
## Local encounter mix. Does not change buses or the campaign AudioManager.
## setup(false) and stop_audio() silence every owned voice. Call setup(true) to resume.
## update_state: tension/quiet in 0..1, speed in world pixels/second; quiet ducks ambience.
## cue: creak, wood_snap, splash, divine_rumble, footstep, land, gust, warning.

const SAMPLE_RATE := 22050
const STORM_PATH := "res://Assets/act4_storm/storm_loop.wav"
const CUE_DURATION := {
	"creak": 1.05, "wood_snap": 0.82, "splash": 0.88,
	"divine_rumble": 2.8, "footstep": 0.17, "land": 0.38,
	"gust": 1.4, "warning": 1.15, "sword_swing":0.23, "sword_hit":0.28, "dash":0.2,
}
const CUE_VOLUME := {
	"creak": -23.0, "wood_snap": -16.0, "splash": -21.0,
	"divine_rumble": -17.0, "footstep": -29.0, "land": -23.0,
	"gust": -25.0, "warning": -23.0, "sword_swing":-23.0, "sword_hit":-19.0, "dash":-20.0,
}
const CUE_GAP := {
	"creak": 0.55, "wood_snap": 0.25, "splash": 0.22,
	"divine_rumble": 1.1, "footstep": 0.17, "land": 0.2,
	"gust": 0.6, "warning": 0.45, "sword_swing":0.2, "sword_hit":0.12, "dash":0.2,
}

static var _bank: Dictionary = {}
var mix_offset_db := 0.0
var _enabled: bool = false
var _initialized: bool = false
var _storm: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _snap: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _last_cue: Dictionary = {}
var _variant_index: Dictionary = {}
var _tension: float = 0.0
var _quiet: float = 0.0
var _speed: float = 0.0
var _grounded: bool = true
var _foot_clock: float = 0.0

func setup(enabled: bool) -> void:
	if not enabled:
		stop_audio()
		return
	if not _initialized:
		_prepare_bank()
		_storm = _voice()
		_rumble = _voice()
		_snap = _voice()
		for index in 4:
			_voices.append(_voice())
		var original := load(STORM_PATH) as AudioStreamWAV
		if original:
			var loop := original.duplicate() as AudioStreamWAV
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
			_storm.stream = loop
		_storm.volume_db = -40.0
		_initialized = true
	_enabled = true
	set_process(true)
	if _storm.stream and not _storm.playing:
		_storm.play()

func update_state(tension: float, quiet: float, player_speed: float, grounded: bool) -> void:
	_tension = clampf(tension, 0.0, 1.0)
	_quiet = clampf(quiet, 0.0, 1.0)
	_speed = absf(player_speed)
	if grounded and not _grounded and _enabled:
		cue("land")
	_grounded = grounded
	if not grounded or _speed < 30.0:
		_foot_clock = 0.0

func cue(kind: String) -> void:
	if not _enabled or not _bank.has(kind):
		return
	var now: float = Time.get_ticks_msec() * 0.001
	if now - float(_last_cue.get(kind, -100.0)) < float(CUE_GAP[kind]):
		return
	var player: AudioStreamPlayer
	if kind == "divine_rumble":
		player = _rumble
	elif kind == "wood_snap":
		player = _snap
	else:
		for voice in _voices:
			if not voice.playing:
				player = voice
				break
		# A crowded mix drops texture instead of stealing an impact or stacking noise.
		if player == null:
			return
	var variants: Array = _bank[kind]
	var index: int = int(_variant_index.get(kind, 0)) % variants.size()
	_variant_index[kind] = index + 1
	_last_cue[kind] = now
	player.stream = variants[index]
	player.volume_db = mix_offset_db + float(CUE_VOLUME[kind]) - _quiet * (2.0 if kind in ["wood_snap", "divine_rumble"] else 5.0)
	player.pitch_scale = 1.0 + float(index - 1) * 0.025
	player.play()

func _process(delta: float) -> void:
	if not _enabled:
		return
	var target_db: float = mix_offset_db + lerpf(-31.0, -23.0, _tension) - _quiet * 18.0
	_storm.volume_db = lerpf(_storm.volume_db, target_db, 1.0 - exp(-delta * 2.8))
	if _grounded and _speed > 30.0:
		_foot_clock += delta
		var stride: float = clampf(72.0 / maxf(_speed, 1.0), 0.21, 0.48)
		if _foot_clock >= stride:
			_foot_clock = fmod(_foot_clock, stride)
			cue("footstep")

func _voice() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	player.max_polyphony = 1
	add_child(player)
	return player

static func _prepare_bank() -> void:
	if not _bank.is_empty():
		return
	var seed_number: int = 8127
	for kind in CUE_DURATION:
		if kind=="dash":
			_bank[kind]=[preload("res://Assets/sfx_dash.wav")]
			continue
		var clips: Array[AudioStreamWAV] = []
		var count: int = 3 if kind in ["footstep", "creak", "wood_snap", "land"] else 2
		for variant in count:
			clips.append(_material(kind, float(CUE_DURATION[kind]), seed_number + variant * 137))
		_bank[kind] = clips
		seed_number += 1709

static func _material(kind: String, duration: float, random_seed: int) -> AudioStreamWAV:
	# One-time noise synthesis: bands, damped wooden resonances and material envelopes.
	# No oscillators or audio generation in the gameplay update.
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var frames: int = int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var resonator := PackedFloat32Array()
	resonator.resize(173)
	var low: float = 0.0
	var slower: float = 0.0
	var fast: float = 0.0
	var tail: float = 0.0
	var grain: float = 0.0
	var wood: bool = kind in ["creak", "wood_snap", "footstep", "land"]
	var alpha: float = 0.035 if kind == "divine_rumble" else 0.15 if wood else 0.32
	for i in frames:
		var t: float = float(i) / SAMPLE_RATE
		var u: float = t / duration
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += alpha * (noise - low)
		slower += 0.009 * (noise - slower)
		fast += 0.68 * (noise - fast)
		var band: float = low - slower
		var hiss: float = fast - low
		if rng.randf() < (0.002 if wood else 0.0006):
			grain = rng.randf_range(0.2, 1.0)
		grain *= 0.993 if kind == "creak" else 0.975
		var delayed: float = resonator[i % resonator.size()]
		var body: float = band * (0.8 + grain * 1.3) + delayed * 0.61
		resonator[i % resonator.size()] = body * 0.72
		var envelope: float = 0.0
		var sample: float = 0.0
		match kind:
			"creak":
				envelope = sin(PI * u) * (0.35 + grain)
				sample = body * 1.65 + hiss * grain * 0.15
			"wood_snap":
				envelope = exp(-t * 7.0) + maxf(0.0, 1.0 - absf(t - 0.19) / 0.045) * 0.36
				sample = body * 2.0 + hiss * 0.7 * exp(-t * 21.0)
			"footstep":
				envelope = exp(-t * 30.0)
				sample = body * 2.3 + hiss * 0.13
			"land":
				envelope = exp(-t * 13.0)
				sample = body * 2.5 + hiss * 0.22
			"splash":
				envelope = pow(maxf(0.0, 1.0 - u), 1.6) * minf(t * 23.0, 1.0)
				sample = band * 1.7 + hiss * (0.15 + 0.5 * u)
			"divine_rumble":
				envelope = minf(t * 5.0, 1.0) * pow(maxf(0.0, 1.0 - u), 1.45)
				sample = low * 4.0 + slower * 5.0 + hiss * 0.025
			"gust":
				envelope = pow(sin(PI * u), 1.7)
				sample = band * 1.8 + hiss * 0.2
			"sword_swing":
				envelope = pow(sin(PI*u),2.0)
				sample = hiss*1.4+band*0.5
			"sword_hit":
				envelope = exp(-t*19.0)
				sample = body*2.8+hiss*exp(-t*36.0)*1.5
			"warning":
				envelope = pow(sin(PI * u), 0.8) * (0.35 + u * 0.65)
				sample = slower * 4.0 + band * 1.2 + hiss * 0.07
		# Smooth both sample boundaries and remove residual DC before encoding.
		var edge: float = minf(t * 500.0, 1.0) * minf((duration - t) * 120.0, 1.0)
		var raw: float = sample * envelope * edge
		tail += 0.001 * (raw - tail)
		var limited: float = clampf((raw - tail) * 0.75, -0.92, 0.92)
		bytes.encode_s16(i * 2, int(limited * 28000.0))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = SAMPLE_RATE
	clip.stereo = false
	clip.data = bytes
	return clip

func stop_audio() -> void:
	_enabled = false
	set_process(false)
	for player in [_storm, _rumble, _snap]:
		if is_instance_valid(player):
			player.stop()
	for player in _voices:
		if is_instance_valid(player):
			player.stop()
	_foot_clock = 0.0
	_last_cue.clear()

func _exit_tree() -> void:
	stop_audio()
	for player in [_storm, _rumble, _snap]:
		if is_instance_valid(player):
			player.stream = null
	for player in _voices:
		if is_instance_valid(player):
			player.stream = null
