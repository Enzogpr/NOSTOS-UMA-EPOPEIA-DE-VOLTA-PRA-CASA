extends Node
func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	var game: Control = preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn").instantiate()
	game.persist_record = false
	game.autoplay_thoughts = false
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(0.4).timeout
	game.begin()
	game.model.day = 9
	game.model.fatigue = 100.0
	game.model.tick(0.01)
	await get_tree().create_timer(0.12).timeout
	if game.sounds.storm.playing or not game.sounds.ambient.playing:
		push_error("The thoughts must start quietly, without released winds.")
		get_tree().quit(1)
		return
	game._show_thought(4)
	await get_tree().create_timer(0.12).timeout
	if not game.sounds.storm.playing:
		push_error("Released winds must start with Penelope's warning.")
		get_tree().quit(1)
		return
	game._show_thought(6)
	await get_tree().create_timer(1.4).timeout
	if game.sounds.storm.volume_db < -20.0 or game.sounds.ending_shot != "cry":
		push_error("The storm must swell as the illustrated real deck returns.")
		get_tree().quit(1)
		return
	game._show_thought(13)
	if game.sounds.storm_target_db != -29.0:
		push_error("Closing the remaining winds must soften the storm.")
		get_tree().quit(1)
		return
	game._show_thought(15)
	await get_tree().create_timer(1.5).timeout
	if game.sounds.storm.volume_db > -35.0 or game.sounds.ending_shot != "presence":
		push_error("The sea must quiet down for the unidentified voice.")
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
	print("VIGIL AUDIO: 6 checks; 0 failures")
	get_tree().quit()
