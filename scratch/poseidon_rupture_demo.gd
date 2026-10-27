extends Node
const R := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureModel.gd")
var scene: Control
var pilot := preload("res://scratch/PoseidonRupturePilot.gd").new()
var key_states: Dictionary = {}
var active := false
var finishing := false
var demo_clock := 0.0
var frame_times: Array[float] = []

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
	if scene.name != "PoseidonEscape" or not scene.proof_enabled:
		push_error("The real Morra handoff did not open the rupture encounter.")
		get_tree().quit(1)
		return
	scene.persist_record = false
	await get_tree().create_timer(1.8).timeout
	scene.ready_delay = 0
	scene.begin()
	active = true

func _key(code: Key, down: bool) -> void:
	if key_states.get(code,false) == down: return
	key_states[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _process(dt: float) -> void:
	if not active or finishing: return
	demo_clock += dt
	if "--profile" in OS.get_cmdline_user_args(): frame_times.append(dt)
	if scene.model.phase == R.Phase.FAILED:
		push_error("Keyboard proof route failed: "+scene.model.failure_reason)
		get_tree().quit(1)
		return
	var c: Dictionary = pilot.controls(scene.model)
	_key(KEY_D,c.move > 0.18)
	_key(KEY_A,c.move < -0.18)
	_key(KEY_S,c.duck)
	if c.jump: _key(KEY_SPACE,false)
	_key(KEY_SPACE,c.held)
	if scene.model.phase == R.Phase.COMPLETE:
		finishing = true
		_finish()
	elif demo_clock > 90:
		push_error("Keyboard proof route timed out.")
		get_tree().quit(1)

func _finish() -> void:
	for code in [KEY_D,KEY_A,KEY_S,KEY_SPACE]: _key(code,false)
	print("RUPTURE MOVIE: keyboard-only route completed; ",scene.model.record())
	if not frame_times.is_empty():
		frame_times.sort()
		print("NORMAL CLOCK PROFILE: ",frame_times.size()," frames; median ",snappedf(frame_times[frame_times.size()/2]*1000,0.01)," ms; p95 ",snappedf(frame_times[int(frame_times.size()*0.95)]*1000,0.01)," ms; max ",snappedf(frame_times[-1]*1000,0.01)," ms")
	await get_tree().create_timer(1.8).timeout
	scene.stop_audio()
	await get_tree().create_timer(0.2).timeout
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
