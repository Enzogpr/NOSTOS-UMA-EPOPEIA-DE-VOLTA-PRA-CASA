extends "res://Ato4_Tempestade/Cutscenes/LuckRunsOut.gd"
## Reuses the project's cinematic UI, with reference-directed shot durations.
signal poseidon_finished
@export var continue_to_escape: bool = true
const POSEIDON_DIRECTOR := preload("res://Ato4_Tempestade/Cutscenes/PoseidonStage.gd")
var shot_clock: float = 0.0
var complete_count: int = 0
var end_panel: Panel
var wind: AudioStreamPlayer
var foley: AudioStreamPlayer
var audio_enabled: bool = true
var sound_events: Array[String] = []
var handoff_record: Dictionary = {}
var escape_score: Node
var score_transferred := false

func _dialogue_path() -> String:
	return "res://Ato4_Tempestade/Cutscenes/Ruthlessness.dialogue.json"

func _create_director() -> Node2D:
	return POSEIDON_DIRECTOR.new()

func _ready() -> void:
	super._ready()
	set_meta("cinematic_active",true)
	standalone_ascent = false
	MainHUD.set_station("Ato 4 - Poseidon")
	$Stage/TopTitle.text = "ATO IV   /   CRUELDADE É PIEDADE"
	$Stage/Controls/SkipButton.hide()
	for path in ["BottomShade","TopBar","TopTitle","Captions","Controls"]:
		get_node("Stage/"+path).z_index = 20
	black.z_index = 29
	$Stage/Captions.position = Vector2(60,472)
	$Stage/Captions.size = Vector2(1032,123)
	dialogue.size = Vector2(1014,82)
	dialogue.add_theme_font_size_override("normal_font_size",25)
	director.sound_cue.connect(_sound)
	wind = AudioStreamPlayer.new()
	wind.stream = preload("res://Assets/act4_storm/storm_loop.wav")
	wind.bus = &"SFX"
	wind.volume_db = -30.0
	add_child(wind)
	foley = AudioStreamPlayer.new()
	foley.bus = &"SFX"
	foley.volume_db = -17.0
	add_child(foley)
	if audio_enabled: wind.play()
	else: sea_ambience.stop()
	_build_end_panel()

func _show_beat(index: int) -> void:
	super._show_beat(index)
	shot_clock = 0.0
	$Stage/Captions.visible = not str(beats[index].text).is_empty()
	var god_speaks: bool = beats[index].speaker == "Poseidon"
	var tint := Color(0.40,0.88,0.92) if god_speaks else Color(1.0,0.78,0.53)
	speaker.add_theme_color_override("font_color",tint)
	$Stage/Captions/Accent.color = tint
	speaker_context.text = "TERRA DOS GIGANTES · POSEIDON"

func _process(delta: float) -> void:
	if director == null: return
	input_cooldown = maxf(0.0,input_cooldown-delta)
	var step: float = delta*playback_speed
	if not can_advance or is_ending:
		director.seek(director.age,step)
		return
	shot_clock += step
	type_elapsed += step
	var count: int = dialogue.get_total_character_count()
	dialogue.visible_characters = mini(count,int(type_elapsed*characters_per_second))
	director.speaking = dialogue.visible_characters < count
	director.seek(shot_clock,step)
	var action_complete: bool = shot_clock >= float(beats[current_beat].duration)
	next_button.text = "MOSTRAR FALA  ›" if director.speaking else "CONTINUAR  ›" if action_complete else "AGUARDE  ›"
	if audio_enabled:
		wind.volume_db = move_toward(wind.volume_db,-21.0 if director.ocean.visible else -30.0,delta*6.0)
		sea_ambience.volume_db = -29.0
	if autoplay and action_complete: _advance()

func _advance_requested() -> void:
	if not can_advance or is_ending or input_cooldown > 0.0: return
	input_cooldown = 0.22
	if dialogue.visible_characters < dialogue.get_total_character_count():
		type_elapsed = 1000.0
		dialogue.visible_characters = dialogue.get_total_character_count()
	elif shot_clock >= float(beats[current_beat].duration):
		_advance()

func _sound(kind: String) -> void:
	sound_events.append(kind)
	if not audio_enabled: return
	if kind == "impact":
		foley.stream = preload("res://Assets/act4_storm/thunder.wav")
		foley.volume_db = -23.0 if is_instance_valid(escape_score) else -10.0
		foley.play()
	elif kind in ["surge","splash"]:
		foley.stream = preload("res://Assets/act4_storm/storm_loop.wav")
		foley.volume_db = -21.0
		foley.play()
		get_tree().create_timer(0.45,false).timeout.connect(func():
			if is_instance_valid(foley): foley.stop())
	elif kind in ["grip","deck","hoof"]:
		var tone := AudioStreamWAV.new()
		tone.format = AudioStreamWAV.FORMAT_16_BITS
		tone.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(4200*2)
		for i in 4200:
			var t: float = float(i)/22050.0
			bytes.encode_s16(i*2,int(sin(t*TAU*(65.0 if kind != "grip" else 110.0))*exp(-t*34.0)*0.2*32767))
		tone.data = bytes
		foley.stream = tone
		foley.volume_db = -21.0 if kind == "hoof" else -17.0
		foley.play()

func _finish() -> void:
	if is_ending: return
	is_ending = true
	can_advance = false
	director.speaking = false
	$Stage/Captions.hide()
	$Stage/Controls.hide()
	black.color.a = 1.0
	stop_audio()
	complete_count += 1
	poseidon_finished.emit()
	conversation_finished.emit()
	cinematic_finished.emit()
	if continue_to_escape:
		_continue_to_escape.call_deferred()
	else:
		end_panel.show()

func _start_escape_score() -> void:
	escape_score = preload("res://Ato4_Tempestade/Gameplay/PoseidonScore.gd").new()
	# A stable parent keeps AudioStreamPlayers inside the tree at the handoff.
	# This scene owns cleanup until the gameplay controller accepts ownership.
	get_tree().root.add_child(escape_score)
	escape_score.setup(audio_enabled)
	escape_score.start_entry()
	# Only the opening invocation is voiced; gameplay phrases are instrumental.
	# Campaign music is restored by this scene and ducked by the next owner.

func _continue_to_escape() -> void:
	if not is_instance_valid(escape_score): _start_escape_score()
	release_music()
	var next: Control = load("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	next.handoff_record = handoff_record.duplicate(true)
	next.audio_enabled = audio_enabled
	next.handoff_score = escape_score
	next.autostart = true
	next.modulate.a = 0.0
	get_tree().root.add_child(next)
	score_transferred = true
	get_tree().current_scene = next
	var transition := next.create_tween()
	transition.tween_property(next,"modulate:a",1.0,0.65)
	queue_free()

func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.position = Vector2(276,223)
	end_panel.z_index = 30
	end_panel.size = Vector2(600,208)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015,0.04,0.06,0.96)
	style.border_color = Color(0.25,0.54,0.58)
	style.set_border_width_all(1)
	end_panel.add_theme_stylebox_override("panel",style)
	stage.add_child(end_panel)
	var title := Label.new()
	title.text = "CRUELDADE É PIEDADE"
	title.position = Vector2(28,26)
	title.add_theme_font_size_override("font_size",29)
	end_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "O primeiro impacto."
	subtitle.position = Vector2(28,79)
	subtitle.add_theme_font_size_override("font_size",20)
	end_panel.add_child(subtitle)
	for definition in [["REVER CENA",28],["VOLTAR AO MAPA",316]]:
		var button := Button.new()
		button.text = definition[0]
		button.position = Vector2(definition[1],143)
		button.size = Vector2(256,38)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			get_tree().change_scene_to_file("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn" if definition[1] == 28 else "res://Scenes/WorldMap.tscn"))
		end_panel.add_child(button)
	end_panel.hide()

func stop_audio() -> void:
	for player in [wind,foley,sea_ambience]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	if is_instance_valid(escape_score) and not score_transferred:
		escape_score.stop_audio()
		escape_score.queue_free()
	stop_audio()
	release_music()

func release_music() -> void:
	if music_ducked and is_instance_valid(AudioManager): AudioManager.music_player.volume_db = previous_music_volume
	music_ducked = false
