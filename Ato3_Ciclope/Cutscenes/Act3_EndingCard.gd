extends CanvasLayer

@onready var title_lbl: Label = $ColorRect/VBox/TitleLabel
@onready var desc_lbl: Label = $ColorRect/VBox/DescLabel
@onready var prompt_lbl: Label = $ColorRect/PromptLabel

var can_continue: bool = false

func _ready() -> void:
	preload("res://Code/CinematicCardBackdrop.gd").attach(self, "res://Assets/cinematics/ship_deck.png")
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
	if event.is_pressed() and not event.is_echo() and not event.is_action_pressed("ui_cancel"):
		if can_continue:
			var viewport := get_viewport()
			if viewport:
				viewport.set_input_as_handled()
			can_continue = false
			var tween = create_tween()
			tween.tween_property($ColorRect, "modulate:a", 0.0, 1.0)
			tween.tween_callback(func():
				get_tree().change_scene_to_file("res://Ato4_Tempestade/Cutscenes/Act4_StormCutscene.tscn")
			)
