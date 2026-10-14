extends Node
## Record the actual automatic sequence, including its transition to ascent.

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var scene: Control = preload("res://Ato4_Tempestade/Cutscenes/LuckRunsOut.tscn").instantiate()
	scene.autoplay = true
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await scene.conversation_finished
	await get_tree().create_timer(5.5).timeout
	print("LUCK DEMO: dialogue and ascent complete")
	get_tree().quit()
