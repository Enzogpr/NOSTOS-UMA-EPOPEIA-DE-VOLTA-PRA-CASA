extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const PILOT := preload("res://scratch/PoseidonEscapePilot.gd")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var scene: Control
var completions: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func snapshot(name: String) -> void:
	scene._update_interface()
	scene.visuals.fleet_stage.focus = scene.model.position.x
	scene.visuals.update_visuals(0.01)
	if not capture: return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	frame.save_png("res://scratch/poseidon_fleet_preview/"+name+".png")
	var color: Color = frame.get_pixel(1100,350)
	check(color.r+color.g+color.b > 0.1,"The real environment must render in "+name)

func final_model() -> MODEL:
	var m := MODEL.new()
	m.phase = MODEL.Phase.SURVIVAL
	m.act_index = 2
	m.has_bag = true
	m.bag_secured = true
	m.position = MODEL.HELM
	m.clock = 10
	for i in 11: m.sunk_at[i] = 10
	return m

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://scratch/poseidon_fleet_preview")
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var hp: int = GameManager.player_current_hp
	var inventory: Array = GameManager.inventory.duplicate(true)
	var m := MODEL.new()
	m.tick(10,Vector2.RIGHT,true,true)
	check(m.phase == MODEL.Phase.READY and m.position == MODEL.START,"The introduction must wait for explicit start.")
	m.start()
	m.position = m.launch_point()
	m.tick(0.02,Vector2.ZERO,false,true)
	check(not m.airborne and m.route_index == 0,"Rushing the bow cannot skip the opening attack sequence.")
	m.tick(0.2,Vector2.RIGHT)
	check(m.position.x <= m.route_rect().end.x,"Walking cannot cross the ocean gap without a jump.")
	m = MODEL.new()
	m.start()
	for i in 900:
		m.tick(0.05)
		if m.phase == MODEL.Phase.FAILED: break
	check(m.phase == MODEL.Phase.FAILED and m.hits >= 3,"Standing still must fail through real attacks, not safely wait for the escape.")
	check(m.completion_count == 0 and m.phase != MODEL.Phase.COMPLETE,"Taking repeated hits must never produce an automatic victory.")
	check("INTERROMPIDA" in m.objective() and not "ESCAPOU" in m.objective(),"The failure interface must not claim that the captain escaped.")
	var frozen: float = m.clock
	m.tick(20)
	check(m.phase == MODEL.Phase.FAILED and m.clock == frozen,"A failed attempt must wait for the player's retry decision.")
	m.retry_checkpoint()
	check(m.phase == MODEL.Phase.TRAVERSAL and m.balance == 100 and m.route_index == 0,"Retry must restore the current passage without a death scene.")
	m = final_model()
	m._begin_final()
	check(m.phase == MODEL.Phase.SURVIVAL and not m.fleet_gone(),"Counting eleven losses must not allow escape while their destruction is still visible.")
	m.clock += MODEL.WRECK_SECONDS+0.01
	m._begin_final()
	check(m.phase == MODEL.Phase.FINAL_ATTACK and m.fleet_gone(),"The final release must unlock only after every wreck finishes sinking.")
	m.tick(6.6,Vector2.ZERO,true)
	check(m.wind_progress == 0,"Holding interaction from before the opening must not trigger the wind automatically.")
	m.tick(0.03)
	m.tick(1,Vector2.ZERO,true)
	check(m.phase == MODEL.Phase.ESCAPING,"A fresh held interaction inside the opening must release the wind.")
	m.completed.connect(func(_data): completions += 1)
	m.tick(20)
	m.tick(20)
	check(completions == 1 and m.record().acts_completed == 3,"Completion and the final result must fire exactly once.")
	m = final_model()
	m.clock += 5
	m._begin_final()
	m.tick(11)
	check(m.phase == MODEL.Phase.FAILED and m.fleet_remaining() == 1,"Missing the wind opening must fail the attempt without reviving the destroyed fleet.")
	m.retry_checkpoint()
	check(m.phase == MODEL.Phase.FINAL_ATTACK and m.fleet_gone(),"Retrying the release must retain the completed traversal, acts and destroyed fleet.")
	# Full defended runs: real movement, all jumps, all mandatory attacks, no health cheats.
	for seed_value in [614,88,441]:
		var route := MODEL.new(seed_value)
		var pilot := PILOT.new()
		route.start()
		var seen: Dictionary = {}
		var own_arrival: float = 0
		for i in 8000:
			var command: Dictionary = pilot.controls(route)
			route.tick(0.05,command.direction,command.interact,command.dash)
			if route.phase == MODEL.Phase.ARRIVAL and own_arrival == 0: own_arrival = route.clock
			seen["%d_%d" % [route.phase,route.act_index]] = true
			if route.phase == MODEL.Phase.FAILED and route.retries < 3:
				route.retry_checkpoint()
				pilot = PILOT.new()
			elif route.phase in [MODEL.Phase.COMPLETE,MODEL.Phase.FAILED]: break
		check(route.phase == MODEL.Phase.COMPLETE,"The defended route must be playable for seed "+str(seed_value))
		check(route.clock >= 175 and own_arrival >= 60,"Both playable parts must have substance, rather than another forty-second bag run.")
		check(route.jumps == 3 and route.route_index == 3,"All three physical crossings must be required.")
		check(route.resolved_attacks >= 36 and seen.has("3_0") and seen.has("3_1") and seen.has("3_2"),"All three deck acts and their attack sequences must be played.")
		check(route.fleet_gone() and route.fleet_remaining() == 1 and route.mast_broken,"The ending must retain one ship and the damage caused by Poseidon.")
		print("DEFENDED RUN ",seed_value,": ",route.record())
	await _scene_checks()
	var save_after: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	check(save_before == save_after and hp == GameManager.player_current_hp and inventory == GameManager.inventory,"The new failure/retry rules must preserve campaign health, save and inventory.")
	print("POSEIDON FLEET: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)

func _scene_checks() -> void:
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	scene = preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.audio_enabled = false
	scene.persist_record = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.4).timeout
	await snapshot("01_intro")
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await get_tree().process_frame
	check(scene.model.phase == MODEL.Phase.TRAVERSAL,"Enter must start the actual traversal.")
	var from: Vector2 = scene.model.position
	key(KEY_D,true)
	Input.flush_buffered_events()
	scene._process(0.25)
	key(KEY_D,false)
	check(scene.model.position.x > from.x+25,"Keyboard movement must reach the actual character model.")
	scene.set_process(false)
	var pilot := PILOT.new()
	var captures: Dictionary = {}
	for i in 5200:
		var command: Dictionary = pilot.controls(scene.model)
		scene.model.tick(0.05,command.direction,command.interact,command.dash)
		var title: String = ""
		if scene.model.landing_pause > 0.6 and scene.model.landing_pause < 1.0: title = "14_ship_crushed"
		if scene.model.route_index == 0 and scene.model.phase_clock > 11 and not scene.model.airborne: title = "02_traversal"
		if scene.model.airborne and scene.model.flight_age > 0.45: title = "03_jump" if scene.model.route_index == 0 else "04_rope" if scene.model.route_index == 1 else "05_last_crossing"
		if scene.model.phase == MODEL.Phase.SURVIVAL:
			if scene.model.act_index == 0 and scene.model.phase_clock > 11: title = "06_own_ship_bag"
			if scene.model.act_index == 1 and scene.model.phase_clock > 9: title = "07_broken_mast"
			if scene.model.act_index == 1 and scene.model.phase_clock > 28.4: title = "13_rope_defense"
			if scene.model.act_index == 2 and scene.model.phase_clock > 3: title = "08_final_assault"
		if scene.model.phase == MODEL.Phase.FINAL_ATTACK: title = "09_fleet_destroyed"
		if scene.model.phase == MODEL.Phase.ESCAPING and scene.model.phase_clock > 2.5: title = "10_wind_escape"
		if not title.is_empty() and not captures.has(title):
			captures[title] = true
			await snapshot(title)
		if scene.model.phase in [MODEL.Phase.COMPLETE,MODEL.Phase.FAILED]: break
	check(scene.model.phase == MODEL.Phase.COMPLETE and scene.result.visible,"The rendered route must finish with the result panel.")
	await snapshot("11_result")
	check(scene.visuals.deck.texture == preload("res://Assets/act4_poseidon_escape/deck_broken.png") and not scene.visuals.mast.visible,"Poseidon's mast destruction must change the actual artwork and remove its shelter.")
	check(scene.visuals.escape_ship.visible and scene.visuals.deck.modulate.a < 0.01,"The last ship must physically sail away after the full fleet destruction.")
	check(scene.balance_bar.size.y <= 10 and scene.action_bar.size.y <= 10,"The HUD bars must not cover their instructions.")
	scene.set_process(true)
	var visual_clock: float = scene.visuals.elapsed
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await get_tree().create_timer(0.15,true).timeout
	check(get_tree().paused and scene.visuals.elapsed == visual_clock,"Pause must freeze both visual and gameplay clocks.")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	get_viewport().size = Vector2i(800,1000)
	await get_tree().process_frame
	check(scene.stage.scale.x < 0.7 and scene.stage.position.y > 200,"Tall windows must preserve both arenas and their controls.")
	get_viewport().size = Vector2i(1152,648)
	scene.queue_free()
	await get_tree().process_frame
	# Actual predecessor handoff, then a real failure panel and keyboard retry.
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	previous.audio_enabled = false
	previous.handoff_record = {"voyage":42}
	get_tree().root.add_child(previous)
	get_tree().current_scene = previous
	await get_tree().create_timer(1.4).timeout
	previous._finish()
	await get_tree().process_frame
	scene = get_tree().current_scene
	scene.persist_record = false
	await get_tree().create_timer(0.8).timeout
	check(scene.name == "PoseidonEscape" and scene.handoff_record.get("voyage") == 42 and not is_instance_valid(previous),"The cinematic must hand off to the new first part and retain its voyage record.")
	scene.begin()
	for i in 4: scene.model._hit("crush")
	check(scene.failure_panel.visible and scene.model.phase == MODEL.Phase.FAILED,"Losing balance must show a retry decision, not an automatic recovery.")
	await snapshot("12_retry")
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await get_tree().process_frame
	check(scene.model.phase == MODEL.Phase.TRAVERSAL and not scene.failure_panel.visible,"Enter must resume only the current checkpoint.")
	scene.stop_audio()
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
