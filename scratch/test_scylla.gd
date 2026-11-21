extends SceneTree

const RUN := preload("res://Ato8_Cila/Gameplay/ScyllaRun.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const SCENE := "res://Ato8_Cila/Gameplay/ScyllaPassage.tscn"
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func advance(run: RUN, seconds: float, forward := true) -> void:
	for _frame in ceili(seconds / STEP):
		run.tick(STEP, forward)

func snapshot(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var folder := "res://scratch/campaign_review/scylla"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func verify() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.persistence_enabled = false
	var run := RUN.new()
	advance(run, 2.0)
	check(run.distance == 0.0 and run.torches == 6, "The boat waits for the handoff from the cinematic")
	run.restart()
	advance(run, 1.0)
	var past := run.distance
	advance(run, 1.0, false)
	check(run.speed == 0.0 and run.distance > past, "Releasing forward lets momentum carry the boat briefly before stopping")
	past = run.distance
	advance(run, 2.0, false)
	check(run.distance == past and run.torches == 6, "Waiting in place never triggers a later attack")

	run.distance = RUN.ATTACKS[0].x
	run.speed = 0.0
	advance(run, 0.6, false)
	check(run.lunges[0].age > RUN.OPENING and run.torch_strength(0) < 0.8 and run.torch_strength(0) > 0.0 and run.torches == 6,
		"The targeted flame dims during the approach")
	check(run.torch_strength(1) == 1.0, "An attack only dims the flame it targets")
	advance(run, 0.44, false)
	check(run.torches == 5 and run.torch_strength(0) == 0.0 and run.lunges[0].taken,
		"The strike extinguishes exactly one torch, even when the boat stops")
	advance(run, 2.0, false)
	check(run.torches == 5 and run.lunges[1].age < 0.0, "The same strike cannot claim another torch")
	run.restart()
	check(run.torches == 6 and run.distance == 0.0 and run.lunges[0].age < 0.0 and run.torch_strength(0) == 1.0,
		"Retry restores the start of the cave and every light")

	for speed in [0.3, 1.0, 1.72]:
		var passage := RUN.new()
		passage.apply_attributes({"speed_mult": speed})
		passage.restart()
		var losses: Array[int] = []
		passage.torch_lost.connect(func(index: int, _at: Vector2): losses.append(index))
		var last_light := 0.0
		var had_light := true
		for _frame in 60 * 70:
			passage.tick(STEP, true)
			if passage.torches == 0 and had_light:
				last_light = passage.distance
				had_light = false
			if passage.phase == RUN.Phase.ESCAPED: break
		check(passage.phase == RUN.Phase.ESCAPED and passage.torches == 0 and losses == [0, 1, 2, 3, 4, 5],
			"Holding forward alone completes the six strikes in order at speed %.2f" % speed)
		check(passage.distance - last_light > 480.0 and is_equal_approx(passage.lateral, RUN.channel_at(passage.distance).x),
			"The boat follows the channel and travels through a dark stretch after the final strike")
		print("Cila route speed=", speed, " time=", snappedf(passage.clock, 0.01), " torches=", passage.torches)
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	check(map.stops.size() == 19 and not map.stops[12].is_unlocked(), "The campaign map locks Cila until the Sirens are completed")
	gm.complete_scylla()
	check(not gm.scylla_completed, "The campaign rejects an out-of-order completion")
	gm.underworld_prophecy_completed = true
	gm.complete_sirens(6)
	check(map.stops[12].is_unlocked() and map.stops[12].level_scene == SCENE, "Completing the Sirens opens the authored cave scene")
	map.queue_free()
	await process_frame
	var scene: Control = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	check(scene.mode == scene.Mode.INTRO and scene.run.phase == RUN.Phase.READY, "The real scene begins on the deck before enabling the helm")
	scene._update_story(4.1)
	scene._update_story(4.1)
	scene._update_story(2.6)
	check(scene.deck.torch_count == 6 and not scene.next_button.disabled, "The six lights appear before the player's handoff")
	scene.advance_story()
	check(scene.mode == scene.Mode.HELM and scene.run.phase == RUN.Phase.RUNNING, "The handoff starts the traversable cave")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame in 14:
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(scene.run.distance > 2.0, "Physical W alone advances the ship")
	var before: float = scene.run.distance
	paused = true
	await physics_frame
	await physics_frame
	check(scene.run.distance == before, "Pausing also freezes the canal simulation")
	paused = false
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1152, 648)
		scene.set_physics_process(false)
		scene.curtain.color.a = 0.0
		scene.advance_hint.hide()
		while scene.run.distance < 390.0:
			scene.run.tick(STEP, true)
			scene.stage.update_view(STEP)
		await snapshot("seis_tochas")
		while scene.run.lunges[2].age < 0.74:
			scene.run.tick(STEP, true)
			scene.stage.update_view(STEP)
		await snapshot("investida")
		while scene.run.distance < 3970.0:
			scene.run.tick(STEP, true)
			scene.stage.update_view(STEP)
		await snapshot("no_escuro")
		while scene.run.distance < 4390.0:
			scene.run.tick(STEP, true)
			scene.stage.update_view(STEP)
		await snapshot("luz_da_saida")
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for _frame in 60 * 70:
		if scene.ending_pending: break
		scene._physics_process(STEP)
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(scene.ending_pending and scene.run.torches == 0 and scene.run.distance == RUN.EXIT_DISTANCE,
		"The live scene reaches the outro using only the physical forward command")
	scene._process(0.6)
	check(scene.mode == scene.Mode.OUTRO and not gm.scylla_completed and scene.deck.torch_count == 0, "Escape cuts to the extinguished torches before recording completion")
	for duration in [3.3, 3.7, 3.3, 4.1]:
		scene._update_story(duration)
	check(scene.mode == scene.Mode.RESULT and gm.scylla_completed and gm.player_current_hp == 6 and gm.highest_unlocked_level == 9, "The last cinematic saves completion without applying hull damage to Odisseu")
	scene.queue_free()
	await process_frame
	var manager := MANAGER.new()
	manager.save_file_path = OS.get_environment("TEMP").path_join("nostos_scylla_%d.json" % Time.get_ticks_usec())
	var legacy := FileAccess.open(manager.save_file_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"highest_unlocked_level": 7, "circe_moly_found": true, "circe_search_completed": true, "circe_battle_completed": true, "underworld_crossing_completed": true, "underworld_vision_index": 3, "underworld_prophecy_completed": true, "sirens_completed": true}))
	legacy.close()
	check(manager.load_game() and manager.highest_unlocked_level == 8 and not manager.scylla_completed, "A legacy save after the Sirens opens Cila without awarding completion")
	manager.complete_scylla()
	manager.reset()
	check(not manager.scylla_completed and manager.load_game() and manager.scylla_completed, "New game resets the flag and a saved victory restores it")
	DirAccess.remove_absolute(manager.save_file_path)
	manager.free()
	print("SCYLLA: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
