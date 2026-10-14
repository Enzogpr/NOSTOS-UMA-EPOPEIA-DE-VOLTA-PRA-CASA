extends Node
func _input(_event: InputEvent) -> void:
	# A recording must keep every supplied line even if keys/clicks arrive.
	get_viewport().set_input_as_handled()

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var scene: Control = preload("res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn").instantiate()
	scene.autoplay = true
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await scene.conversation_finished
	await get_tree().create_timer(2.0).timeout
	print("FRIENDS DEMO: completed at Tentaremos")
	get_tree().quit()
