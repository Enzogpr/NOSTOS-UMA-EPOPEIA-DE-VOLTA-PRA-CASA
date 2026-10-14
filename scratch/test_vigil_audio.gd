extends Node
func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	var game: Control = preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn").instantiate()
	game.persist_record = false
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.4).timeout
	game.begin()
	game.model.day = 9
	game.model.state = game.MODEL.State.ENDING
	game.model.ending_clock = 8.0
	await get_tree().create_timer(0.12).timeout
	if not game.sounds.storm.playing or not game.sounds.ambient.playing:
		push_error("Final wind and sea audio must be active.")
		get_tree().quit(1)
		return
	game.sounds.stop()
	await get_tree().create_timer(0.15).timeout
	if game.sounds.storm.playing or game.sounds.ambient.playing or game.sounds.storm.stream != null:
		push_error("Leaving the scene must release its audio players.")
		get_tree().quit(1)
		return
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("VIGIL AUDIO: 2 checks; 0 failures")
	get_tree().quit()
