extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const PILOT := preload("res://scratch/PoseidonEscapePilot.gd")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var completions: int = 0
var scene: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func clean_model() -> MODEL:
	var model := MODEL.new(440)
	model.start()
	model.next_attack = 1000
	return model

func snapshot(title: String) -> void:
	scene._update_interface()
	scene.visuals.update_visuals(0)
	if not capture: return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.save_png("res://scratch/poseidon_escape_preview/"+title+".png")
	var world: Color = frame.get_pixel(1100,350)
	check(world.r+world.g+world.b > 0.15,"The actual sea/deck must render in "+title)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://scratch/poseidon_escape_preview")
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var record_before: PackedByteArray = FileAccess.get_file_as_bytes("user://poseidon_escape_record.json") if FileAccess.file_exists("user://poseidon_escape_record.json") else PackedByteArray()
	var health_before: int = GameManager.player_current_hp
	var inventory: Array = GameManager.inventory.duplicate(true)
	var model := MODEL.new()
	model.tick(5,Vector2.RIGHT,true,true)
	check(model.phase == MODEL.Phase.READY and model.position == MODEL.START,"The introduction must not move or attack before the player starts.")
	model.start()
	model.next_attack = 1000
	model.tick(0.7,Vector2.RIGHT)
	check(model.position.x > MODEL.START.x+100,"Walking must respond continuously.")
	model.tick(20,Vector2(1,1))
	check(MODEL.WALK_AREA.has_point(model.position-Vector2.ONE*0.01),"Deck edges must keep the captain aboard.")
	model.position = MODEL.MAST+Vector2(-90,0)
	model.tick(0.3,Vector2.RIGHT)
	check(((model.position-MODEL.MAST)/Vector2(58,30)).length() >= 0.99,"The captain must collide with the mast footprint.")
	model.position = MODEL.MAST-Vector2(0,22)
	model.tick(0.1,Vector2.DOWN)
	check(model.position.y >= MODEL.WALK_AREA.position.y,"Mast correction must never push the captain off the playable deck.")
	model = clean_model()
	model.position = Vector2(920,500)
	model.spawn_attack("jets")
	var target: Vector2 = model.hazards[0].points[0]
	model.tick(1.2)
	check(model.hits == 0,"Jet warnings must be harmless before their announced strike.")
	model.tick(0.2)
	check(model.hits == 1 and model.stagger > 0,"A jet must knock back an exposed captain.")
	model.tick(0.2)
	check(model.hits == 1,"One jet strike must not damage every frame.")
	check(target == model.hazards[0].points[0],"Jet markers must lock their positions, not track the player's escape.")
	model = clean_model()
	model.spawn_attack("jets")
	model.tick(1.1,Vector2.RIGHT)
	model.tick(0.5,Vector2.RIGHT,false,true)
	check(model.hits == 0 and model.dodges == 1,"Movement and dodge must allow the player to escape announced jets.")
	var dodge_count: int = model.dodges
	model.tick(0.05,Vector2.RIGHT,false,true)
	check(model.dodges == dodge_count,"Dodge must respect its cooldown.")
	model = clean_model()
	model.position = Vector2(485,485)
	model.spawn_attack("sweep")
	model.tick(4.5)
	check(model.hits == 0 and model.sheltered(),"The lee of the mast must protect against the complete sweep.")
	check(model.fleet_remaining() == 11,"The fleet must suffer an impact even when the player defends successfully.")
	model = clean_model()
	model.position = Vector2(900,510)
	model.spawn_attack("sweep")
	model.tick(4.4)
	check(model.hits == 1 and model.position.x < 900,"An unprotected sweep must visibly push the captain backward.")
	model = clean_model()
	model.position = MODEL.ANCHORS[1]
	model.spawn_attack("hoof")
	model.tick(3.9,Vector2.ZERO,true)
	check(model.hits == 0 and model.bracing,"Holding a nearby rope must resist the horse impact.")
	model = clean_model()
	model.spawn_attack("hoof")
	model.tick(4)
	check(model.hits == 1,"The hoof impact must knock down an unbraced captain.")
	for i in 16:
		model.invulnerable = 0
		model._hit("hoof")
		model.tick(0.2)
	check(model.active() and model.balance > 0 and model.position.y <= MODEL.WALK_AREA.end.y,"Repeated impacts must never kill the captain or remove him from the ship.")
	model = clean_model()
	model.position = MODEL.BAG-Vector2(20,0)
	model.tick(1.5,Vector2.ZERO,true)
	var progress: float = model.bag_progress
	check(progress > 0.4 and not model.has_bag,"The trapped bag must take deliberate interaction to free.")
	model._hit("jets")
	model.tick(2)
	check(model.bag_progress == progress,"A hit must interrupt interaction while preserving the cords already freed.")
	model.position = MODEL.BAG-Vector2(20,0)
	model.tick(2,Vector2.ZERO,true)
	check(model.has_bag and model.phase == MODEL.Phase.RETURN,"Finishing the cords must put the bag in the captain's hands and change the objective.")
	model.invulnerable = 0
	model._hit("hoof")
	check(model.has_bag,"A carrying knockdown must not lose or reopen the recovered bag.")
	model.tick(2)
	model.position = MODEL.HELM
	model.tick(0.1,Vector2.ZERO,true)
	check(model.phase == MODEL.Phase.FINAL_ATTACK,"The final strike must start through interaction at the helm.")
	model.tick(11.6)
	check(model.phase == MODEL.Phase.RETURN and model.has_bag and model.completion_count == 0,"Missing the final opening must require another attempt, with no automatic escape or death.")
	check(model.fleet_remaining() == 1,"Every other ship must be lost by the final attack.")
	model.tick(2)
	model.position = MODEL.HELM
	model.tick(0.1,Vector2.ZERO,true)
	model.tick(7.8,Vector2.ZERO,true)
	check(model.phase == MODEL.Phase.FINAL_ATTACK and model.wind_progress == 0,"Holding the bag before the opening must not release the winds early.")
	model.tick(1.3,Vector2.ZERO,true)
	check(model.phase == MODEL.Phase.FINAL_ATTACK and model.wind_progress == 0,"Holding E continuously before the opening must not cause an automatic timed release.")
	model.tick(0.05)
	model.tick(0.95,Vector2.ZERO,true)
	check(model.phase == MODEL.Phase.ESCAPING and model.fleet_remaining() == 1,"Holding E during the opening must cause the last ship to escape.")
	model.completed.connect(func(_record): completions += 1)
	model.tick(10)
	model.tick(10)
	check(completions == 1 and model.completion_count == 1 and model.record().escaped,"The escape and its result must complete exactly once.")
	# Full playable route: objective movement and defense, with no teleports or invulnerability.
	for seed_value in [614,88,441]:
		var route := MODEL.new(seed_value)
		var pilot := PILOT.new()
		route.start()
		for i in 1400:
			var controls: Dictionary = pilot.controls(route)
			route.tick(0.05,controls.direction,controls.interact,controls.dash)
			if route.phase == MODEL.Phase.COMPLETE: break
		check(route.phase == MODEL.Phase.COMPLETE,"An ordinary defended route must be completable for seed "+str(seed_value))
		check(route.hits < 10 and route.fleet_remaining() == 1,"A defended route must remain fair and still lose the fleet, seed "+str(seed_value))
		print("ESCAPE ROUTE ",seed_value,": ",route.clock,"s; ",route.hits," hits; phase ",route.phase)
	await _scene_checks()
	var save_after: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var record_after: PackedByteArray = FileAccess.get_file_as_bytes("user://poseidon_escape_record.json") if FileAccess.file_exists("user://poseidon_escape_record.json") else PackedByteArray()
	check(save_before == save_after and record_before == record_after and inventory == GameManager.inventory and health_before == GameManager.player_current_hp,"QA, handoff and escape must preserve campaign health, saves, inventory and existing records.")
	print("POSEIDON ESCAPE: ",checks," checks; ",failures," failures")
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
	check(scene.balance_bar.size.y <= 10 and scene.action_bar.size.y <= 10,"Progress bars must remain thin and must not overlap prompts or extend beyond the footer.")
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await get_tree().process_frame
	check(scene.model.phase == MODEL.Phase.APPROACH and not scene.intro.visible,"Enter must start actual gameplay and dismiss the introduction.")
	var first: Vector2 = scene.model.position
	key(KEY_D,true)
	Input.flush_buffered_events()
	scene._process(0.3)
	key(KEY_D,false)
	check(scene.model.position.x > first.x+30,"The real keyboard must move the on-screen character.")
	scene.set_process(false)
	scene.model.next_attack = 1000
	scene.model.combo_due = -1.0
	scene.model.position = Vector2(485,490)
	scene.model.spawn_attack("sweep")
	await snapshot("02_mast_cover")
	scene.model.hazards.clear()
	scene.model.position = Vector2(905,510)
	scene.model.spawn_attack("jets")
	scene.model.hazards[0].age = 0.8
	await snapshot("03_jet_warning")
	scene.model.hazards[0].age = 1.55
	await snapshot("04_jets")
	scene.model.hazards.clear()
	scene.model.position = MODEL.ANCHORS[2]
	scene.model.spawn_attack("hoof")
	scene.model.tick(2.5,Vector2.ZERO,true)
	await snapshot("05_rope_guard")
	scene.model.hazards.clear()
	scene.model.position = MODEL.BAG-Vector2(40,0)
	scene.model.tick(1.2,Vector2.ZERO,true)
	await snapshot("06_free_bag")
	scene.model.tick(2.5,Vector2.ZERO,true)
	scene.model.position = Vector2(720,535)
	scene.model.velocity = Vector2(-172,0)
	scene.visuals.update_visuals(0.3)
	await snapshot("07_carry")
	check(scene.visuals.player_frame in [4,5,6,7],"Carrying must use the dedicated costume-preserving bag movement frames.")
	scene.model.velocity = Vector2.ZERO
	scene.model.position = MODEL.HELM
	scene.model.tick(0.1,Vector2.ZERO,true)
	scene.model.tick(8.1)
	await snapshot("08_final_window")
	scene.model.tick(1,Vector2.ZERO,true)
	scene.model.tick(2.5)
	await snapshot("09_wind_escape")
	check(scene.visuals.escape_ship.visible and scene.visuals.deck.modulate.a < 0.01,"The ending must show the last ship physically moving away under the winds.")
	scene.model.tick(4.5)
	await snapshot("10_result")
	check(scene.complete_count == 1 and scene.result.visible,"The final result must report the single surviving ship.")
	scene.set_process(true)
	var clock: float = scene.visuals.elapsed
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await get_tree().create_timer(0.15,true).timeout
	check(get_tree().paused and scene.visuals.elapsed == clock,"Esc must pause the world and gameplay together.")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await get_tree().process_frame
	get_viewport().size = Vector2i(800,1000)
	await get_tree().process_frame
	check(scene.stage.scale.x < 0.7 and scene.stage.position.y > 200,"The scene must letterbox in tall windows without stretching.")
	get_viewport().size = Vector2i(1152,648)
	scene.queue_free()
	await get_tree().process_frame
	# Real cinematic endpoint -> playable scene, no end card in between.
	var music_before: float = AudioManager.music_player.volume_db
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	previous.audio_enabled = true
	previous.handoff_record = {"test_voyage":42}
	get_tree().root.add_child(previous)
	get_tree().current_scene = previous
	await get_tree().create_timer(1.4).timeout
	previous._finish()
	await get_tree().process_frame
	scene = get_tree().current_scene
	scene.persist_record = false
	await get_tree().create_timer(0.8).timeout
	check(scene.name == "PoseidonEscape" and not is_instance_valid(previous),"The first impact must continue directly to the playable escape and release the cinematic.")
	check(scene.handoff_record.get("test_voyage") == 42 and scene.model.phase == MODEL.Phase.READY,"The voyage record must survive handoff and wait for the player.")
	check(scene.ambience.playing and is_equal_approx(scene.previous_music_volume,music_before),"The storm ambience must start after handoff without stacking music attenuation.")
	scene.stop_audio()
	await get_tree().create_timer(0.15).timeout
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(AudioManager.music_player.volume_db,music_before),"Leaving the escape must restore the original music volume.")
