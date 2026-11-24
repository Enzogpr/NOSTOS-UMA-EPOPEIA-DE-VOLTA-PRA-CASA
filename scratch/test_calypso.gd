extends SceneTree

const PATHS := preload("res://Ato10_Calipso/Gameplay/OgygiaPaths.gd")
const RAFT := preload("res://Ato10_Calipso/Gameplay/RaftLaunch.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const PATH_SCENE := "res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn"
const RAFT_SCENE := "res://Ato10_Calipso/Gameplay/CalypsoDeparture.tscn"
const STEP := 1.0 / 120.0
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func advance_dialogue(scene: Control) -> void:
	for index in scene.beats.size():
		scene._process(0.8)
		scene.advance_story()

func visit(paths: PATHS, destination: Vector2) -> void:
	for index in 1200:
		var offset := destination - paths.position
		if offset.length() < 7.0:
			return
		paths.tick(STEP, (offset / 24.0).limit_length(), false)

func interact(scene: Control) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	scene._unhandled_input(event)

func work_at_bench(scene: Control, duration: float) -> void:
	for index in ceili(duration / STEP):
		scene.paths.tick(STEP, Vector2.ZERO, true)
	scene._update_hud()

func navigate_escape(raft: RAFT) -> void:
	for index in 6000:
		if raft.phase != RAFT.Phase.AFLOAT:
			return
		var ahead := raft.distance + 56.0
		var target := raft.channel_center(ahead)
		for reef in raft.reefs():
			var closeness := 1.0 - smoothstep(65.0, 176.0, absf(ahead - reef.y))
			var center := raft.channel_center(reef.y)
			var direction := -1.0 if reef.x > center else 1.0
			var clear_side := reef.x + direction * (reef.z + 36.0)
			target = lerpf(target, clear_side, closeness)
		var axis := clampf((target - raft.lateral - raft.side_speed * 0.11) / 33.0, -1.0, 1.0)
		raft.tick(STEP, axis, -0.05, false)

func test_escape_routes() -> void:
	for route: int in [RAFT.COVE, RAFT.OPEN]:
		var idle := RAFT.new()
		idle.begin_escape(route)
		for index in 4200:
			if idle.phase != RAFT.Phase.AFLOAT:
				break
			idle.tick(STEP, 0.0, 0.0, false)
		check(idle.phase == RAFT.Phase.SHORE, "Route %d requires active steering" % route)
		for speed: float in [0.3, 1.0, 1.7]:
			var raft := RAFT.new()
			raft.apply_stats({"speed_mult": speed, "intellect": 5})
			raft.begin_escape(route)
			navigate_escape(raft)
			check(raft.phase == RAFT.Phase.ARRIVED, "Route %d is navigable at speed %.1f" % [route, speed])


func tied_raft(beach: int) -> RAFT:
	var raft := RAFT.new()
	raft.choose_beach(beach)
	for frame in 95:
		raft.tick(STEP, 0.0, 0.0, true)
	return raft

func navigate(raft: RAFT, stop_at: float = RAFT.FINISH) -> void:
	var points := [Vector2(0, 0), Vector2(288, 0), Vector2(556, -66), Vector2(874, 93), Vector2(1155, 5), Vector2(1540, 0)]
	for frame in 3600:
		if raft.phase != RAFT.Phase.AFLOAT or raft.distance >= stop_at:
			return
		var ahead := raft.distance + 45.0
		var target := raft.channel_center(ahead)
		if raft.beach == RAFT.COVE:
			for index in range(1, points.size()):
				if ahead <= points[index].x:
					var from: Vector2 = points[index - 1]
					var to: Vector2 = points[index]
					target = lerpf(from.y, to.y, inverse_lerp(from.x, to.x, ahead))
					break
		var steer := clampf((target - raft.lateral - raft.side_speed * 0.12) / 38.0, -1.0, 1.0)
		raft.tick(STEP, steer, 0.0, false)

func capture(scene: Control, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene.stage.update_view(0.21, scene.paths.can_work() and scene.paths.work > 0.0)
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(OS.get_environment("TEMP").path_join("nostos_calypso_" + name + ".png"))

func check_saved_progress() -> void:
	var saved := MANAGER.new()
	saved.save_file_path = OS.get_environment("TEMP").path_join("nostos_ogygia_%d.json" % Time.get_ticks_usec())
	var old := FileAccess.open(saved.save_file_path, FileAccess.WRITE)
	old.store_string(JSON.stringify({
		"highest_unlocked_level": 9, "player_age": 38, "player_current_hp": 5,
		"circe_moly_found": true, "circe_search_completed": true, "circe_battle_completed": true,
		"underworld_crossing_completed": true, "underworld_vision_index": 3,
		"underworld_prophecy_completed": true, "sirens_completed": true,
		"scylla_completed": true, "mutiny_completed": true,
	}))
	old.close()
	check(saved.load_game() and saved.highest_unlocked_level == 10 and not saved.ogygia_paths_completed, "A completed Motim save opens Ogígia without awarding a victory")
	saved.complete_ogygia_paths()
	saved.complete_calypso()
	saved.reset()
	check(not saved.ogygia_paths_completed and not saved.calypso_completed, "A new campaign clears both milestones")
	check(saved.load_game() and saved.ogygia_paths_completed and saved.calypso_completed and saved.player_age == 47 and saved.player_current_hp == 2 and saved.sacrificed_years == 18, "Migration preserves sacrificed years and applies nine natural years once")
	DirAccess.remove_absolute(saved.save_file_path)
	saved.free()

func run() -> void:
	var manager: MANAGER = root.get_node("GameManager")
	if manager.standalone_stage_preview:
		var path := PATH_SCENE if PATH_SCENE in OS.get_cmdline_args() else RAFT_SCENE
		var preview: Control = load(path).instantiate()
		preview.audio_enabled = false
		root.add_child(preview)
		check(not manager.persistence_enabled and preview.mode == preview.Mode.STORY, "Direct startup opens this scene without campaign progress or saves")
		preview.queue_free()
		await process_frame
		print("CALYPSO STANDALONE: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	manager.persistence_enabled = false
	manager.reset()
	manager.player_current_hp = 4
	manager.player_age = 33
	manager.complete_ogygia_paths()
	manager.complete_calypso()
	check(not manager.ogygia_paths_completed and not manager.calypso_completed, "Completion requires the prior campaign milestone")
	manager.scylla_completed = true
	manager.complete_mutiny(4)
	check(manager.highest_unlocked_level == 10, "The Motim unlocks Act X")
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check(map.stops.size() == 12 and map.destination("ogygia").is_unlocked() and not map.DATA.chapter_unlocked(map.destination("ogygia").chapters[1]), "One Ogigia pin opens captivity while keeping the departure locked")
	check(map.destination("ogygia").chapters[0].scene == PATH_SCENE and map.destination("ogygia").chapters[1].scene == RAFT_SCENE, "Both Ogigia chapters keep independent scenes inside the same destination")
	check(map.destination("ogygia").real_name == "Ogígia · Calipso", "Calypso has one named island on the map")
	map.queue_free()
	await process_frame

	test_escape_routes()
	for told: bool in [false, true]:
		var previously_unlocked := manager.ogygia_paths_completed
		var scene: Control = load(PATH_SCENE).instantiate()
		scene.audio_enabled = false
		root.add_child(scene)
		current_scene = scene
		scene.set_physics_process(false)
		scene.set_process(false)
		advance_dialogue(scene)
		check(scene.mode == scene.Mode.WALK and scene.paths.beat == PATHS.Beat.SALVAGE and scene.progress.text.is_empty(), "The player starts on the beach without a year HUD")
		var paths: PATHS = scene.paths
		await capture(scene, "oar_beach")
		visit(paths, PATHS.WRECK)
		interact(scene)
		check(paths.beat == PATHS.Beat.CARVE, "Odisseu recovers recognisable fleet timber")
		visit(paths, PATHS.HOUSE)
		interact(scene)
		var hold := InputEventKey.new()
		hold.physical_keycode = KEY_E
		hold.pressed = true
		Input.parse_input_event(hold)
		Input.flush_buffered_events()
		scene._physics_process(0.25)
		check(paths.work > 0.0, "Holding physical E advances the work through the scene controller")
		var release := InputEventKey.new()
		release.physical_keycode = KEY_E
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		work_at_bench(scene, 1.75)
		check(paths.place == PATHS.Place.BENCH and paths.work > 0.5 and paths.oar_condition == -1, "The player's input shapes the first oar")
		if not told:
			await capture(scene, "oar_bench_first")
		work_at_bench(scene, 1.0)
		check(paths.beat == PATHS.Beat.CARVED and paths.place == PATHS.Place.BENCH, "Odisseu can linger and see the completed oar")
		interact(scene)
		check(paths.beat == PATHS.Beat.CAST and paths.oar_condition == 0 and paths.place == PATHS.Place.SHORE, "The finished oar and character go back to the same beach")

		var origin := 1 if told else 0
		visit(paths, PATHS.CURRENTS[origin])
		interact(scene)
		check(paths.beat == PATHS.Beat.DRIFT and paths.cast_route == origin, "Either current can take the marked timber")
		var launch_at := paths.marker_position()
		paths.tick(3.35, Vector2.ZERO, false)
		check(paths.marker_position().y < launch_at.y - 100.0, "The tracer visibly drifts out to sea")
		paths.tick(3.8, Vector2.ZERO, false)
		check(paths.beat == PATHS.Beat.RECOVER and paths.marker_position().distance_to(PATHS.CURRENTS[1 - origin]) < 20.0, "The exact marker returns by the opposite shore")
		visit(paths, paths.marker_position())
		interact(scene)
		if told:
			visit(paths, PATHS.CALYPSO)
			interact(scene)
			check(paths.told_calypso and scene.mode == scene.Mode.STORY, "Telling Calipso is an actual optional conversation")
			advance_dialogue(scene)
		visit(paths, PATHS.HOUSE)
		interact(scene)
		work_at_bench(scene, 1.45)
		check(paths.time_cut > 0.0 and paths.place == PATHS.Place.BENCH, "The first jump in time starts during the work gesture")
		var working_progress := paths.work
		paths.tick(0.9, Vector2.ZERO, false)
		check(paths.seasons > 0.0 and paths.work == working_progress, "Time advances while the same gesture and framing remain")
		work_at_bench(scene, 5.0)
		interact(scene)
		check(paths.beat == PATHS.Beat.LAUNCH and paths.seasons == 3.0, "Preparing the grip takes Odisseu back to the changed beach")
		check(manager.player_age == (38 if not previously_unlocked else 42), "The first three island years reach campaign age without charging a replay")
		visit(paths, PATHS.CURRENTS[origin])
		interact(scene)
		check(scene.mode == scene.Mode.ESCAPE and scene.raft.beach == origin, "The chosen coast changes the playable crossing")
		scene.restart_checkpoint()
		check(scene.mode == scene.Mode.WALK and paths.beat == PATHS.Beat.LAUNCH and paths.oar_condition == 0, "Retry keeps the oar and the choice about Calipso")
		visit(paths, PATHS.CURRENTS[origin])
		interact(scene)
		var reef: Vector3 = scene.raft.reefs()[0]
		scene.raft.distance = reef.y - 1.0
		scene.raft.lateral = reef.x
		scene._physics_process(0.02)
		check(scene.mode == scene.Mode.WALK and paths.beat == PATHS.Beat.LAUNCH and not scene.note.text.is_empty(), "A real collision returns control on the beach")
		visit(paths, PATHS.CURRENTS[origin])
		interact(scene)
		if not told:
			await capture(scene, "oar_escape")
		navigate_escape(scene.raft)
		check(scene.mode == scene.Mode.RETURN_CURRENT and manager.ogygia_paths_completed == previously_unlocked, "A successful voyage reaches the reveal, before the story unlock")
		scene._process(4.5)
		if not told:
			await capture(scene, "oar_return")
		scene._process(2.0)
		check(scene.mode == scene.Mode.WALK and paths.beat == PATHS.Beat.REUNION and paths.oar_condition == 1, "Ogígia returns the player to shore with a visibly damaged oar")
		visit(paths, paths.reunion_position())
		interact(scene)
		check(scene.mode == scene.Mode.STORY and scene.stage.shot == ("return" if told else "bench_return"), "The player finds the appropriate Calipso reunion by their own actions")
		if not told:
			await capture(scene, "oar_reunion")
		advance_dialogue(scene)
		visit(paths, PATHS.HOUSE)
		interact(scene)
		work_at_bench(scene, 5.15)
		check(paths.seasons == 7.0 and paths.oar_condition == 2 and paths.place == PATHS.Place.BENCH, "The same bench shows seven marks and the worn-out, broken oar")
		check(manager.player_age == 42, "All seven years are applied during the visible time cuts, without duplicate replay aging")
		work_at_bench(scene, 2.0)
		check(paths.beat == PATHS.Beat.LEAVE_TOOLS, "The player gets a quiet moment to decide to put the tools down")
		if not told:
			await capture(scene, "oar_bench_late")
		interact(scene)
		visit(paths, PATHS.PATH)
		interact(scene)
		check(paths.place == PATHS.Place.HEADLAND, "Odisseu walks the headland without a platforming challenge")
		visit(paths, PATHS.OVERLOOK)
		check(scene.mode == scene.Mode.STORY and scene.stage.shot == "cliff", "The player reaches Calipso and the call to Atena")
		if not told:
			advance_dialogue(scene)
			check(scene.mode == scene.Mode.DONE and manager.ogygia_paths_completed, "Zeus's decision, rather than the escape attempt, unlocks the departure")
		scene.queue_free()
		await process_frame


	var raft := tied_raft(RAFT.OPEN)
	check(is_equal_approx(raft.lash, 1.0), "Holding the interaction ties the raft")
	raft.clock = 2.0
	raft.launch()
	check(raft.phase == RAFT.Phase.SHORE and raft.shore_delay > 0.0, "A sideways launch washes the raft ashore")
	raft.retry()
	raft.angle = RAFT.TARGET[RAFT.OPEN]
	raft.clock = 0.2
	raft.launch()
	check(raft.phase == RAFT.Phase.SHORE and raft.shore_delay > 0.0 and raft.lash == 1.0, "Launching against the tide fails and preserves the ropes")
	for beach in [RAFT.COVE, RAFT.OPEN]:
		for speed in [0.3, 1.0, 1.7]:
			raft = tied_raft(beach)
			raft.apply_stats({"speed_mult": speed, "intellect": 5})
			raft.angle = RAFT.TARGET[beach]
			raft.clock = 2.0
			raft.launch()
			navigate(raft)
			check(raft.phase == RAFT.Phase.ARRIVED, "Beach %d is passable at speed %.1f" % [beach, speed])
	raft = tied_raft(RAFT.COVE)
	raft.angle = RAFT.TARGET[RAFT.COVE]
	raft.launch()
	raft.lateral = RAFT.ROCKS[0].x
	raft.distance = RAFT.ROCKS[0].y
	raft.tick(STEP, 0.0, 0.0, false)
	check(raft.phase == RAFT.Phase.SHORE and raft.lash == 1.0, "Hitting a reef returns the raft to the beach")

	var scene: Control = load(RAFT_SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.set_process(false)
	await capture(scene, "farewell")
	advance_dialogue(scene)
	await capture(scene, "shore")
	scene.raft.choose_beach(RAFT.OPEN)
	scene.raft.tick(0.8, 0.0, 0.0, true)
	scene.raft.clock = 2.0
	scene.raft.angle = RAFT.TARGET[RAFT.OPEN]
	scene.raft.launch()
	scene._update_hud()
	await capture(scene, "channel")
	navigate(scene.raft, RAFT.FINISH - 3.0)
	scene._update_hud()
	var before_arrival: String = scene.progress.text
	scene._physics_process(0.07)
	check(scene.mode == scene.Mode.STORY and scene.stage.shot == "hermes" and not manager.calypso_completed, "Clearing the surf triggers the Hermes scene before saving")
	check(not scene.hud.visible and scene.progress.text == before_arrival, "The frame that opens Hermes's cutscene leaves the sailing HUD alone")
	await capture(scene, "hermes")
	advance_dialogue(scene)
	check(scene.mode == scene.Mode.DONE and manager.calypso_completed, "Completing the conversation records Ogígia")
	check(manager.player_age == 42 and manager.player_current_hp == 4 and manager.story_years() == 9, "Seven Ogigia years age the campaign once and preserve existing wounds")
	check_saved_progress()
	scene.queue_free()
	await process_frame
	print("CALYPSO: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
