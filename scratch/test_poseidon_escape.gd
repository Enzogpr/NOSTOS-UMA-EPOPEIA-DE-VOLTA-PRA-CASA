extends Node
const M := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const PILOT := preload("res://scratch/PoseidonEscapePilot.gd")
var checks := 0
var failures := 0
var capture := false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func advance(m: M, seconds: float, move := 0.0, duck := false, jump := false, held := false, interact := false) -> void:
	for frame in int(seconds*120):
		m.tick(1.0/120,move,duck,jump and frame == 0,held,interact)

func fresh() -> M:
	var m := M.new()
	m.start()
	return m

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var m := M.new()
	m.tick(1,1,false,true,true)
	check(m.phase == M.Phase.READY and m.position == Vector2(145,480),"The intro must wait for explicit start.")
	m.start()
	check(m.boats.size() == 11 and m.platforms.size() == 45,"Ten intermediate boats, the captain's boat, thirty wrecks and four raised ledges must exist.")
	advance(m,0.4,1)
	check(m.velocity.x == 325 and m.position.x > 230,"Horizontal running must accelerate to the configured speed.")
	advance(m,0.2,-1)
	check(m.velocity.x < 0,"The player must be able to brake and turn back.")
	var high := fresh()
	var low := fresh()
	var high_y := high.position.y
	var low_y := low.position.y
	for frame in 100:
		high.tick(1.0/120,0,false,frame==0,true)
		low.tick(1.0/120,0,false,frame==0,frame<4)
		high_y = minf(high_y,high.position.y)
		low_y = minf(low_y,low.position.y)
	check(high_y < 340 and low_y > 420,"Holding jump must produce a controllable higher arc.")
	check(high.grounded and high.position.y == 480,"A jump must land on the actual deck collision surface.")
	var no_double := high.jumps
	high.tick(0.1,0,false,true,true)
	high.tick(0.1,0,false,true,true)
	check(high.jumps == no_double+1,"There must be no air jump.")
	var edge := fresh()
	edge.position.x = 487
	advance(edge,0.045,1)
	edge.tick(0.01,1,false,true,true)
	check(edge.velocity.y < -500,"Coyote time must accept a jump just after leaving the edge.")
	var fall := fresh()
	advance(fall,5,1)
	check(fall.phase == M.Phase.FAILED and not fall.record().escaped,"Running into a gap must fail, never snap to the next boat.")
	var stopped: Vector2 = fall.position
	fall.tick(5,1,false,true,true)
	check(fall.position == stopped and fall.phase == M.Phase.FAILED,"Failure must wait for an explicit retry.")
	fall.retry_checkpoint()
	check(fall.phase == M.Phase.TRAVERSAL and fall.position == Vector2(145,480) and fall.retries == 1,"Retry must restore the safe boat, not auto-rescue in place.")
	var beam := fresh()
	var r: Rect2 = beam.obstacles.filter(func(o): return o.kind == "beam")[0].rect
	beam.position = Vector2(r.position.x-30,r.end.y+59)
	beam.phase = M.Phase.TRAVERSAL
	advance(beam,0.3,1)
	check(beam.position.x <= r.position.x-M.HALF_WIDTH+1,"Standing collision must block the low beam.")
	beam.position = Vector2(r.position.x+30,r.end.y+59)
	beam.crouching = true
	beam.grounded = true
	beam.tick(0.01,0,false)
	check(beam.crouching and not beam.can_stand(),"Releasing crouch under a beam cannot expand into the ceiling.")
	var wave := fresh()
	wave._spawn_attack("high",0)
	wave.hazards[0].warning = 0.0
	wave.hazards[0].x = 160
	advance(wave,0.2,0,true)
	check(wave.hits == 0 and wave.ducked_attacks == 1,"Crouching must physically clear a high sweep.")
	var hit := fresh()
	hit._spawn_attack("high",0)
	hit.hazards[0].warning = 0.0
	hit.hazards[0].x = 160
	advance(hit,0.1)
	check(hit.hits == 1 and hit.balance == 72 and hit.position.x < 145,"The same sweep must hit and push a standing character.")
	var wreck := fresh()
	wreck.position = wreck.platform_rect(11).get_center()-Vector2(0,9)
	wreck.support = 11
	advance(wreck,5.6)
	check(wreck.platforms[11].gone,"A used wreck must warn and sink rather than remain an eternal safe spot.")
	var idle := fresh()
	advance(idle,25)
	check(idle.phase == M.Phase.FAILED and idle.sunk_at[0] >= 0,"Waiting forever must let Poseidon destroy the actual support.")
	_mechanic_checks()
	_run_route()
	if capture: await _scene_checks()
	print("POSEIDON PLATFORM: ",checks," checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _mechanic_checks() -> void:
	var buffered := fresh()
	buffered.position.y = 458
	buffered.velocity.y = 220
	buffered.grounded = false
	buffered.support = -1
	advance(buffered,0.14,0,false,true,true)
	check(buffered.jumps == 1 and buffered.velocity.y < 0,"A jump pressed shortly before landing must be buffered.")
	var fast := fresh()
	var slow := fresh()
	for i in 36: fast.tick(1.0/60,1,false,i==0,true)
	for i in 72: slow.tick(1.0/120,1,false,i==0,true)
	check(fast.position.distance_to(slow.position) < 0.5,"Movement and jump collision must agree across frame rates.")
	var crouch := fresh()
	advance(crouch,0.4,1,true)
	check(crouch.velocity.x == 138 and crouch.body_rect().size.y == M.CROUCH_HEIGHT,"Crouching must use its own speed and collider, not a dodge animation.")
	var low := fresh()
	advance(low,0.2,0,false,true,true)
	low._spawn_attack("low",0)
	low.hazards[0].warning = 0
	low.hazards[0].x = 160
	advance(low,0.15,0,false,false,true)
	check(low.hits == 0,"An airborne character must physically clear a low wave.")
	var slam := fresh()
	slam._spawn_attack("slam",0)
	var marked_x: float = slam.hazards[0].target
	advance(slam,0.4,1)
	check(slam.hazards[0].target == marked_x and slam.position.x > marked_x+50,"The slam warning must remain fixed while the player moves away.")
	var final := fresh()
	final.position = final.boats[10].rect.position+Vector2(50,0)
	final._enter_boat(10)
	final.position = final.bag_point
	final._final_interaction(1,true)
	check(not final.has_bag,"The bag cannot be claimed before freeing all three bindings.")
	final.bindings.assign([1.0,1.0,1.0])
	final.mast_broken = true
	final._final_interaction(1,true)
	check(final.has_bag and final.checkpoint.has_bag,"Claiming the bag must establish the return checkpoint.")
	final._fail("test")
	final.retry_checkpoint()
	check(final.has_bag and final.bindings_done() == 3 and final.phase == M.Phase.FINAL_SHIP,"Final retry must retain the earned bag and freed bindings.")
	final.position = final.exit_point
	final.grounded = true
	final._final_interaction(1,true)
	check(final.phase == M.Phase.FINAL_SHIP,"The player cannot escape while any fleet ship is still afloat.")
	for i in 11: final._sink(i)
	final._final_interaction(1,true)
	check(final.phase == M.Phase.FINAL_SHIP,"Counting sunk ships cannot skip their visible wreckage animation.")
	final.clock += 4.1
	final._final_interaction(1,true)
	check(final.phase == M.Phase.ESCAPING,"Completing the platform objective must trigger escape without waiting for arbitrary attack acts.")
	advance(final,6)
	advance(final,6)
	check(final.completion_count == 1 and final.fleet_remaining() == 1,"The new escape must finish once with only the captain's ship remaining.")

func _run_route() -> void:
	var m := fresh()
	var pilot := PILOT.new()
	var last_boat := -1
	for frame in 24000:
		var c: Dictionary = pilot.controls(m)
		m.tick(1.0/60,c.move,c.duck,c.jump,c.held,c.interact)
		if m.visited_boat != last_boat:
			last_boat = m.visited_boat
			print("PILOT BOAT ",last_boat," at ",snappedf(m.clock,0.1)," x ",m.position)
		if m.phase in [M.Phase.FAILED,M.Phase.COMPLETE]: break
	check(m.phase == M.Phase.COMPLETE,"The full course must be completable using only the actual move, crouch, jump and interaction inputs.")
	check(m.visited_boat == 10 and m.bindings_done() == 3 and m.has_bag,"Completion must include all ten boats and the final objective.")
	check(m.fleet_remaining() == 1 and m.completion_count == 1,"The last boat alone must escape; completion emits once.")
	print("PLATFORM RUN ",m.record()," position ",m.position," phase ",m.phase," reason ",m.failure_reason)

func _scene_checks() -> void:
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var record_before: PackedByteArray = FileAccess.get_file_as_bytes("user://poseidon_escape_record.json") if FileAccess.file_exists("user://poseidon_escape_record.json") else PackedByteArray()
	var health_before: int = GameManager.player_current_hp
	var inventory_before: Array = GameManager.inventory.duplicate(true)
	var scene: Control = preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.proof_enabled = false
	scene.persist_record = false
	scene.audio_enabled = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	scene.ready_delay = 0
	scene.begin()
	scene.set_physics_process(false)
	var pilot := PILOT.new()
	var captured := {}
	for frame in 24000:
		var c: Dictionary = pilot.controls(scene.model)
		scene.model.tick(1.0/60,c.move,c.duck,c.jump,c.held,c.interact)
		scene.notice_time = maxf(0,scene.notice_time-1.0/60)
		var title := ""
		if scene.model.visited_boat == 0 and scene.model.clock > 1: title = "01_first_boat"
		if scene.model.support >= 0 and scene.model.platforms[scene.model.support].kind == "wreck": title = "02_wrecks"
		if scene.model.crouching: title = "03_crouch"
		if scene.model.visited_boat == 5: title = "04_middle"
		if scene.model.visited_boat == 9: title = "05_tenth_boat"
		if scene.model.phase == M.Phase.FINAL_SHIP: title = "06_final_ship" if scene.model.bindings_done() < 2 else "07_broken_mast"
		if scene.model.has_bag: title = "08_bag"
		if scene.model.phase == M.Phase.ESCAPING: title = "09_escape"
		if scene.model.sunk_at[0] >= 0 and scene.model.clock-scene.model.sunk_at[0] > 0.4 and scene.model.clock-scene.model.sunk_at[0] < 0.6: title = "10_ship_destroyed"
		if not title.is_empty() and not captured.has(title):
			captured[title] = true
			scene._update_interface()
			scene.visuals.reset_camera()
			scene.visuals.update_visuals(0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://scratch/poseidon_platform_preview/"+title+".png")
		if scene.model.phase in [M.Phase.FAILED,M.Phase.COMPLETE]: break
	check(scene.model.phase == M.Phase.COMPLETE and scene.result.visible,"Rendered route must finish through the same controller completion signal.")
	check(captured.size() >= 8,"Visual QA must include wrecks, crouch, the final ship and escape.")
	check(scene.complete_count == 1,"The controller must persist and emit completion only once.")
	var save_after: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var record_after: PackedByteArray = FileAccess.get_file_as_bytes("user://poseidon_escape_record.json") if FileAccess.file_exists("user://poseidon_escape_record.json") else PackedByteArray()
	check(save_before == save_after and record_before == record_after and GameManager.player_current_hp == health_before and GameManager.inventory == inventory_before,"Preview and failure must preserve campaign health, inventory, save and the existing escape record.")
	scene.model._change(M.Phase.TRAVERSAL)
	scene.model._fail("Teste de retomada")
	check(scene.failure_panel.visible,"A fall must show the retry panel through the real controller signal.")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	scene._unhandled_key_input(event)
	check(scene.model.active() and not scene.failure_panel.visible,"Enter must explicitly resume the checkpoint.")
	scene.set_physics_process(true)
	await get_tree().physics_frame
	get_tree().paused = true
	var before_pause: float = scene.model.clock
	var before_visual: float = scene.visuals.elapsed
	await get_tree().create_timer(0.12,true).timeout
	check(scene.model.clock == before_pause and scene.visuals.elapsed == before_visual,"Pausing must freeze physics and all platform visuals.")
	get_tree().paused = false
	get_viewport().size = Vector2i(800,1000)
	await get_tree().process_frame
	check(scene.stage.scale.x < 0.7 and scene.stage.position.y > 200,"Tall windows must preserve the complete platform camera and HUD.")
	scene.queue_free()
	await get_tree().process_frame
