extends SceneTree

const MODEL := preload("res://Ato11_Caribdis/Gameplay/CharybdisRun.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const SCENE := "res://Ato11_Caribdis/Gameplay/Charybdis.tscn"
const STEP := 1.0 / 120.0
var checks := 0
var failures := 0

func _initialize() -> void:
	exercise.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func exercise() -> void:
	var manager: MANAGER = root.get_node("GameManager")
	var preview := manager.standalone_stage_preview
	manager.persistence_enabled = false
	manager.reset()
	manager.player_age = 31
	manager.player_current_hp = 6
	manager.complete_charybdis()
	expect(not manager.charybdis_completed, "A save cannot complete Caríbdis before the departure")
	var scene: Control = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	if preview:
		expect(not scene.locked and not manager.persistence_enabled, "F6 opens Caríbdis independently and never saves")
	else:
		expect(scene.locked, "A campaign entry is locked without completing Ogígia")
	scene.queue_free()
	await process_frame
	manager.ogygia_paths_completed = true
	manager.complete_calypso()
	expect(manager.highest_unlocked_level == 11, "Completing Calypso unlocks act XI")

	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	await process_frame
	expect(map.stops.size() == 19 and map.stops[16].level_scene == SCENE and map.stops[16].is_unlocked() and not map.stops[16].is_completed(), "The map offers the actual encounter after Ogígia")
	map.queue_free()
	await process_frame

	for lane in 3:
		var model := MODEL.new()
		model.start()
		model.steer(lane - 1)
		for frame in 7200:
			model.tick(STEP)
		expect(model.phase == MODEL.Phase.LOST and model.hull == 0, "Camping lane %d cannot clear the encounter" % lane)
		model.start()
		expect(model.phase == MODEL.Phase.ORBIT and model.hull == 3 and model.time == 0.0, "Retry resets the encounter")

	for speed in [0.3, 1.0, 1.72]:
		var model := MODEL.new()
		model.set_agility(speed)
		model.start()
		navigate(model)
		expect(model.phase == MODEL.Phase.RELEASE and model.hull == 3 and model.time == MODEL.LIMIT, "All sweeps are dodgeable at agility %.2f" % speed)
		model.tick(MODEL.RELEASE_TIME + STEP)
		expect(model.phase == MODEL.Phase.DONE and is_zero_approx(model.power()), "The vortex subsides as the raft escapes")

	scene = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	press(KEY_ENTER)
	expect(scene.run.phase == MODEL.Phase.ORBIT, "Enter starts the real scene")
	press(KEY_A)
	expect(scene.run.target_lane == 0, "A steers inward")
	press(KEY_RIGHT)
	press(KEY_D)
	expect(scene.run.target_lane == 2, "Right and D steer outward")
	var at_pause: float = scene.run.time
	scene.set_physics_process(true)
	paused = true
	for frame in 4:
		await physics_frame
	expect(scene.run.time == at_pause, "Pause freezes the challenge timer")
	paused = false
	scene.set_physics_process(false)
	scene.restart_checkpoint()
	for frame in 1855:
		scene._physics_process(STEP)
	await capture("approach")
	scene.restart_checkpoint()
	navigate(scene.run)
	expect(not manager.charybdis_completed, "Completion waits for the release")
	scene._physics_process(MODEL.RELEASE_TIME + STEP)
	expect(manager.charybdis_completed != preview, "Only campaign completion records the victory")
	expect(manager.player_age == 31 and manager.player_current_hp == 6, "The raft uses separate durability and preserves age and life")
	scene.queue_free()
	await process_frame
	print("CHARYBDIS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func navigate(model: MODEL) -> void:
	var next := 0
	while model.phase == MODEL.Phase.ORBIT:
		if next < MODEL.SWEEPS.size():
			var sweep: Vector3i = MODEL.SWEEPS[next]
			if model.sweep_time(sweep) - model.time < 1.16:
				var current := model.target_lane
				if (sweep.y & (1 << current)) != 0:
					for index in 3:
						if (sweep.y & (1 << index)) == 0:
							for press_count in absi(index - current):
								model.steer(1 if index > current else -1)
							break
				next += 1
		model.tick(STEP)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(OS.get_environment("TEMP").path_join("nostos_charybdis_" + name + ".png"))
