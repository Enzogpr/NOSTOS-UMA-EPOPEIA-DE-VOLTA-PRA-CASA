extends "res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.gd"
## Scene-owned animation; campaign mounts it over the secured rope before ascent.

signal conversation_finished
const STORY := "res://Ato4_Tempestade/Cutscenes/LuckRunsOut.dialogue.json"
const DIRECTOR := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
@export var standalone_ascent: bool = true
var director: Node2D

func _ready() -> void:
	set_meta("hide_main_hud", true)
	set_meta("cinematic_active", true)
	GameManager.combat_mode = false
	MainHUD.set_station("Ato 4 - A sorte acaba")
	beats = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	world.hide()
	director = DIRECTOR.new()
	director.name = "LuckStage"
	stage.add_child(director)
	stage.move_child(director, 1)
	resized.connect(_fit_stage)
	_fit_stage()
	$Stage/Opening.hide()
	$Stage/TopTitle.text = "ATO IV   /   A SORTE ACABA"
	$Stage/Captions.modulate.a = 0.0
	$Stage/Controls.modulate.a = 0.0
	$Stage/Controls/SkipButton.text = "PULAR CONVERSA"
	auto_button.pressed.connect(_toggle_auto)
	next_button.pressed.connect(_advance_requested)
	$Stage/Controls/SkipButton.pressed.connect(_finish)
	_update_auto_button()
	previous_music_volume = AudioManager.music_player.volume_db
	music_ducked = AudioManager.music_player.playing
	if music_ducked:
		AudioManager.music_player.volume_db = previous_music_volume - 8.0
	_start_sea_ambience()
	sea_ambience.volume_db = -24.0
	black.color.a = 1.0
	director.present(0, beats[0])
	intro_tween = create_tween()
	intro_tween.tween_property(black, "color:a", 0.0, 0.7)
	intro_tween.tween_property($Stage/Captions, "modulate:a", 1.0, 0.35)
	intro_tween.parallel().tween_property($Stage/Controls, "modulate:a", 1.0, 0.35)
	intro_tween.tween_callback(func():
		can_advance = true
		_show_beat(0)
	)

func _show_beat(index: int) -> void:
	current_beat = index
	type_elapsed = 0.0
	hold_elapsed = 0.0
	input_cooldown = 0.2
	var beat: Dictionary = beats[index]
	dialogue.text = str(beat.text)
	dialogue.visible_characters = 0
	speaker.text = str(beat.speaker).to_upper()
	var tint := Color(1.0,0.76,0.48) if beat.speaker == "Odisseu" else Color(0.72,0.85,1.0)
	speaker.add_theme_color_override("font_color", tint)
	$Stage/Captions/Accent.color = tint
	speaker_context.text = "EM PARTICULAR" if index >= 26 else "CONVÉS · EÓLIA"
	director.present(index, beat)

func _process(delta: float) -> void:
	elapsed += delta
	input_cooldown = maxf(0.0, input_cooldown-delta)
	if director == null:
		return
	sea_ambience.volume_db = lerpf(-24.0,-32.0,clampf(director.privacy/0.46,0.0,1.0))
	if not can_advance or is_ending:
		director.speaking = false
		return
	type_elapsed += delta * playback_speed
	var count := dialogue.get_total_character_count()
	dialogue.visible_characters = mini(int(type_elapsed*characters_per_second), count)
	director.speaking = dialogue.visible_characters < count
	if dialogue.visible_characters >= count:
		next_button.text = "CONTINUAR  ›"
		hold_elapsed += delta * playback_speed
		var hold: float = float(beats[current_beat].get("hold",1.3)) + count/70.0
		if autoplay and hold_elapsed >= hold:
			_advance()
	else:
		next_button.text = "MOSTRAR FALA  ›"

func _finish() -> void:
	if is_ending:
		return
	is_ending = true
	can_advance = false
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
	director.prepare_ascent()
	ending_tween = create_tween()
	ending_tween.tween_property($Stage/Captions,"modulate:a",0.0,0.45)
	ending_tween.parallel().tween_property($Stage/Controls,"modulate:a",0.0,0.45)
	ending_tween.tween_interval(1.2)
	ending_tween.tween_property(black,"color:a",1.0,0.6)
	ending_tween.tween_callback(func():
		conversation_finished.emit()
		cinematic_finished.emit()
		if standalone_ascent:
			var game: Control = load("res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.tscn").instantiate()
			get_tree().root.add_child(game)
			get_tree().current_scene = game
			game.prepare_ascent_preview()
			queue_free()
	)
