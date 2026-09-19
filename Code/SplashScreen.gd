extends Control

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var bg_rect: TextureRect = $BGTexture

func _ready() -> void:
	if ResourceLoader.exists("res://Assets/loading_bg.png"):
		bg_rect.texture = load("res://Assets/loading_bg.png")
	elif ResourceLoader.exists("res://Assets/loading_bg.jpg"):
		bg_rect.texture = load("res://Assets/loading_bg.jpg")
		
	progress_bar.value = 0.0
	
	var tween = create_tween()
	# Simula um carregamento artificial de 15 segundos
	tween.tween_property(progress_bar, "value", 100.0, 15.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		var fade = create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 1.0)
		fade.tween_callback(func():
			get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
		)
	)
