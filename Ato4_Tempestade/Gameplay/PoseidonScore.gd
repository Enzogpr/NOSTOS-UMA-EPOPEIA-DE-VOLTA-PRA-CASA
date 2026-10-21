extends Node
## One score clock, including hardware mix latency, survives the cinematic handoff.
## Checkpoints capture the clip, loop, queued transition and absolute musical grid.
signal section_changed(section: String)
signal accent(kind: String)

const ROOT := "res://Assets/act4_poseidon_escape/music/"
const CROSSFADE := 0.088
var sections: Dictionary = {}
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var enabled := false
var deterministic := false
var running := false
var frozen := false
var section := ""
var section_elapsed := 0.0
var absolute_time := 0.0
var section_start := 0.0
var beat_period := 60.0/135.0
var pending_section := ""
var pending_at := -1.0
var current_voice := 0
var fade_age := CROSSFADE
var last_raw := 0.0
var loops := 0
var wind_sent := false
var transition_log: Array[Dictionary] = []

func setup(audio: bool, virtual_clock: bool = false) -> void:
	sections = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"score.json")).sections
	beat_period = float(sections.surge.beat_period)
	enabled = audio
	deterministic = virtual_clock or not audio or "--write-movie" in OS.get_cmdline_args()
	if not voices.is_empty(): return
	for name in sections:
		var stream: AudioStreamOggVorbis = load(ROOT+str(sections[name].file)).duplicate()
		stream.loop = bool(sections[name].loop)
		stream.loop_offset = 0.0
		streams[name] = stream
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music" if AudioServer.get_bus_index(&"Music")>=0 else &"Master"
		player.volume_db = -5.0
		add_child(player)
		voices.append(player)

func start_entry() -> void:
	absolute_time = -float(sections.intro.duration)
	_switch("intro",absolute_time,0.0,false)
	running = true
	set_frozen(false)

func start_traversal() -> void:
	absolute_time = 0.0
	_switch("surge",0.0,0.0,false)
	running = true
	set_frozen(false)

func request_section(name: String) -> void:
	if not sections.has(name) or name==section or name==pending_section: return
	if not running:
		start_traversal()
	if section=="intro":
		pending_section=name
		pending_at=0.0
		return
	# The next bar admits a new musical phrase; movement never waits for a bar.
	var bar := beat_period*4.0
	pending_section=name
	pending_at=(floorf(maxf(0,absolute_time)/bar)+1.0)*bar

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not running or frozen or delta<=0: return
	if deterministic:
		section_elapsed += delta
	else:
		var player := voices[current_voice]
		var duration := float(sections[section].duration)
		if player.playing:
			# Godot's audio clock is more stable than accumulated rendered frames.
			var raw := maxf(0.0,player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
			if bool(sections[section].loop):
				raw = fmod(raw,duration)
				if raw < last_raw-duration*0.5: loops += 1
			last_raw=raw
			section_elapsed=maxf(section_elapsed,float(loops)*duration+raw)
		else:
			# A non-looping clip has ended; retain its final cue and transition.
			section_elapsed=maxf(section_elapsed,duration)
	absolute_time=section_start+section_elapsed
	if section=="intro" and section_elapsed>=float(sections.intro.duration):
		var overflow:=section_elapsed-float(sections.intro.duration)
		var following: String=pending_section if not pending_section.is_empty() else "surge"
		pending_section=""
		pending_at=-1
		_switch(following,0.0,overflow,true)
	elif not pending_section.is_empty() and absolute_time>=pending_at:
		var following:=pending_section
		var boundary:=pending_at
		pending_section=""
		pending_at=-1
		_switch(following,boundary,absolute_time-boundary,true)
	if section=="escape" and not wind_sent and section_elapsed>=float(sections.escape.wind_release):
		wind_sent=true
		accent.emit("wind_release")
	if section=="escape" and section_elapsed>=float(sections.escape.duration):
		section_elapsed=float(sections.escape.duration)
		absolute_time=section_start+section_elapsed
		running=false
		for voice in voices: voice.stop()
	if fade_age<CROSSFADE:
		fade_age=minf(CROSSFADE,fade_age+delta)
		_mix_fade()

func _switch(name: String, start: float, elapsed: float, blend: bool) -> void:
	var old:=current_voice
	current_voice=1-current_voice
	section=name
	section_start=start
	section_elapsed=elapsed
	absolute_time=start+elapsed
	var duration:=float(sections[name].duration)
	loops=int(floorf(elapsed/duration)) if bool(sections[name].loop) else 0
	last_raw=fmod(elapsed,duration)
	wind_sent=false
	var player:=voices[current_voice]
	player.stop()
	player.stream=streams[name]
	player.volume_db=-70.0 if blend else -5.0
	if enabled: player.play(last_raw)
	if not blend: voices[old].stop()
	fade_age=0.0 if blend else CROSSFADE
	transition_log.append({"section":name,"at":start,"clip_position":last_raw})
	section_changed.emit(name)

func _mix_fade() -> void:
	var weight:=clampf(fade_age/CROSSFADE,0,1)
	voices[current_voice].volume_db=-5.0+linear_to_db(maxf(weight,0.0001))
	voices[1-current_voice].volume_db=-5.0+linear_to_db(maxf(1.0-weight,0.0001))
	if weight>=1: voices[1-current_voice].stop()

func get_snapshot() -> Dictionary:
	return {"section":section,"elapsed":section_elapsed,"absolute":absolute_time,"start":section_start,"pending":pending_section,"pending_at":pending_at,"wind_sent":wind_sent,"running":running}

func restore(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		start_traversal()
		return
	for voice in voices: voice.stop()
	_switch(str(snapshot.section),float(snapshot.start),float(snapshot.elapsed),false)
	absolute_time=float(snapshot.absolute)
	pending_section=str(snapshot.pending)
	pending_at=float(snapshot.pending_at)
	wind_sent=bool(snapshot.wind_sent)
	running=bool(snapshot.running)
	set_frozen(false)

func set_frozen(value: bool) -> void:
	frozen=value
	for voice in voices: voice.stream_paused=value

func stop_audio() -> void:
	running=false
	for voice in voices: voice.stop()

func _exit_tree() -> void:
	stop_audio()
