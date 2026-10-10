extends Control

## Cartão de Título: Ato II - A Ilha dos Lotófagos

@onready var text1: Label = $Text1
@onready var text2: Label = $Text2

func _ready() -> void:
	preload("res://Code/CinematicCardBackdrop.gd").attach(self, "res://Assets/cinematics/lotus_shore.png")
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
		get_tree().change_scene_to_file("res://Ato2_Lotofagos/Cutscenes/Act2_VoyageCutscene.tscn")
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and not event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://Ato2_Lotofagos/Cutscenes/Act2_VoyageCutscene.tscn")
