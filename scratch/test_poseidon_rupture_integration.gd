extends Node
const R := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureModel.gd")
const P := preload("res://scratch/PoseidonRupturePilot.gd")
var checks := 0
var failures := 0
var emitted := 0
var capture := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture = "--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var save_before := bytes(GameManager.SAVE_FILE_PATH)
	var record_before := bytes("user://poseidon_escape_record.json")
	var health: int = GameManager.player_current_hp
	var inventory: Array = GameManager.inventory.duplicate(true)
	var combat_before: bool = GameManager.combat_mode
	GameManager.combat_mode = true
	var scene: Control = preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.audio_enabled = false
	scene.persist_record = false
	scene.handoff_record = {"story_complete":true,"proof_test":"handoff"}
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.4).timeout
	check(scene.model is R and scene.intro.visible,"The campaign entry must select the new proof scene without discarding the intro.")
	scene.ready_delay = 0
	scene.escaped.connect(func(_record): emitted += 1)
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await get_tree().create_timer(0.05).timeout
	check(scene.model.active() and not scene.intro.visible,"Enter must start the actual encounter controller.")
	key(KEY_D,true)
	await get_tree().create_timer(0.14).timeout
	key(KEY_D,false)
	await get_tree().physics_frame
	check(scene.model.position.x > 150,"Real keyboard events must move Odysseus through the controller physics loop.")
	key(KEY_S,true)
	await get_tree().create_timer(0.04).timeout
	check(scene.model.crouching,"The actual controller must map S to crouch.")
	key(KEY_S,false)
	scene.set_physics_process(false)
	scene.visuals.set_process(false)
	var pilot := P.new()
	var captured := {}
	for frame in 6000:
		var c: Dictionary = pilot.controls(scene.model)
		scene.model.tick(1.0/60,c.move,c.duck,c.jump,c.held,false)
		scene.visuals.update_visuals(1.0/60)
		var state: String = scene.model.encounter_state
		var title := ""
		if state == "foreboding" and scene.model.position.x > 450: title = "01_foreboding"
		if state == "fracture" and scene.model.event_age > 1.25: title = "02_fracture"
		if state == "retreat": title = "03_retreat"
		if state == "mast_fall" and scene.model.event_age > 0.8: title = "04_mast_fall"
		if state == "crossing" and scene.model.position.x > 700: title = "05_ramp"
		if state == "pursuit" and scene.model.position.x > 2270: title = "06_pursuit"
		if state == "pursuit" and scene.model.position.x > 3800: title = "07_fragments"
		if state == "safe": title = "08_refuge"
		if state == "finished": title = "09_complete"
		if capture and not title.is_empty() and not captured.has(title):
			captured[title] = true
			scene._update_interface()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://scratch/poseidon_rupture_preview/"+title+".png")
		if scene.model.phase in [R.Phase.COMPLETE,R.Phase.FAILED]: break
	check(scene.model.phase == R.Phase.COMPLETE and scene.result.visible,"The rendered route must finish via the real result signal and panel.")
	check(scene.model.retreated and scene.model.ducked_sail and scene.model.crossed_ramp and scene.model.mobile_landings >= 5,"The complete run must use the intended retreat, sail clearance, ramp and moving wrecks.")
	check(emitted == 0 and not scene.model.record().escaped,"Finishing a proof must never emit campaign escape or claim the entire boss phase is complete.")
	check(scene.complete_count == 1,"The proof result must only be shown once.")
	check(save_before == bytes(GameManager.SAVE_FILE_PATH) and record_before == bytes("user://poseidon_escape_record.json") and health == GameManager.player_current_hp and inventory == GameManager.inventory,"Preview must preserve campaign health, inventory and saved records.")
	if capture: check(captured.size() >= 8,"Capture route must cover fracture, mast, ramp, pursuit and refuge.")
	# Explicit fail/retry panel, followed by a pause check on an active model.
	scene.model._change(R.Phase.TRAVERSAL)
	scene.model._fail("Teste de retorno")
	check(scene.failure_panel.visible,"Failure must show the explicit retry panel.")
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await get_tree().process_frame
	check(scene.model.active() and not scene.failure_panel.visible,"Enter must resume the safe checkpoint through the real input handler.")
	scene.set_physics_process(true)
	scene.visuals.set_process(true)
	await get_tree().physics_frame
	get_tree().paused = true
	var before_clock: float = scene.model.clock
	var before_visual: float = scene.visuals.elapsed
	await get_tree().create_timer(0.12,true).timeout
	check(scene.model.clock == before_clock and scene.visuals.elapsed == before_visual,"Pause must freeze collision, encounter and visual clocks.")
	get_tree().paused = false
	get_viewport().size = Vector2i(800,1000)
	await get_tree().process_frame
	check(scene.stage.scale.x < 0.7 and scene.stage.position.y > 200,"The new encounter must retain the existing letterbox fit in tall windows.")
	get_viewport().size = Vector2i(1152,648)
	scene._continue_legacy(3)
	await get_tree().process_frame
	var next: Control = get_tree().current_scene
	check(not next.proof_enabled and next.legacy_start_boat == 3 and next.handoff_record.proof_test == "handoff","Continuing must keep the voyage record and select the remaining legacy traversal.")
	check(not GameManager.combat_mode and next.previous_combat,"Transfer must leave the next scene in control and retain the original combat restoration value.")
	next.ready_delay = 0
	next.begin()
	check(next.model.visited_boat == 3 and next.model.position.x > 3900,"Continuation must start at the next surviving ship instead of replaying the three lost ships.")
	next.random_seed = 93721
	next.allow_input = false
	var replay_handoff: Dictionary = next.handoff_record.duplicate(true)
	next.replay()
	await get_tree().process_frame
	var replayed: Control = get_tree().current_scene
	check(not replayed.proof_enabled and replayed.legacy_start_boat == 3 and not replayed.audio_enabled and not replayed.persist_record,"Replaying the legacy continuation must keep its mode, starting boat and disabled audio/persistence configuration.")
	check(replayed.random_seed == 93721 and not replayed.allow_input and replayed.handoff_record == replay_handoff,"Replay must preserve the explicit seed, input policy and incoming narrative record.")
	replayed.ready_delay = 0
	replayed.begin()
	check(replayed.model.visited_boat == 3 and replayed.model.position.x > 3900,"A repeated legacy continuation must again start on its configured surviving boat.")
	replayed.stop_audio()
	replayed.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.combat_mode,"Leaving the final owner must restore the original combat mode exactly once.")
	GameManager.combat_mode = combat_before
	print("RUPTURE INTEGRATION: ",checks," checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)
