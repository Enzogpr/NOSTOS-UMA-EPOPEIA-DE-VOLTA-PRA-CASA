extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const PILOT := preload("res://scratch/PoseidonEscapePilot.gd")
var scene: Control
var pilot := PILOT.new()
var active: bool = false
var finishing: bool = false
var demo_clock: float = 0.0
var failure_delay: float = 0.0

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	previous.autoplay = false
	get_tree().root.add_child(previous)
	get_tree().current_scene = previous
	await get_tree().create_timer(1.1).timeout
	previous._show_beat(previous.beats.size()-1)
	previous.can_advance = true
	previous.autoplay = true
	for frame in 600:
		if get_tree().current_scene.name == "PoseidonEscape": break
		await get_tree().process_frame
	scene = get_tree().current_scene
	if scene.name != "PoseidonEscape":
		push_error("Escape demo: cinematic handoff did not complete.")
		get_tree().quit(1)
		return
	scene.persist_record = false
	await get_tree().create_timer(2.5).timeout
	scene.begin()
	active = true

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _process(delta: float) -> void:
	if not active or finishing: return
	demo_clock += delta
	if scene.model.phase == MODEL.Phase.FAILED:
		failure_delay += delta
		if failure_delay > 1.5:
			_key(KEY_ENTER,true)
			_key(KEY_ENTER,false)
			failure_delay = 0
		return
	var controls: Dictionary = pilot.controls(scene.model)
	_key(KEY_D,controls.direction.x > 0.2)
	_key(KEY_A,controls.direction.x < -0.2)
	_key(KEY_S,controls.direction.y > 0.2)
	_key(KEY_W,controls.direction.y < -0.2)
	_key(KEY_E,controls.interact)
	_key(KEY_SPACE,controls.dash)
	if scene.model.phase == MODEL.Phase.COMPLETE:
		finishing = true
		_finish_demo()
	elif demo_clock > 400:
		push_error("Escape demo did not complete the actual keyboard-driven route.")
		get_tree().quit(1)

func _finish_demo() -> void:
	for code in [KEY_D,KEY_A,KEY_S,KEY_W,KEY_E,KEY_SPACE]: _key(code,false)
	print("ESCAPE MOVIE: actual keyboard route complete; ",scene.model.record())
	await get_tree().create_timer(2.4).timeout
	scene.stop_audio()
	await get_tree().create_timer(0.15).timeout
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
