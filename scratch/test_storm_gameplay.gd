extends Node
## Physical contacts, keyboard input, pause, campaign handoff and a complete crossing.

const LEVEL := preload("res://Ato4_Tempestade/Gameplay/StormLevel.tscn")
const SHIP := preload("res://Ato4_Tempestade/Gameplay/StormShip.tscn")
const WAVE := preload("res://Ato4_Tempestade/Gameplay/StormWave.tscn")
var failures: int = 0
var capture: bool = false
var checks: int = 0
var save_existed: bool
var saved_bytes: PackedByteArray
var original_progress: int

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func new_level() -> Node2D:
	var level := LEVEL.instantiate()
	level.persist_progress = false
	level.random_seed = 4104
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	return level

func screenshot(name: String) -> void:
	if not capture:
		return
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/" + name + ".png")
	get_tree().paused = was_paused

func physical_front(level: Node2D, huge: bool, in_gap: bool = false, sheltered: bool = false) -> void:
	level.set_physics_process(false)
	level.ship.set_physics_process(false)
	level.ship.hull = 100
	level.ship.hit_cooldown = 0
	level.ship.braced = false
	level.ship.calm = sheltered
	level.ship.impulse = Vector2.ZERO
	level.ship.position = Vector2(1800, 950) if sheltered else Vector2(1500, 800)
	var wave := WAVE.instantiate()
	wave.level = level
	wave.tsunami = huge
	wave.damage = 48.0 if huge else 28.0
	wave.gap_center = 800 if in_gap else 400
	wave.position = Vector2(level.ship.position.x, 0 if huge else level.ship.position.y)
	wave.warning_seconds = 0.1
	wave.travel_speed = 0
	level.get_node("Waves").add_child(wave)
	await frames(18)
	var expected_hull: float = 100.0 if in_gap or sheltered else 52.0 if huge else 72.0
	check(is_equal_approx(level.ship.hull, expected_hull), "Physical fronts must spare calm water and the tsunami gap, and damage exposed hulls.")
	var first_impulse: Vector2 = level.ship.impulse
	check(first_impulse.is_zero_approx() if in_gap or sheltered else first_impulse.x < -300.0, "Only exposed wave contact must give the hull a strong backwards impulse.")
	await frames(15)
	check(is_equal_approx(level.ship.hull, expected_hull) and level.ship.impulse == first_impulse, "A single front must neither damage nor push the same hull repeatedly.")
	wave.free()
	level.ship.set_physics_process(true)
	level.set_physics_process(true)

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	save_existed = FileAccess.file_exists(GameManager.SAVE_FILE_PATH)
	if save_existed:
		saved_bytes = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH)
		FileAccess.open("res://scratch/storm_original_save.backup", FileAccess.WRITE).store_buffer(saved_bytes)
	else:
		FileAccess.open("res://scratch/storm_original_save.backup", FileAccess.WRITE).store_string("NO_SAVE")
	original_progress = GameManager.highest_unlocked_level
	await get_tree().process_frame
	var level := new_level()
	# Unit checks isolate the input/contact under test from ambient random fronts.
	level.next_wave = INF
	level.tsunami_thresholds.clear()
	level.next_gust = INF
	await frames(3)
	check(level.state == level.State.READY and not level.ship.sailing, "The helm instructions must be safe until the player starts.")
	check(level.GOAL.x > 21000 and level.get_node("Rocks").get_child_count() == 28 and level.get_node("Whirlpools").get_child_count() == 8, "The longer crossing must include extra reefs and eight whirlpools.")
	check(not level.has_node("Island") and not level.has_node("Dock") and not level.get_node("SkyIsland").visible, "There must be no grounded island or dock at the destination.")
	check(not FileAccess.get_file_as_string("res://Ato4_Tempestade/Gameplay/StormHUD.gd").contains("_map_point"), "The minimap must be removed.")
	check(not MainHUD.visible, "The storm HUD must replace the hero HUD.")
	check(level.storm_audio.playing and level.storm_audio.bus == &"SFX", "Storm audio must remain active on the SFX bus.")
	await screenshot("storm_game_instructions")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(3)
	check(level.state == level.State.SAILING, "Real Enter input must start the playable crossing.")
	var start_x: float = level.ship.position.x
	# A hidden Windows render window may release OS key state when focus changes.
	# Keyboard behavior is verified headless; GL uses the same physical helm path.
	if capture:
		level.ship.scripted_helm = true
		level.ship.helm = Vector2(0, 1)
	else:
		key(KEY_W, true)
	for _frame in 60:
		if not capture:
			key(KEY_W, true)
		await get_tree().physics_frame
	key(KEY_W, false)
	check(level.ship.position.x > start_x + 40, "W must propel the actual CharacterBody2D ship.")
	if capture:
		level.ship.helm = Vector2(1, 0)
	else:
		key(KEY_D, true)
	await frames(12)
	key(KEY_D, false)
	check(level.ship.rotation > 0.2, "D must steer the actual ship.")
	var rig: Node2D = level.ship.get_node("RowingRig")
	check(rig.oars.size() == 24, "All 24 oars must have independent rowing pivots.")
	level.ship.rowing_effort = 1.0
	var first_angle: float = rig.oars[0].rotation
	await get_tree().create_timer(0.25).timeout
	check(absf(rig.oars[0].rotation - first_angle) > 0.02, "Oar animation must move when rowing.")
	await screenshot("storm_hard_rowing")
	level.ship.scripted_helm = false
	await physical_front(level, false)
	await physical_front(level, true)
	await physical_front(level, true, true)
	await physical_front(level, false, false, true)
	await physical_front(level, true, false, true)
	level.ship.calm = false
	var incoming: Area2D = level.spawn_wave(true)
	check(incoming.position.x - level.ship.position.x > level.ship.max_speed * incoming.warning_seconds + 82, "A ship at full sail must not bypass a tsunami before its warning ends.")
	incoming.free()
	var unexpected: Area2D = level.spawn_wave(false, true)
	check(unexpected.warning_seconds == 0 and unexpected.moving and unexpected.monitoring, "Surprise waves must be active immediately, without warning graphics.")
	unexpected.free()
	var test_gusts := []
	for _gust in 5:
		level.next_gust = 0
		level.update_wind(0.1)
		test_gusts.append(level.wind_target)
	check(test_gusts[0].distance_to(test_gusts[1]) > 40 and test_gusts[0].length() >= 124 and test_gusts[0].length() <= 192, "Reduced gusts must stay in range while changing direction and intensity.")
	level.wind = Vector2.ZERO
	level.wind_target = Vector2.ZERO
	level.next_gust = INF
	var swirl_model := SHIP.instantiate()
	swirl_model.braced = true
	for _step in 120:
		swirl_model.apply_whirlpool(1.0 / 60.0, true)
	check(is_equal_approx(swirl_model.hull, 94), "Whirlpool exposure must cause exactly three damage per second, even when braced.")
	swirl_model.apply_whirlpool(0.0, false)
	check(swirl_model.whirlpool_timer == 0, "Whirlpool damage must stop on exit.")
	swirl_model.free()
	level.set_physics_process(false)
	var vortex: Area2D = level.get_node("Whirlpools/Whirlpool1")
	level.ship.position = vortex.position + Vector2(-160, 0)
	level.ship.rotation = 0
	level.ship.calm = false
	level.ship.scripted_helm = true
	level.ship.helm = Vector2.ZERO
	level.ship.speed = 0
	level.ship.wind = Vector2.ZERO
	level.ship.drift = Vector2.ZERO
	level.ship.impulse = Vector2.ZERO
	level.ship.weather_damage = 0
	level.ship.hull = 100
	level.ship.in_whirlpool = true
	for _step in 62:
		level.ship.whirlpool_pull = vortex.field_at(level.ship.position)
		await get_tree().physics_frame
	print("Physical whirlpool: distance=", level.ship.position.distance_to(vortex.position), "; hull=", level.ship.hull, "; exposure=", level.ship.whirlpool_timer)
	check(level.ship.position.distance_to(vortex.position) < 160 and level.ship.hull <= 97.01 and level.ship.hull >= 96.9, "A real whirlpool must pull the physical hull and tick three damage.")
	await screenshot("storm_hard_whirlpool")
	level.ship.in_whirlpool = false
	level.ship.whirlpool_pull = Vector2.ZERO
	level.ship.whirlpool_timer = 0
	# The editor-authored reef polygon must stop the hull and inflict collision damage.
	level.set_physics_process(false)
	level.ship.scripted_helm = true
	level.ship.helm = Vector2(0, 1)
	level.ship.position = Vector2(1150, 650)
	level.ship.rotation = 0
	level.ship.speed = 0
	level.ship.wind = Vector2.ZERO
	level.ship.drift = Vector2.ZERO
	level.ship.impulse = Vector2.ZERO
	level.ship.weather_damage = 0
	level.ship.hull = 100
	level.ship.hit_cooldown = 0
	await frames(100)
	check(level.ship.position.x < 1300 and level.ship.hull < 90, "The reef's saved collision polygon must block and damage the physical ship.")
	level.ship.scripted_helm = false
	level.ship.weather_damage = 1.15
	level.set_physics_process(true)
	level.ship.hit_cooldown = 0
	level.ship.hull = 100
	level.ship.braced = true
	check(level.ship.take_wave_damage(48), "A fresh wave must register a hit.")
	check(is_equal_approx(level.ship.hull, 73.6), "Reefing sails must reduce wave damage by 45 percent.")
	check(not level.ship.take_wave_damage(48), "Collision immunity must prevent duplicate immediate damage.")
	# Continuous damage must not truncate at normal frame rates.
	var slow := SHIP.instantiate()
	var fast := SHIP.instantiate()
	for _i in 30:
		slow.apply_weather(1.0 / 30.0)
	for _i in 120:
		fast.apply_weather(1.0 / 120.0)
	check(absf(slow.hull - fast.hull) < 0.001 and absf(slow.hull - 98.85) < 0.001, "Storm attrition must be independent of frame rate.")
	slow.free()
	fast.free()
	level.ship.position = Vector2(1800, 950)
	level.ship.rotation = 0
	level.ship.speed = 0
	level.ship.drift = Vector2.ZERO
	level.ship.impulse = Vector2.ZERO
	level.ship.hull = 60
	key(KEY_E, true)
	await frames(60)
	key(KEY_E, false)
	check(level.ship.hull > 64 and level.ship.calm, "Crew repairs must work in sheltered water while stopped.")
	await screenshot("storm_game_repair")
	get_viewport().size = Vector2i(800, 1000)
	await get_tree().process_frame
	await get_tree().process_frame
	check(level.hud.position.x >= 0 and level.hud.position.y >= 0 and level.hud.scale.x < 1.0, "The ship HUD must fit a portrait window.")
	await screenshot("storm_game_portrait")
	get_viewport().size = Vector2i(1152, 648)
	await get_tree().process_frame
	level.ship.position = Vector2(1100, 300)
	level.ship.speed = 0
	var before: float = level.ship.hull
	key(KEY_E, true)
	await frames(30)
	key(KEY_E, false)
	check(level.ship.hull < before and not level.ship.repairing, "Repairs must be unavailable in rough water.")
	level.set_physics_process(false)
	level.ship.scripted_helm = true
	level.ship.helm = Vector2.ZERO
	level.ship.wind = Vector2(0, 180)
	var previous_y: float = level.ship.position.y
	await frames(60)
	check(level.ship.position.y > previous_y + 30, "Wind must displace the physical ship.")
	level.ship.position = Vector2(85, 500)
	level.ship.rotation = 0
	level.ship.wind = Vector2(-500, 0)
	level.ship.drift = Vector2(-500, 0)
	await frames(45)
	check(level.ship.position.x >= 74, "Wind must respect the collision boundary instead of teleporting through it.")
	level.set_physics_process(true)
	var clock: float = level.elapsed
	var vortex_clock: float = level.get_node("Whirlpools/Whirlpool1").age
	var oar_clock: float = level.ship.get_node("RowingRig").phase
	var rain_clock: float = level.sea_clock
	var position_before: Vector2 = level.ship.position
	var sound_clock: float = level.storm_audio.get_playback_position()
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	check(level.elapsed == clock and level.sea_clock == rain_clock and level.ship.position == position_before, "Pause must freeze weather, rain, hull damage and ship motion.")
	check(level.get_node("Whirlpools/Whirlpool1").age == vortex_clock and level.ship.get_node("RowingRig").phase == oar_clock, "Pause must also freeze whirlpool and rowing animation.")
	check(absf(level.storm_audio.get_playback_position() - sound_clock) < 0.08, "Pause must freeze storm audio.")
	get_tree().paused = false
	level.ship.hull = 0.1
	level.ship.calm = false
	level.ship.apply_weather(1.0)
	check(level.state == level.State.LOST, "Hull loss must show the retry outcome once.")
	await screenshot("storm_game_sunk")
	key(KEY_R, true)
	key(KEY_R, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	level = get_tree().current_scene
	check(level.name == "Act4StormNavigation" and level.state == level.State.READY and level.ship.hull == 100, "Real R must reload the crossing with a fresh ship.")
	level.free()
	await get_tree().process_frame
	# Complete the existing cutscene and test the real configured scene change.
	var prologue: Control = load("res://Ato4_Tempestade/Cutscenes/Act4_StormCutscene.tscn").instantiate()
	get_tree().root.add_child(prologue)
	get_tree().current_scene = prologue
	prologue.cinematic.autoplay = false
	for _beat in 16:
		while prologue.cinematic.active:
			prologue.cinematic.input_cooldown = 0
			prologue.cinematic.dialogue.visible_characters = prologue.cinematic.dialogue.get_total_character_count()
			var prior_beat: int = prologue.beat_index
			prologue.cinematic._advance_requested()
			if prologue.beat_index != prior_beat or prologue.handoff_started:
				break
	await get_tree().create_timer(1.3).timeout
	level = get_tree().current_scene
	check(level.name == "Act4StormNavigation", "The final spoken order must lead directly into the ship level.")
	check(GameManager.highest_unlocked_level >= 4, "Reaching the crossing must unlock act four for replay.")
	await full_crossing(level)
	level = get_tree().current_scene
	# Map reentry must select and link the fourth station.
	level.return_to_map()
	await get_tree().create_timer(0.5).timeout
	var world_map: Control = get_tree().current_scene
	check(world_map.player.current_node.level_id == 4, "The map must select unlocked act four.")
	check(world_map.node3.get_right() == world_map.node4 and world_map.node4.get_left() == world_map.node3, "Both directions of the new map link must work.")
	world_map.free()
	get_tree().current_scene = self
	await get_tree().process_frame
	if save_existed:
		FileAccess.open(GameManager.SAVE_FILE_PATH, FileAccess.WRITE).store_buffer(saved_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_FILE_PATH))
	GameManager.highest_unlocked_level = original_progress
	print("STORM GAMEPLAY: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func full_crossing(level: Node2D) -> void:
	level.rng.seed = 42
	level.ship.damaged.connect(func(amount: float): print("Pilot impact ", amount, " at ", level.elapsed, " hp=", level.ship.hull, " pos=", level.ship.position))
	level.start_sailing()
	level.ship.scripted_helm = true
	var waypoints: Array[Vector2] = []
	for shelter in level.get_node("CalmWaters").get_children():
		waypoints.append(shelter.position)
	waypoints.append(level.GOAL)
	var index: int = 0
	var repairing_stop: bool = false
	var tsunami_capture: bool = false
	var calm_capture: bool = false
	var path := PackedVector2Array()
	var repath_at: float = 0.0
	var grid := make_navigation_grid(level)
	Engine.physics_ticks_per_second = 180
	Engine.time_scale = 6
	while level.state == level.State.SAILING and level.elapsed < 420:
		var ship: CharacterBody2D = level.ship
		var target: Vector2 = waypoints[index]
		# A crest can now carry us back toward the previous shelter. Return to
		# the nearer repair stop instead of insisting on the next leg at low hull.
		if ship.hull < 68 and not ship.calm and not repairing_stop:
			var closest: int = index
			var best_distance: float = ship.position.distance_to(target)
			for shelter_index in range(waypoints.size() - 1):
				var distance: float = ship.position.distance_to(waypoints[shelter_index])
				if distance + 180 < best_distance:
					closest = shelter_index
					best_distance = distance
			if closest != index:
				index = closest
				target = waypoints[index]
				repath_at = 0
		var active_front: Area2D
		for wave in level.get_node("Waves").get_children():
			if wave.tsunami and wave.position.x > ship.position.x - 110 and wave.position.x < ship.position.x + 1400:
				active_front = wave
				break
		if active_front:
			target = Vector2(minf(ship.position.x + 500, waypoints[index].x), active_front.gap_center)
			if not tsunami_capture and active_front.moving:
				await screenshot("storm_hard_tsunami")
				tsunami_capture = true
		elif index < waypoints.size() - 1 and ship.calm and ship.position.distance_to(target) < 165:
			# Leave shelter on a favorable gust, using the visible wind indicator.
			var next_leg: Vector2 = (waypoints[index + 1] - target).normalized()
			if ship.hull < 99 or level.wind.dot(next_leg) < 25:
				if not repairing_stop:
					print("Pilot repair shelter ", index, " hp=", ship.hull, " t=", level.elapsed)
				repairing_stop = true
				ship.helm = Vector2.ZERO
				ship.brace_command = true
				ship.repair_command = true
				await get_tree().physics_frame
				continue
			repairing_stop = false
			print("Pilot leave shelter ", index, " hp=", ship.hull, " t=", level.elapsed)
			index += 1
			target = waypoints[index]
		ship.repair_command = false
		# Visible surprise crests can be dodged even though they have no telegraph.
		for wave in level.get_node("Waves").get_children():
			if not active_front and ship.position.distance_to(waypoints[index]) > 650 and not wave.tsunami and wave.position.x > ship.position.x + 180 and wave.position.x < ship.position.x + 700:
				if absf(ship.position.y - wave.position.y) < wave.height / 2 + 70:
					var upper: float = clampf(wave.position.y - wave.height / 2 - 110, 150, 1450)
					var lower: float = clampf(wave.position.y + wave.height / 2 + 110, 150, 1450)
					var upper_cost: float = absf(ship.position.y - upper) + 0.8 * absf(target.y - upper)
					var lower_cost: float = absf(ship.position.y - lower) + 0.8 * absf(target.y - lower)
					if wave.position.y - wave.height / 2 - 110 < 100:
						upper_cost = INF
					if wave.position.y + wave.height / 2 + 110 > 1500:
						lower_cost = INF
					target = Vector2(minf(ship.position.x + 400, target.x), upper if upper_cost < lower_cost else lower)
					break
		if level.elapsed >= repath_at:
			path = grid.get_point_path(open_cell(grid, ship.position), open_cell(grid, target))
			repath_at = level.elapsed + 0.45
		var aim: Vector2 = target
		for point in path:
			if point.distance_to(ship.position) > 130:
				aim = point
				break
		if active_front:
			var clear_approach: bool = true
			for vortex in level.get_node("Whirlpools").get_children():
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(vortex.position, ship.position, target)
				if closest.distance_to(vortex.position) < vortex.radius + 85:
					clear_approach = false
			if clear_approach:
				aim = target
		ship.brace_command = false
		for wave in level.get_node("Waves").get_children():
			if wave.moving and wave.position.x > ship.position.x - 130 and wave.position.x < ship.position.x + 160:
				ship.brace_command = true
		if ship.in_whirlpool:
			ship.brace_command = false
		var travel: Vector2 = (aim - ship.position).normalized()
		var current: Vector2 = ship.drift + ship.whirlpool_pull
		var sideways: Vector2 = current - travel * current.dot(travel)
		var available_speed: float = ship.max_speed * (0.55 if ship.brace_command else 1.0)
		var forward: float = sqrt(maxf(625, available_speed * available_speed - sideways.length_squared()))
		var heading: float = angle_difference(ship.rotation, (travel * forward - sideways).angle())
		ship.helm = Vector2(clampf(heading / 0.45, -1, 1), 1.0 if absf(heading) < 0.85 else 0.0)
		if not calm_capture and ship.position.x > 1200:
			await screenshot("storm_hard_sailing")
			calm_capture = true
		await get_tree().physics_frame
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	print("HARD CROSSING: state=", level.state, "; time=", level.elapsed, "; hull=", level.ship.hull, "; position=", level.ship.position, "; tsunamis=", level.tsunami_index, "; surprise=", level.surprise_waves, "; gusts=", level.gust_changes)
	check(level.state == level.State.ARRIVAL, "A full hard crossing using leme, visual hazards and repair shelters must reach the sky passage.")
	check(level.tsunami_index == 5 and level.surprise_waves > 0 and level.gust_changes > 8, "The longer route must retain five tsunamis, occasional surprise waves and changing gusts.")
	# Always verify the actual physical ending even if the pilot failed the crossing.
	if level.state != level.State.ARRIVAL:
		level.free()
		await get_tree().process_frame
		level = new_level()
		level.start_sailing()
		level.ship.position = level.GOAL
		await frames(5)
	check(level.state == level.State.ARRIVAL and not level.ship.sailing and level.get_node("SkyIsland").visible, "Reaching the final area must stop navigation and reveal airborne Aeolia.")
	Engine.time_scale = 6
	await get_tree().create_timer(4.9).timeout
	check(level.get_node("SkyIsland").position.y < level.ship.position.y - 250, "The floating island must remain above the ship.")
	await screenshot("storm_aeolia_overhead")
	var arrival_clock: float = level.arrival_age
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	check(level.arrival_age == arrival_clock, "Pause must freeze the island flyover.")
	get_tree().paused = false
	await get_tree().create_timer(2.0).timeout
	Engine.time_scale = 1
	check(level.state == level.State.WON, "Victory must follow the island flyover, not a coastal landing.")
	await screenshot("storm_aeolia_victory")

func make_navigation_grid(level: Node2D) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 230, 16)
	grid.cell_size = Vector2(100, 100)
	grid.offset = Vector2(50, 50)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in 230:
		for y in 16:
			var point := Vector2(x * 100 + 50, y * 100 + 50)
			var blocked: bool = y == 0 or y == 15
			for rock in level.get_node("Rocks").get_children():
				if point.distance_to(rock.position) < 65 * rock.scale.x + 135:
					blocked = true
			for vortex in level.get_node("Whirlpools").get_children():
				if point.distance_to(vortex.position) < vortex.radius + 75:
					blocked = true
			grid.set_point_solid(Vector2i(x, y), blocked)
	return grid

func open_cell(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var cell := Vector2i(clampi(int(point.x / 100), 0, 229), clampi(int(point.y / 100), 1, 14))
	if not grid.is_point_solid(cell):
		return cell
	var result := cell
	var best: float = INF
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var candidate: Vector2i = cell + Vector2i(dx, dy)
			if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
				var distance: float = Vector2(candidate * 100 + Vector2i(50, 50)).distance_squared_to(point)
				if distance < best:
					best = distance
					result = candidate
	return result
