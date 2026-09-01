extends Control

@onready var text1: Label = $Text1
@onready var text2: Label = $Text2

func _ready() -> void:
	text1.modulate.a = 0
	text2.modulate.a = 0
	_play_sequence()

func _play_sequence() -> void:
	var tween = create_tween()
	
	# Aguarda 1 segundo na tela preta
	tween.tween_interval(1.0)
	
	# Fade in texto 1 ("ATO II")
	tween.tween_property(text1, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.0)
	
	# Fade out texto 1
	tween.tween_property(text1, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	
	# Fade in texto 2 ("ESTAÇÃO 2: A ILHA DOS LOTÓFAGOS")
	tween.tween_property(text2, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.5)
	
	# Fade out texto 2
	tween.tween_property(text2, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	
	# Transição para a Estação 2 (A Ilha dos Lotófagos)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Scenes/Station2_LotusEaters.tscn")
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		get_tree().change_scene_to_file("res://Scenes/Station2_LotusEaters.tscn")
