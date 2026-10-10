extends Control
## Story prologue, followed by the playable storm crossing.

signal storm_revealed
signal ship_control_requested

enum Phase { BLACK, STORM, HANDOFF }
const STORY := "res://Ato4_Tempestade/Cutscenes/Act4_Storm.dialogue.json"
const BACKDROP := "res://Assets/act4_storm/storm_deck.png"
const ACTORS := "res://Assets/act4_storm/fullbody_actors.json"
const REVEAL_BEAT := 9

@export_file("*.tscn") var ship_scene_path: String = "res://Ato4_Tempestade/Gameplay/StormLevel.tscn"
@onready var cinematic: Control = $CinematicPresenter
@onready var storm_audio: AudioStreamPlayer = $StormAudio
@onready var thunder_audio: AudioStreamPlayer = $ThunderAudio

var beats: Array = []
var beat_index: int = -1
var phase: Phase = Phase.BLACK
var storm_time: float = 0.0
var thunder_at: float = 11.0
var rain: Node2D
var handoff_started: bool = false
var handoff_tween: Tween

func _ready() -> void:
	beats = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	GameManager.combat_mode = false
	set_meta("cinematic_active", true)
	MainHUD.set_station("Ato 4 - A Tempestade")
	# Keep this scene's direction local; existing campaign sequences are untouched.
	var actor_sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTORS))
	for key in actor_sources:
		cinematic.library.actors[key] = _make_portrait_actor(actor_sources[key])
	var directions: Array = []
	for index in range(beats.size()):
		var beat: Dictionary = beats[index]
		var direction := {"background": BACKDROP, "hold": beat.get("hold", 1.5), "quiet": true}
		if index > REVEAL_BEAT:
			direction["left"] = "odysseus_storm"
			direction["left_pose"] = int(beat.get("pose", 0))
			direction["focus"] = "left"
			if index >= 14:
				direction["right"] = "eurylochus_storm"
				direction["right_pose"] = 1 if beat.speaker == "Euríloco" else 3
				direction["focus"] = "right" if beat.speaker == "Euríloco" else "left"
			direction["context"] = "CONVÉS · TEMPESTADE"
		directions.append(direction)
	cinematic.library.sequences["act4_storm"] = {"title": "", "beats": directions}
	cinematic.advance_requested.connect(_advance_story)
	cinematic.can_advance = false
	cinematic.get_node("Stage/World/Cave").material.shader = preload("res://Assets/act4_storm/storm_water.gdshader")
	rain = preload("res://Ato4_Tempestade/Cutscenes/StormRain.gd").new()
	rain.name = "StormRain"
	var stage: Control = cinematic.get_node("Stage")
	stage.add_child(rain)
	stage.move_child(rain, stage.get_node("BottomShade").get_index())
	rain.hide()
	var loop := storm_audio.stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / (4 if loop.stereo else 2)
	storm_audio.stream = loop
	_show_beat(0)

func _make_portrait_actor(source: Dictionary) -> Dictionary:
	# Godot frames the existing art; the new faces and gestures stay unchanged.
	var atlas: Texture2D = load(str(source.texture))
	var cell := Vector2(atlas.get_width() / 2.0, atlas.get_height() / 2.0)
	var poses: Array[Texture2D] = []
	var offsets: Array[Vector2] = []
	for frame in range(4):
		var top: float = maxf(0.0, float(source.bounds[frame][1]) - 24.0)
		var pose := AtlasTexture.new()
		pose.atlas = atlas
		pose.region = Rect2(Vector2((frame % 2) * cell.x, (frame / 2) * cell.y + top), Vector2(cell.x, 340.0))
		pose.filter_clip = true
		poses.append(pose)
		var center: float = float(source.anchors[frame][0])
		if bool(source.flip):
			center = cell.x - center
		offsets.append(Vector2(cell.x * 0.5 - center, 0))
	return {"poses": poses, "pose_offsets": offsets, "height": 520.0, "flip": source.flip}

func _show_beat(index: int) -> void:
	beat_index = index
	var on_black: bool = index < REVEAL_BEAT
	_layout_captions(on_black)
	cinematic.present(beats[index], "act4_storm", index)
	# The presenter silences music and skips the mind drone from its own _ready.
	cinematic.get_node("Stage/World").visible = not on_black
	cinematic.get_node("Stage/TopTitle").hide()
	cinematic.get_node("Stage/TopBar").hide()
	cinematic.get_node("Stage/BottomShade").visible = not on_black
	cinematic.get_node("Stage/Controls").modulate.a = 0.45 if on_black else 1.0
	if on_black:
		cinematic.dialogue.bbcode_enabled = true
		cinematic.dialogue.text = "[center]" + cinematic.caption_text + "[/center]"
	if index == REVEAL_BEAT and phase == Phase.BLACK:
		_reveal_storm()

func _layout_captions(on_black: bool) -> void:
	var captions: Control = cinematic.get_node("Stage/Captions")
	captions.position = Vector2(160, 247) if on_black else Vector2(72, 475)
	captions.size = Vector2(832, 140) if on_black else Vector2(1008, 121)
	cinematic.speaker.position = Vector2.ZERO if on_black else Vector2(16, 0)
	cinematic.speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if on_black else HORIZONTAL_ALIGNMENT_LEFT
	cinematic.speaker.custom_minimum_size.x = 832.0 if on_black else 0.0
	cinematic.speaker.size = Vector2(832, 33) if on_black else Vector2(210, 33)
	cinematic.speaker.add_theme_font_size_override("font_size", 18 if on_black else 23)
	cinematic.dialogue.position = Vector2(0, 48) if on_black else Vector2(16, 39)
	cinematic.dialogue.size = Vector2(832, 92) if on_black else Vector2(980, 82)
	cinematic.dialogue.add_theme_font_size_override("normal_font_size", 32 if on_black else 25)
	cinematic.get_node("Stage/BottomShade").position.y = 403.0
	cinematic.get_node("Stage/BottomShade").size.y = 245.0
	cinematic.get_node("Stage/Controls").position.y = 605.0
	cinematic.dialogue.bbcode_enabled = false
	cinematic.get_node("Stage/Captions/Context").visible = not on_black
	cinematic.get_node("Stage/Captions/Accent").visible = not on_black

func _reveal_storm() -> void:
	phase = Phase.STORM
	storm_time = 0.0
	# Hard cut: there is deliberately no background fade or audio ramp here.
	if cinematic.backdrop_tween and cinematic.backdrop_tween.is_running():
		cinematic.backdrop_tween.kill()
	var backdrop: Sprite2D = cinematic.get_node("Stage/World/Cave")
	backdrop.modulate = Color(0.9, 0.94, 1.0, 1.0)
	backdrop.scale *= 1.045
	cinematic.previous_cave.modulate.a = 0.0
	rain.show()
	storm_audio.play()
	_lightning(true)
	cinematic.input_cooldown = 0.7
	storm_revealed.emit()

func _lightning(first: bool = false) -> void:
	thunder_audio.volume_db = -5.0 if first else -10.0
	thunder_audio.play()
	cinematic.shake = 7.0 if first else 2.0
	cinematic._flash(Color(0.76, 0.88, 1.0, 0.42 if first else 0.16))

func _process(delta: float) -> void:
	if phase == Phase.BLACK:
		return
	storm_time += delta
	cinematic.get_node("Stage/World/Cave").rotation = sin(storm_time * 0.82) * 0.012
	cinematic.background_material.set_shader_parameter("storm_clock", storm_time)
	if storm_time >= thunder_at:
		_lightning()
		thunder_at = storm_time + 13.0 + sin(storm_time) * 2.0

func _advance_story() -> void:
	if handoff_started:
		return
	if beat_index + 1 < beats.size():
		_show_beat(beat_index + 1)
	else:
		_begin_handoff()

func _begin_handoff() -> void:
	if handoff_started:
		return
	handoff_started = true
	cinematic.active = false
	cinematic.get_node("Stage/Controls").hide()
	handoff_tween = create_tween()
	handoff_tween.tween_property(cinematic.get_node("Stage/Captions"), "modulate:a", 0.0, 0.6)
	handoff_tween.tween_property(cinematic.get_node("Stage/World/Odysseus"), "modulate:a", 0.0, 0.5)
	handoff_tween.parallel().tween_property(cinematic.get_node("Stage/World/Athena"), "modulate:a", 0.0, 0.5)
	handoff_tween.tween_callback(func():
		phase = Phase.HANDOFF
		ship_control_requested.emit()
		if not ship_scene_path.is_empty():
			get_tree().change_scene_to_file(ship_scene_path)
	)
