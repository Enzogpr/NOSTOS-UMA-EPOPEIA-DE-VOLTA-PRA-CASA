extends Control

## Cartão de Título: Ato III - A Ilha do Ciclope

@onready var text1: Label = $Text1
@onready var text2: Label = $Text2

func _ready() -> void:
	text1.modulate.a = 0
	text2.modulate.a = 0
	_play_sequence()

func _play_sequence() -> void:
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(text1, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.0)
	tween.tween_property(text1, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	tween.tween_property(text2, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.5)
	tween.tween_property(text2, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.tscn")
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		get_tree().change_scene_to_file("res://Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.tscn")
