extends Node
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/ReleasedWindsPreview.tscn").instantiate()
	previous.persist_record = false
	previous.autoplay_thoughts = false
	get_tree().root.add_child(previous)
	get_tree().current_scene = previous
	await get_tree().create_timer(0.65).timeout
	previous._show_thought(previous.thoughts.size()-1)
	previous.autoplay_thoughts = true
	for frame in 600:
		if get_tree().current_scene.name == "Ruthlessness": break
		await get_tree().process_frame
	var scene: Control = get_tree().current_scene
	if scene.name != "Ruthlessness":
		push_error("Poseidon demo: the preceding cutscene did not hand off.")
		get_tree().quit(1)
		return
	await scene.cinematic_finished
	await get_tree().create_timer(2.0).timeout
	print("POSEIDON MOVIE: predecessor handoff, all supplied lines and first impact complete")
	scene.stop_audio()
	await get_tree().create_timer(0.15).timeout
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
