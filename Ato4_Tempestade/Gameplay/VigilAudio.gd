extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
var model: MODEL
var enabled: bool = true
var ambient: AudioStreamPlayer
var cue: AudioStreamPlayer
var storm: AudioStreamPlayer
var previous_music: float = 0.0
var music_ducked: bool = false
var ending_shot: String = ""
var storm_target_db: float = -28.0

func _ready() -> void:
	if not enabled:
		return
	previous_music = AudioManager.music_player.volume_db
	music_ducked = AudioManager.music_player.playing
	if music_ducked:
		AudioManager.music_player.volume_db = previous_music-10.0
	ambient = _player("Sea",_sea(),&"Music",-23.0)
	ambient.play()
	cue = _player("Attention",null,&"SFX",-17.0)
	storm = _player("ReleasedWinds",preload("res://Assets/act4_storm/storm_loop.wav"),&"SFX",-34.0)

func _player(title: String, stream: AudioStream, bus: StringName, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = title
	player.stream = stream
	player.bus = bus
	player.volume_db = volume
	add_child(player)
	return player

func feedback(_text: String, kind: String) -> void:
	if not enabled or cue == null or kind == "notice":
		return
	cue.stream = _tone(kind)
	cue.play()

func _tone(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var length: int = 5000
	var bytes := PackedByteArray()
	bytes.resize(length*2)
	var frequency: float = 75.0 if kind == "steps" else 340.0 if kind == "wake" else 170.0
	for i in length:
		var t: float = float(i)/22050.0
		var envelope: float = sin(PI*float(i)/length)*exp(-t*17.0)
		var value: float = sin(TAU*frequency*t)*envelope*0.28
		bytes.encode_s16(i*2,int(value*32767))
	stream.data = bytes
	return stream

func _sea() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var length: int = 22050*4
	var bytes := PackedByteArray()
	bytes.resize(length*2)
	var random := RandomNumberGenerator.new()
	random.seed = 9044
	var filtered: float = 0.0
	var noise := PackedFloat32Array()
	noise.resize(length)
	for i in length:
		filtered = lerpf(filtered,random.randf_range(-1.0,1.0),0.05)
		noise[i] = filtered
	var overlap: int = int(22050*0.08)
	for i in length:
		var value: float = noise[i]
		if i >= length-overlap:
			value = lerpf(value,noise[i-(length-overlap)],float(i-(length-overlap))/overlap)
		var swell: float = 0.7+sin(TAU*float(i)/length)*0.25
		bytes.encode_s16(i*2,int(value*swell*32767))
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = overlap
	stream.loop_end = length
	return stream

func _process(_delta: float) -> void:
	if not enabled or model == null:
		return
	if model.state in [MODEL.State.ENDING,MODEL.State.COMPLETE]:
		var age: float = model.ending_clock
		ambient.volume_db = -23.0-smoothstep(0.0,3.0,age)*27.0
		if music_ducked:
			AudioManager.music_player.volume_db = previous_music-10.0-smoothstep(0.0,3.0,age)*25.0
		if not model.bag_sealed and not storm.playing:
			storm.play()
		storm.volume_db = move_toward(storm.volume_db,storm_target_db,_delta*12.0)
	elif model.state == MODEL.State.FAILED:
		ambient.volume_db = -48.0

func present_ending(beat: Dictionary) -> void:
	if not enabled or beat.get("phase", "mind") != "storm": return
	ending_shot = str(beat.shot)
	storm_target_db = -19.0
	if ending_shot == "close": storm_target_db = -29.0
	if ending_shot in ["voice","presence"]: storm_target_db = -36.0
	# No footsteps or staged bag-opener sounds accompany the return to reality.
	if ending_shot == "cry":
		cue.stop()
		feedback("","alarm")

func stop() -> void:
	enabled = false
	for player in [ambient,cue,storm]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	stop()
	release_music()

func release_music() -> void:
	if music_ducked and is_instance_valid(AudioManager):
		AudioManager.music_player.volume_db = previous_music
	music_ducked = false
