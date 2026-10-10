extends Control
## Layered, responsive cinematic: poses, reactions, camera and apparition are
## independent of the dialogue. Run this scene directly with F6 to preview it.

signal cinematic_finished

const DESIGN_SIZE := Vector2(1152, 648)
const DIALOGUE_FILE := "res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewell.dialogue.json"
const ANIMATIC := preload("res://Ato3_Ciclope/Cutscenes/Act3_AthenaAnimatic.gd")

@export var use_animatic: bool = true
@export var autoplay: bool = true
@export_range(20.0, 80.0) var characters_per_second: float = 38.0
@export_range(0.5, 3.0) var playback_speed: float = 1.0
@export_file("*.tscn") var next_scene_path: String = "res://Ato3_Ciclope/Cutscenes/Act3_EndingCard.tscn"

@onready var stage: Control = $Stage
@onready var world: Node2D = $Stage/World
@onready var atmosphere: Node2D = $Stage/World/Atmosphere
@onready var odysseus: Node2D = $Stage/World/Odysseus/Motion
@onready var athena: Node2D = $Stage/World/Athena/Motion
@onready var dialogue: RichTextLabel = $Stage/Captions/Dialogue
@onready var speaker: Label = $Stage/Captions/Speaker
@onready var speaker_context: Label = $Stage/Captions/Context
@onready var auto_button: Button = $Stage/Controls/AutoButton
@onready var next_button: Button = $Stage/Controls/NextButton
@onready var black: ColorRect = $Stage/Black
@onready var presence_material: ShaderMaterial = $Stage/World/Athena/Motion/Portrait.material

var beats: Array = []
var current_beat: int = -1
var can_advance: bool = false
var is_ending: bool = false
var elapsed: float = 0.0
var type_elapsed: float = 0.0
var hold_elapsed: float = 0.0
var input_cooldown: float = 0.0
var camera_zoom: float = 1.0
var camera_offset := Vector2.ZERO
var odysseus_offset := Vector2.ZERO
var athena_offset := Vector2.ZERO
var presence: float = 0.0
var agitation: float = 0.0
var shake: float = 0.0
var intro_tween: Tween
var beat_tween: Tween
var apparition_tween: Tween
var ending_tween: Tween
var pose_tweens: Dictionary = {}
var previous_music_volume: float = 0.0
var music_ducked: bool = false
var animatic: Node2D

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_FILE))
	if not parsed is Array or parsed.is_empty():
		push_error("O diálogo do adeus de Atena não pôde ser carregado.")
		return
	beats = parsed
	if use_animatic:
		animatic = ANIMATIC.new()
		animatic.name = "Animatic"
		stage.add_child(animatic)
		stage.move_child(animatic, 1)
		world.hide()
		animatic.present(0, beats[0])
	GameManager.combat_mode = false
	MainHUD.set_station("Ato 3 - O Adeus de Atena")
	resized.connect(_fit_stage)
	_fit_stage()
	auto_button.pressed.connect(_toggle_auto)
	next_button.pressed.connect(_advance_requested)
	$Stage/Controls/SkipButton.pressed.connect(_finish)
	_update_auto_button()
	$Stage/Captions.modulate.a = 0.0
	$Stage/Controls.modulate.a = 0.0
	$Stage/Opening.modulate.a = 0.0
	$Stage/World/Athena.modulate.a = 1.0
	black.color.a = 1.0
	_start_ambience()
	intro_tween = create_tween()
	intro_tween.tween_property(black, "color:a", 0.0, 1.0)
	intro_tween.parallel().tween_property($Stage/Opening, "modulate:a", 1.0, 0.8)
	intro_tween.tween_interval(1.0)
	intro_tween.tween_property(self, "presence", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	intro_tween.parallel().tween_property($Stage/Opening, "modulate:a", 0.0, 0.8)
	intro_tween.tween_property($Stage/Captions, "modulate:a", 1.0, 0.4)
	intro_tween.parallel().tween_property($Stage/Controls, "modulate:a", 1.0, 0.4)
	intro_tween.tween_callback(func():
		can_advance = true
		_show_beat(0)
	)

func _fit_stage() -> void:
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - DESIGN_SIZE * factor) * 0.5

func _process(delta: float) -> void:
	elapsed += delta
	if animatic:
		animatic.presence = presence
		animatic.agitation = agitation
	input_cooldown = maxf(0.0, input_cooldown - delta)
	shake = move_toward(shake, 0.0, delta * 10.0)
	world.scale = Vector2.ONE * camera_zoom
	world.position = DESIGN_SIZE * 0.5 + camera_offset + Vector2(sin(elapsed * 52.0), cos(elapsed * 39.0)) * shake
	# Small motions read as breathing/hovering while retaining crisp pixel art.
	odysseus.position = odysseus_offset + Vector2(0, sin(elapsed * 1.8) * 1.3)
	odysseus.scale = Vector2(1.0 + sin(elapsed * 1.8) * 0.002, 1.0)
	athena.position = athena_offset + Vector2(sin(elapsed * 0.8) * 1.8, sin(elapsed * 1.25) * 3.2)
	presence_material.set_shader_parameter("presence", presence)
	presence_material.set_shader_parameter("agitation", agitation)
	atmosphere.presence = presence
	atmosphere.agitation = agitation
	$Stage/World/MindLight.modulate.a = presence * (0.55 + sin(elapsed * 1.5) * 0.06)
	if not can_advance or is_ending:
		return
	type_elapsed += delta * playback_speed
	var count: int = dialogue.get_total_character_count()
	dialogue.visible_characters = mini(int(type_elapsed * characters_per_second), count)
	if dialogue.visible_characters >= count:
		next_button.text = "CONTINUAR  ›"
		hold_elapsed += delta * playback_speed
		var beat: Dictionary = beats[current_beat]
		var hold: float = float(beat.get("hold", 1.1)) + float(count) / 65.0
		if autoplay and hold_elapsed >= hold:
			_advance()
	else:
		next_button.text = "MOSTRAR FALA  ›"

func _show_beat(index: int) -> void:
	current_beat = index
	type_elapsed = 0.0
	hold_elapsed = 0.0
	input_cooldown = 0.18
	var beat: Dictionary = beats[index]
	var is_athena: bool = beat.speaker == "Atena"
	var intensity: float = float(beat.get("intensity", 0.3))
	if animatic:
		animatic.present(index, beat)
	dialogue.text = str(beat.text)
	dialogue.visible_characters = 0
	speaker.text = str(beat.speaker).to_upper()
	speaker.add_theme_color_override("font_color", Color(0.72, 0.84, 1.0) if is_athena else Color(1.0, 0.73, 0.43))
	speaker_context.text = "NA MENTE DE ODISSEU" if is_athena else "REI DE ÍTACA"
	$Stage/Captions/Accent.color = Color(0.52, 0.71, 1.0) if is_athena else Color(0.85, 0.45, 0.21)
	_change_pose(athena if is_athena else odysseus, int(beat.pose))
	if beat.has("reaction"):
		_change_pose(odysseus if is_athena else athena, int(beat.reaction))
	if beat_tween and beat_tween.is_running():
		beat_tween.kill()
	var camera: String = str(beat.get("camera", "wide"))
	var target_zoom: float = 1.0 if camera == "wide" else 1.065 + intensity * 0.025
	var target_offset := Vector2.ZERO
	if camera == "athena":
		target_offset = Vector2(-30.0, 14.0)
	elif camera == "odysseus":
		target_offset = Vector2(30.0, 14.0)
	beat_tween = create_tween().set_parallel(true)
	beat_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	beat_tween.tween_property(self, "camera_zoom", target_zoom, 1.1)
	beat_tween.tween_property(self, "camera_offset", target_offset, 1.1)
	beat_tween.tween_property(self, "agitation", intensity, 0.5)
	beat_tween.tween_property(self, "odysseus_offset", Vector2(7.0 if not is_athena else 0.0, 5.0 if int(odysseus.get_node("Portrait").frame) == 0 else 0.0), 0.6)
	beat_tween.tween_property(self, "athena_offset", Vector2(-7.0 if is_athena else 0.0, -intensity * 3.0), 0.7)
	beat_tween.tween_property($Stage/World/Odysseus, "modulate", Color.WHITE if not is_athena else Color(0.73, 0.76, 0.84), 0.4)
	beat_tween.tween_property($Stage/World/Athena, "modulate", Color.WHITE if is_athena else Color(0.78, 0.83, 0.96), 0.4)
	match str(beat.get("cue", "")):
		"shock":
			shake = 4.0
			_flash(Color(1.0, 0.66, 0.38, 0.12))
		"rupture":
			shake = 2.5
			atmosphere.burst()
			if apparition_tween and apparition_tween.is_running():
				apparition_tween.kill()
			apparition_tween = create_tween()
			apparition_tween.tween_property(self, "presence", 0.67, 0.25)
			apparition_tween.tween_property(self, "presence", 0.95, 1.2)
		"verdict":
			_flash(Color(0.58, 0.77, 1.0, 0.10))

func _change_pose(actor: Node2D, frame: int) -> void:
	var portrait := actor.get_node("Portrait") as Sprite2D
	var previous := actor.get_node("PreviousPose") as Sprite2D
	if portrait.frame == frame:
		return
	if pose_tweens.has(actor) and pose_tweens[actor].is_running():
		pose_tweens[actor].kill()
	previous.frame = portrait.frame
	previous.modulate.a = portrait.modulate.a
	portrait.frame = frame
	portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(previous, "modulate:a", 0.0, 0.22)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.22)
	pose_tweens[actor] = tween

func _flash(tint: Color) -> void:
	$Stage/Flash.color = tint
	var tween := create_tween()
	tween.tween_property($Stage/Flash, "color:a", 0.0, 0.35)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	if event is InputEventKey and event.keycode == KEY_A:
		viewport.set_input_as_handled()
		_toggle_auto()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		viewport.set_input_as_handled()
		_advance_requested()

func _advance_requested() -> void:
	if not can_advance or is_ending or input_cooldown > 0.0:
		return
	input_cooldown = 0.18
	if dialogue.visible_characters < dialogue.get_total_character_count():
		type_elapsed = float(dialogue.get_total_character_count()) / characters_per_second
		dialogue.visible_characters = dialogue.get_total_character_count()
		hold_elapsed = 0.0
	else:
		_advance()

func _advance() -> void:
	if current_beat + 1 < beats.size():
		_show_beat(current_beat + 1)
	else:
		_finish()

func _toggle_auto() -> void:
	autoplay = not autoplay
	hold_elapsed = 0.0
	_update_auto_button()

func _update_auto_button() -> void:
	auto_button.text = "AUTO: SIM  [A]" if autoplay else "AUTO: NÃO  [A]"

func _finish() -> void:
	if is_ending:
		return
	is_ending = true
	can_advance = false
	for tween in [intro_tween, beat_tween, apparition_tween]:
		if tween and tween.is_running():
			tween.kill()
	_change_pose(athena, 3)
	_change_pose(odysseus, 0)
	if animatic:
		animatic.begin_departure()
	atmosphere.burst()
	ending_tween = create_tween()
	ending_tween.tween_property($Stage/Captions, "modulate:a", 0.0, 0.5)
	ending_tween.parallel().tween_property($Stage/Controls, "modulate:a", 0.0, 0.5)
	ending_tween.parallel().tween_property($Stage/Opening, "modulate:a", 0.0, 0.5)
	ending_tween.tween_property(self, "presence", 0.0, 3.0).set_trans(Tween.TRANS_SINE)
	ending_tween.parallel().tween_property(self, "camera_zoom", 1.0, 3.0)
	ending_tween.parallel().tween_property(self, "camera_offset", Vector2.ZERO, 3.0)
	ending_tween.parallel().tween_property($MindAmbience, "volume_db", -35.0, 3.0)
	ending_tween.tween_interval(2.2)
	ending_tween.tween_property(black, "color:a", 1.0, 1.2)
	ending_tween.tween_callback(func():
		cinematic_finished.emit()
		if not next_scene_path.is_empty():
			get_tree().change_scene_to_file(next_scene_path)
	)

func _start_ambience() -> void:
	# Scene-owned, seamless ambient drone; follows the existing Music volume bus.
	# No new global audio settings or prerecorded character voices.
	var sample_rate := 22050
	var seconds := 4
	var samples := sample_rate * seconds
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / float(sample_rate)
		var breath: float = 0.75 + 0.25 * sin(TAU * t / float(seconds))
		var wave: float = sin(TAU * 73.5 * t) * 0.12 + sin(TAU * 110.0 * t) * 0.06 + sin(TAU * 147.0 * t) * 0.03
		data.encode_s16(i * 2, int(wave * breath * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	$MindAmbience.stream = stream
	$MindAmbience.play()
	previous_music_volume = AudioManager.music_player.volume_db
	if AudioManager.music_player.playing:
		AudioManager.music_player.volume_db = previous_music_volume - 14.0
		music_ducked = true

func _exit_tree() -> void:
	if music_ducked and is_instance_valid(AudioManager):
		AudioManager.music_player.volume_db = previous_music_volume
