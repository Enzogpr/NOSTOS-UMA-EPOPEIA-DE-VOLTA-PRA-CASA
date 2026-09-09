extends CanvasLayer

@onready var title_lbl: Label = $ColorRect/VBox/TitleLabel
@onready var desc_lbl: Label = $ColorRect/VBox/DescLabel
@onready var prompt_lbl: Label = $ColorRect/PromptLabel

var can_continue: bool = false

func _ready() -> void:
	title_lbl.modulate.a = 0.0
	desc_lbl.modulate.a = 0.0
	prompt_lbl.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(title_lbl, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.0)
	tween.tween_property(desc_lbl, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.5)
	tween.tween_property(prompt_lbl, "modulate:a", 1.0, 0.8)
	tween.tween_callback(func(): can_continue = true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if can_continue:
			can_continue = false
			var tween = create_tween()
			tween.tween_property($ColorRect, "modulate:a", 0.0, 1.0)
			tween.tween_callback(func():
				get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
			)
