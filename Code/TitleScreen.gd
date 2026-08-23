extends Control

func _ready() -> void:
	var tex = $TextureRect
	if ResourceLoader.exists("res://Assets/title_bg.png"):
		tex.texture = load("res://Assets/title_bg.png")
		
	var logo_rect = get_node_or_null("LogoRect")
	if logo_rect and ResourceLoader.exists("res://Assets/logo.png"):
		logo_rect.texture = load("res://Assets/logo.png")
		$TitleLabel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		get_tree().change_scene_to_file("res://Scenes/IntroCutscene.tscn")
