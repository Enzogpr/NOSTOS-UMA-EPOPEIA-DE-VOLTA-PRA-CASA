extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
var game: Control
var demo_clock: float = 0.0
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	game = preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn").instantiate()
	# A shorter demo uses the same model and controls; campaign days stay at 25 s.
	game.day_duration = 9.0
	game.random_seed = 9044
	game.persist_record = false
	game.continue_to_poseidon = false
	game.vigilance_failed.connect(func(_reason: String):
		push_error("The demo must survive the first eight days.")
		get_tree().quit(1))
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(2.0).timeout
	game.begin()
	await game.vigilance_completed
	await get_tree().create_timer(2.0).timeout
	print("VIGIL DEMO: nine abbreviated days and final scene complete")
	game.sounds.stop()
	await get_tree().create_timer(0.15).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _process(delta: float) -> void:
	if game == null or game.model.state != MODEL.State.PLAYING:
		return
	demo_clock += delta
	if game.model.fatigue >= MODEL.WAKE_START:
		game.model.wake()
	var urgent: Dictionary = {}
	for visitor in game.model.crew:
		if not visitor.retreating and (urgent.is_empty() or visitor.progress > urgent.progress):
			urgent = visitor
	if not urgent.is_empty() and float(urgent.progress) > 0.19:
		game.model.look(int(urgent.side))
		game.model.warn_crew()
