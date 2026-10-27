extends Node
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var game: Control = preload("res://Ato4_Tempestade/Cutscenes/ReleasedWindsPreview.tscn").instantiate()
	game.continue_to_poseidon = false
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await game.vigilance_completed
	await get_tree().create_timer(3.0).timeout
	print("RELEASED WINDS DEMO: last warning, storm and unidentified voice complete")
	game.sounds.stop()
	await get_tree().create_timer(0.15).timeout
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
