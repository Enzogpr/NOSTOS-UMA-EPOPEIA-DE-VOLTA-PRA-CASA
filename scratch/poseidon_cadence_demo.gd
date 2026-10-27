extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
const PILOT := preload("res://scratch/PoseidonCadencePilot.gd")
var scene: Control
var pilot := PILOT.new()
var active: bool = false
var finishing: bool = false
var demo_clock: float = 0.0
var failure_delay: float = 0.0
var key_states: Dictionary = {}
var model_input := false
var diagnostic_mark := -1

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	previous.autoplay = false
	previous.audio_enabled = not "--silent" in OS.get_cmdline_user_args()
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
	scene.manual_score_clock = true
	scene.score.set_process(false)
	model_input = "--model-input" in OS.get_cmdline_user_args()
	if model_input:
		scene.score.deterministic=true
		scene.allow_input=false
		scene.set_physics_process(false)
	active = true
	if "--final-only" in OS.get_cmdline_user_args() and model_input:
		# Render only the final encounter after an input-only traversal rehearsal.
		var audible: bool=scene.score.enabled
		scene.score.enabled=false
		for voice in scene.score.voices: voice.stop()
		scene.encounter_audio.stop_audio()
		for frame in 60*180:
			if scene.model.phase==MODEL.Phase.FINAL_SHIP: break
			_physics_process(1.0/60)
			if scene.model.phase==MODEL.Phase.FAILED:
				push_error("The final-only preview could not rehearse its approach")
				get_tree().quit(1)
				return
		var snapshot: Dictionary=scene.score.get_snapshot()
		scene.score.enabled=audible
		scene.score.restore(snapshot)
		scene.encounter_audio.setup(scene.audio_enabled)
		scene.visuals.reset_camera()

func _key(code: Key, pressed: bool) -> void:
	if key_states.get(code,false) == pressed: return
	key_states[code] = pressed
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _physics_process(delta: float) -> void:
	if not model_input or not active or finishing or scene.model.phase==MODEL.Phase.FAILED: return
	var c: Dictionary=pilot.controls(scene.model)
	scene.score.advance(delta)
	scene.model.set_score_time(maxf(0,scene.score.absolute_time))
	scene.model.escape_score_age=scene.score.section_elapsed if scene.score.section=="escape" else -1.0
	scene.model.set_combat_input(c.get("attack",false),c.get("guard",false))
	scene.model.tick(delta,c.move,c.duck,c.jump,c.held,c.interact)
	scene._update_interface()
	if is_instance_valid(scene.encounter_audio):
		scene.encounter_audio.update_state(scene.model.tension,scene.model.quiet,scene.model.velocity.x,scene.model.grounded)

func _process(delta: float) -> void:
	if not active or finishing: return
	demo_clock += delta
	var mark:=int(demo_clock/20)
	if mark!=diagnostic_mark:
		diagnostic_mark=mark
		print("DEMO_PROGRESS ",demo_clock," model=",scene.model.clock," phase=",scene.model.phase," position=",scene.model.position," boat=",scene.model.visited_boat," kills=",scene.model.boarding.kills," retries=",scene.model.retries)
	if scene.model.phase == MODEL.Phase.FAILED:
		failure_delay += delta
		if failure_delay > 1.5:
			if model_input: scene.retry_checkpoint()
			else:
				_key(KEY_ENTER,true)
				_key(KEY_ENTER,false)
			failure_delay = 0
		return
	if scene.model.phase==MODEL.Phase.CINEMATIC and is_instance_valid(scene.aftermath_scene):
		scene.aftermath_scene.advance(delta)
	if not model_input:
		var controls: Dictionary = pilot.controls(scene.model)
		_key(KEY_D,controls.move > 0.2)
		_key(KEY_A,controls.move < -0.2)
		_key(KEY_S,controls.duck)
		_key(KEY_W,false)
		_key(KEY_E,controls.interact)
		_key(KEY_SHIFT,controls.get("guard",false))
		_key(KEY_J,controls.get("attack",false))
		if controls.jump: _key(KEY_SPACE,false)
		_key(KEY_SPACE,controls.held)
	if scene.model.phase == MODEL.Phase.COMPLETE:
		finishing = true
		_finish_demo()
	elif demo_clock > 260:
		print("DEMO_FAILURE ",scene.model.record()," pos=",scene.model.position," boarding=",scene.model.boarding.snapshot())
		push_error("Escape demo did not complete its commanded route.")
		get_tree().quit(1)

func _finish_demo() -> void:
	for code in [KEY_D,KEY_A,KEY_S,KEY_W,KEY_E,KEY_SPACE,KEY_J,KEY_SHIFT,KEY_Q]: _key(code,false)
	print("CADENCE MOVIE: ","model commands" if model_input else "actual keyboard events","; ",scene.model.record())
	await get_tree().create_timer(2.4).timeout
	scene.stop_audio()
	await get_tree().create_timer(0.15).timeout
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
