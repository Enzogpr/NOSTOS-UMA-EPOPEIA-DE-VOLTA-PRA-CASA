extends SceneTree

const MODEL := preload("res://Ato7_Sereias/Gameplay/SirenEncounter.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const SCENE := "res://Ato7_Sereias/Gameplay/SirenCove.tscn"
const STEP := 1.0 / 60.0
const PREVIEW_DIR := "res://scratch/campaign_review/sirens"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func advance(model: MODEL, seconds: float, direction := Vector2.ZERO) -> void:
	for frame in ceili(seconds / STEP):
		model.tick(STEP, direction)

func snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW_DIR))
	root.get_texture().get_image().save_png(PREVIEW_DIR.path_join(label + ".png"))

func steer_to(model: MODEL, target: Vector2) -> Vector2:
	var course := model.position.direction_to(target)
	for reef in MODEL.REEFS:
		var center := Vector2(reef.x, reef.y)
		var closest := Geometry2D.get_closest_point_to_segment(center, model.position, model.position + course * 112.0)
		if closest.distance_to(center) < reef.z + 39.0:
			var outward := center.direction_to(model.position)
			var tangent := outward.orthogonal()
			if tangent.dot(course) < 0.0:
				tangent = -tangent
			return (tangent + outward * 0.44).normalized()
	return course

func run_route(speed: float, intellect: int, health: int) -> MODEL:
	var model := MODEL.new()
	model.apply_attributes({"max_hp": health, "speed_mult": speed, "intellect": intellect})
	model.set_entry_health(health)
	model.begin()
	var route_leg := 0
	for _frame in ceili((MODEL.LIMIT + MODEL.CHARM_DURATION) / STEP):
		if model.phase != MODEL.Phase.ACTIVE: break
		var target := model.siren
		var distance := model.position.distance_to(target.position)
		var steering := Vector2.ZERO
		var direction_sign := -1.0 if model.helm_inverted() else 1.0
		if model.hooked:
			if model.line_blocker >= 0:
				steering = steer_to(model, Vector2(979, 412))
			elif distance > 119.0:
				steering = steer_to(model, target.position) * clampf((distance - 113.0) / 75.0, 0.0, 1.0)
			model.tick(STEP, steering * direction_sign, model.can_haul())
			continue
		if model.leg == MODEL.Leg.CHARM and route_leg < 2:
			var south := Vector2(810, 479) if route_leg == 0 else Vector2(976, 489)
			if model.position.distance_to(south) > 20.0:
				model.tick(STEP, steer_to(model, south) * direction_sign)
				continue
			route_leg += 1
			continue
		var aim := target.position + target.velocity * (MODEL.NET_FLIGHT * 0.78)
		if distance > 153.0:
			steering = steer_to(model, target.position) * clampf((distance - 145.0) / 91.0, 0.0, 1.0)
		elif distance < 105.0:
			steering = target.position.direction_to(model.position) * 0.48
		var open := model.net_window_open() and (model.leg == MODEL.Leg.CHASE or model.window_left > MODEL.NET_FLIGHT)
		if distance > 83.0 and open and model.position.distance_to(aim) <= MODEL.NET_RANGE - 7.0:
			if model.leg != MODEL.Leg.CHARM or model.reef_in_line(aim) < 0:
				model.cast_net(aim)
		model.tick(STEP, steering * direction_sign)
	return model

func run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.persistence_enabled = false
	var model := MODEL.new()
	model.cast_net(Vector2(900, 400))
	check(model.net_age < 0.0 and model.elapsed == 0.0, "Briefing cannot fire a net or advance the clock")
	model.begin()
	model.cast_net(Vector2(900, 400))
	check(is_equal_approx(model.net_to.distance_to(model.position), MODEL.NET_RANGE), "The physical net throw is clamped to the displayed range")
	var old_aim := model.net_to
	model.cast_net(Vector2(0, 140))
	advance(model, 0.17)
	check(model.leg == MODEL.Leg.CHASE and not model.hooked and model.net_to == old_aim, "A cast cannot be retargeted or hook before landing")
	model.restart()
	model.cast_net(Vector2(90, 160))
	advance(model, 0.42)
	check(model.leg == MODEL.Leg.CHASE and not model.hooked, "A missed net cannot advance the hunt")
	model.restart()
	model.position = Vector2(316, 352)
	var target := model.siren
	model.cast_net(target.position + Vector2(35, 10))
	advance(model, MODEL.NET_FLIGHT + 0.04)
	check(model.hooked and model.leg == MODEL.Leg.CHASE, "Landing the first net briefly tethers the siren")
	var first_time := model.elapsed
	advance(model, MODEL.FIRST_ESCAPE_DELAY + 0.08)
	check(not model.hooked and model.leg == MODEL.Leg.MIRAGE and model.siren == target and model.elapsed > first_time,
		"The same siren escapes into the second leg while the global timer keeps counting")
	var reflection := MODEL.new(); reflection.begin(); reflection.leg = MODEL.Leg.MIRAGE
	reflection.siren.position = Vector2(670, 247)
	reflection.position = Vector2(530, 327)
	advance(reflection, 1.6)
	check(reflection.illusions.size() == 2 and reflection.window_left > 0.0, "The second leg shows the real siren and two illusions")
	reflection.cast_net(reflection.illusions[0])
	advance(reflection, MODEL.NET_FLIGHT + 0.04)
	check(not reflection.hooked and reflection.dive_time > 0.0 and reflection.illusions.is_empty(), "The false image dissolves without advancing the hunt")
	reflection.dive_time = 0.0
	reflection.siren.position = reflection.position + Vector2(48, 0)
	reflection._check_contact(); reflection._check_contact()
	check(reflection.hp == 9, "Only contact with the real siren damages the ship")
	reflection.siren.position = reflection.position + Vector2(105, 0)
	reflection.hooked = true
	reflection._advance_line(reflection.reel_time() + 0.02, true)
	check(reflection.phase == MODEL.Phase.ACTIVE and reflection.leg == MODEL.Leg.CHARM and not reflection.hooked and reflection.siren.captured_age < 0.0,
		"Hauling the second net makes the same siren escape without granting a victory")
	var steering := MODEL.new(); steering.begin()
	advance(steering, 0.28, Vector2(1, -1))
	check(steering.position.x > MODEL.START.x and steering.position.y < MODEL.START.y, "The helm obeys both axes before the third leg")
	steering.restart(); steering.leg = MODEL.Leg.CHARM
	advance(steering, 0.28, Vector2(1, -1))
	check(steering.position.x < MODEL.START.x and steering.position.y > MODEL.START.y and steering.helm_inverted(), "The song reverses both axes of the helm in the final leg")
	steering.cast_net(steering.position + Vector2(140, 0))
	check(steering.net_to.x > steering.position.x, "The mouse still aims in the pointed direction during the enchantment")
	var deadline := MODEL.new(); deadline.begin(); deadline.leg = MODEL.Leg.CHARM
	deadline.elapsed = MODEL.LIMIT - 0.01
	deadline.hooked = true
	deadline.reel_progress = deadline.reel_time() - 0.004
	deadline.tick(STEP, Vector2.RIGHT, true)
	check(deadline.phase == MODEL.Phase.ENTHRALLED and not deadline.hooked and deadline.elapsed == MODEL.LIMIT,
		"Expiration takes priority over a nearly finished final haul")
	var drift_start := deadline.position
	advance(deadline, 0.8, Vector2.LEFT)
	check(deadline.position.x > drift_start.x and deadline.song_strength > 0.5, "The charmed boat follows the siren despite steering input")
	advance(deadline, MODEL.CHARM_DURATION)
	check(deadline.phase == MODEL.Phase.LOST, "The charm ends in a failed attempt")
	deadline.restart()
	check(deadline.leg == MODEL.Leg.CHASE and deadline.elapsed == 0.0 and not deadline.helm_inverted(), "Retry clears the enchantment, timer and pursuit progress")
	var rope := MODEL.new(); rope.begin(); rope.leg = MODEL.Leg.CHARM; rope.hooked = true
	rope.position = Vector2(802, 305); rope.siren.position = Vector2(981, 305)
	rope._advance_line(0.4, true)
	check(rope.line_blocker == 2 and rope.line_tension > 0.3 and rope.reel_progress == 0.0, "A reef in the physical rope path creates tension and blocks hauling")
	rope.position = Vector2(977, 409)
	rope.tug = 0.0; rope._advance_line(0.25, false)
	check(rope.line_blocker == -1 and rope.line_tension < 0.2, "Steering around the reef and releasing E slackens the line")
	rope._advance_line(0.25, true)
	check(rope.reel_progress > 0.2, "A close, clear, slack rope can be hauled")
	rope.tug = 1.0; rope._advance_line(0.4, true)
	check(rope.hooked and rope.line_tension > 0.3 and rope.reel_progress < 0.3, "Hauling through a surge stresses the rope without granting progress")
	rope._advance_line(0.6, true)
	check(not rope.hooked and rope.dive_time > 0.0 and rope.leg == MODEL.Leg.CHARM, "A broken final rope can be retried on the same leg before the deadline")
	model.apply_attributes({"max_hp": 4, "speed_mult": 0.6, "intellect": 19})
	model.restart()
	check(model.hp == 4 and model.elapsed == 0 and model.leg == MODEL.Leg.CHASE and model.position == MODEL.START and model.song_resistance < 1.0, "Retry preserves the updated campaign attributes")
	var reef: Vector3 = MODEL.REEFS[0]
	model.position = Vector2(reef.x - 91.0, reef.y)
	advance(model, 0.8, Vector2.RIGHT)
	check(model.position.distance_to(Vector2(reef.x, reef.y)) >= reef.z + 25.99, "The solid reef blocks the hull")
	for profile in [[1.0, 5, 10], [0.3, 25, 1], [1.72, 5, 10]]:
		var won := run_route(profile[0], profile[1], profile[2])
		check(won.phase == MODEL.Phase.WON and won.elapsed < MODEL.LIMIT and won.siren.captured_age >= 0.0,
			"The full hunt is beatable with speed %.2f and %d HP (leg %d, at %s)" % [profile[0], profile[2], won.leg, won.position])
		print("Route speed=", profile[0], " time=", snappedf(won.elapsed, 0.01), " leg=", won.leg, " hp=", won.hp)
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	check(map.stops.size() == 19 and not map.stops[11].is_unlocked(), "The cove is locked on the campaign map before Tiresias")
	gm.complete_sirens(3)
	check(not gm.sirens_completed and gm.player_current_hp == 10, "A locked stage cannot award progression or change campaign health")
	gm.underworld_crossing_completed = true
	gm.record_underworld_vision(gm.UNDERWORLD_VISION_COUNT)
	gm.complete_underworld_prophecy()
	check(map.stops[11].is_unlocked() and map.stops[11].level_scene == SCENE, "The prophecy unlocks the actual cove scene")
	map.queue_free()
	await process_frame
	var scene: Control = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene._begin()
	check(scene.encounter.phase == MODEL.Phase.ACTIVE, "The unlocked campaign scene can start")
	var old_position: Vector2 = scene.encounter.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame in 10:
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(scene.encounter.position.y < old_position.y - 5.0, "The real scene accepts physical WASD input")
	scene.encounter.leg = MODEL.Leg.CHARM
	scene.encounter.position = Vector2(995, 419)
	scene.encounter.velocity = Vector2.ZERO
	scene.encounter.siren.position = Vector2(1000, 320)
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame in 10: await physics_frame
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(scene.encounter.position.y > 425.0, "The physical W key steers down during the final leg")
	scene.encounter.position = Vector2(995, 419)
	scene.encounter.velocity = Vector2.ZERO
	scene.encounter.hooked = true
	var reel_key := InputEventKey.new()
	reel_key.physical_keycode = KEY_E
	reel_key.pressed = true
	Input.parse_input_event(reel_key)
	Input.flush_buffered_events()
	for frame in 15:
		await physics_frame
	var reel_release := InputEventKey.new()
	reel_release.physical_keycode = KEY_E
	Input.parse_input_event(reel_release)
	Input.flush_buffered_events()
	check(scene.encounter.reel_progress > 0.1 and scene.encounter.phase == MODEL.Phase.ACTIVE, "Holding the actual E key starts hauling before awarding capture")
	var clock := scene.encounter.elapsed as float
	paused = true
	await physics_frame
	await physics_frame
	check(scene.encounter.elapsed == clock, "Pause also freezes the encounter clock")
	paused = false
	scene.encounter.elapsed = MODEL.LIMIT - 0.01
	scene._physics_process(STEP)
	check(scene.clock_label.text == "00:00" and scene.encounter.phase == MODEL.Phase.ENTHRALLED and not scene.result.visible,
		"The live scene shows the deadline and lets the charm play out before offering a retry")
	scene._physics_process(MODEL.CHARM_DURATION)
	check(scene.result.visible and scene.result_title.text == "O CANTO TOMOU O LEME" and not gm.sirens_completed,
		"The charmed ending shows a defeat and awards no campaign progress")
	scene.restart_checkpoint()
	check(scene.clock_label.text == "01:15" and scene.encounter.elapsed == 0.0 and scene.encounter.leg == MODEL.Leg.CHASE,
		"Retry restores the visible clock and the first leg")
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1152, 648)
		scene.set_physics_process(false)
		scene.encounter.restart()
		scene.encounter.position = Vector2(307, 344)
		advance(scene.encounter, 0.44)
		scene._update_hud()
		await snapshot("siren_chase")
		scene.encounter.restart()
		scene.encounter.leg = MODEL.Leg.MIRAGE
		scene.encounter.siren.position = Vector2(670, 247)
		scene.encounter.position = Vector2(530, 327)
		advance(scene.encounter, 1.8)
		scene._update_hud()
		await snapshot("siren_illusions")
		scene.encounter.leg = MODEL.Leg.CHARM
		scene.encounter.illusions.clear()
		scene.encounter.window_left = 0.0
		scene.encounter.hooked = true
		scene.encounter.position = Vector2(800, 306)
		scene.encounter.siren.position = Vector2(982, 306)
		scene.encounter._advance_line(0.65, true)
		scene._update_hud()
		await snapshot("siren_inverted_helm")
		scene.encounter.elapsed = MODEL.LIMIT - 0.01
		advance(scene.encounter, 1.5)
		scene._update_hud()
		await snapshot("siren_charm")
		scene.encounter.charm_age = 0.0
		scene.encounter.song_strength = 0.0
	scene.encounter.hp = 6
	scene.encounter.leg = MODEL.Leg.CHARM
	scene.encounter._clear_line()
	scene.encounter.siren.captured_age = 1.0
	scene.encounter.phase = MODEL.Phase.WON
	scene._physics_process(STEP)
	check(gm.sirens_completed and gm.player_current_hp == 6 and gm.highest_unlocked_level == 8, "Victory carries remaining HP and records only the implemented act")
	scene._physics_process(0.9)
	scene._process(0.75)
	scene._physics_process(STEP)
	check(scene.final_dialogue.visible and not scene.result.visible and not scene.stage.cave_visible, "The last siren tells the crew which way to go before the cave is shown")
	await snapshot("last_siren")
	scene._reveal_route()
	scene._process(1.85)
	scene._physics_process(STEP)
	check(scene.stage.cave_visible and scene.result.visible and scene.result_next.visible, "The cave reveal leads to the Cila entry button")
	await snapshot("scylla_entrance")
	gm.complete_sirens(2)
	check(gm.player_current_hp == 6, "Replaying a completed stage does not consume campaign HP again")
	var manager := MANAGER.new()
	manager.save_file_path = OS.get_environment("TEMP").path_join("nostos_sirens_%d.json" % Time.get_ticks_usec())
	var legacy := FileAccess.open(manager.save_file_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"highest_unlocked_level": 6, "circe_moly_found": true, "circe_search_completed": true, "circe_battle_completed": true, "underworld_crossing_completed": true, "underworld_vision_index": 3, "underworld_prophecy_completed": true}))
	legacy.close()
	check(manager.load_game() and manager.highest_unlocked_level == 7 and not manager.sirens_completed, "An older save past Tiresias unlocks the stage without marking it complete")
	manager.complete_sirens(4)
	manager.reset()
	check(not manager.sirens_completed and manager.load_game() and manager.sirens_completed and manager.player_current_hp == 4, "The first victory survives saving and loading while a new game starts clean")
	DirAccess.remove_absolute(manager.save_file_path)
	manager.free()
	scene.queue_free()
	await process_frame
	var audio_manager := root.get_node("AudioManager")
	var prior_stream: AudioStream = audio_manager.music_player.stream
	audio_manager.play_music(preload("res://Assets/act6_underworld/river_drone.wav"))
	var music_paused: bool = audio_manager.music_player.stream_paused
	var audible: Control = load(SCENE).instantiate()
	root.add_child(audible)
	current_scene = audible
	await process_frame
	check(audible.ambience.playing and audible.song.playing, "The normal scene starts the surf and song layers")
	check(audio_manager.music_player.stream_paused, "The normal scene pauses active campaign music")
	audible.queue_free()
	await create_timer(0.25).timeout
	check(audio_manager.music_player.stream_paused == music_paused, "Leaving the cove restores the campaign music state")
	audio_manager.stop_music()
	audio_manager.music_player.stream = prior_stream
	await create_timer(0.15).timeout
	print("SIRENS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
