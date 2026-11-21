extends SceneTree

const FIGHT := preload("res://Ato13_Itaca/Gameplay/SuitorsFight.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const SCENE := "res://Ato13_Itaca/Gameplay/Ithaca.tscn"
const STEP := 1.0 / 120.0
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func advance(model: FIGHT, seconds: float) -> void:
	for step in ceili(seconds / STEP):
		model.tick(STEP)

func aim_bow(model: FIGHT, point: Vector2, pull: float) -> void:
	model.set_input(Vector2.ZERO, point, false)
	model.attack_down()
	advance(model, pull)
	model.attack_up()

func nearest_fighter(model: FIGHT) -> FIGHT.Fighter:
	var nearest: FIGHT.Fighter
	var score := INF
	for fighter in model.fighters:
		if fighter.hp == 0:
			continue
		var distance := model.position.distance_to(fighter.position)
		if not model.clear_segment(model.position, fighter.position, 6): distance += 110.0
		if fighter.role == FIGHT.Role.SHIELD and fighter.state == FIGHT.State.SEEK: distance += 18.0
		if distance < score:
			nearest = fighter
			score = distance
	return nearest

func imminent(model: FIGHT, window: float) -> Vector2:
	var source := Vector2.ZERO
	var soonest := window
	for fighter in model.fighters:
		var remaining := model.windup(fighter) - fighter.age
		if fighter.state == FIGHT.State.DRAW and fighter.role != FIGHT.Role.BOW and remaining < soonest:
			var to_player := fighter.position.direction_to(model.position)
			if model.position.distance_to(fighter.position) < 123.0 and fighter.direction.dot(to_player) > 0.54:
				if model.clear_segment(model.position, fighter.position):
					source = fighter.position
					soonest = remaining
	for arrow in model.arrows:
		var end := arrow.position + arrow.direction * 615.0 * soonest
		var contact := Geometry2D.get_closest_point_to_segment(model.position, arrow.position, end)
		if contact.distance_to(model.position) < 18.0 and model.clear_segment(arrow.position, contact):
			soonest = contact.distance_to(arrow.position) / 615.0
			source = arrow.position - arrow.direction * 33.0
	return source

func move_to(model: FIGHT, at: Vector2) -> Vector2:
	if model.clear_segment(model.position, at, 12):
		return model.position.direction_to(at)
	var from := Vector2i((model.position / FIGHT.CELL).floor())
	var to := Vector2i((at / FIGHT.CELL).floor())
	var route := model.navigation.get_point_path(from, to, true)
	for index in range(1, route.size()):
		if route[index].distance_to(model.position) > 13.0 and model.clear_segment(model.position, route[index], 12):
			return model.position.direction_to(route[index])
	return model.position.direction_to(at)

func fight_step(model: FIGHT) -> void:
	var fighter := nearest_fighter(model)
	if fighter == null:
		model.tick(STEP)
		return
	var distance := model.position.distance_to(fighter.position)
	var target: Vector2 = fighter.position
	var movement := move_to(model, target) if distance > 94.0 else Vector2.ZERO
	var source := imminent(model, 0.135)
	if source != Vector2.ZERO:
		model.set_input(Vector2.ZERO, source, true)
	elif fighter.role == FIGHT.Role.SHIELD and fighter.state == FIGHT.State.SEEK and model.dash_recharge == 0.0 and distance < 136.0 and model.clear_segment(model.position, target, 12):
		model.set_input(model.position.direction_to(target), target, false)
		model.dash()
	else:
		model.set_input(movement, target, false)
		if distance < 115.0 and model.clear_segment(model.position, target) and imminent(model, 0.23) == Vector2.ZERO and (fighter.role != FIGHT.Role.SHIELD or fighter.state != FIGHT.State.SEEK):
			model.attack_down()
	model.tick(STEP)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var result := root.get_texture().get_image()
	if result:
		result.save_png(OS.get_environment("TEMP").path_join("nostos_ithaca_" + name + ".png"))

func check_old_save() -> void:
	var manager := MANAGER.new()
	manager.save_file_path = OS.get_environment("TEMP").path_join("nostos_ithaca_%d.json" % Time.get_ticks_usec())
	var save := FileAccess.open(manager.save_file_path, FileAccess.WRITE)
	save.store_string(JSON.stringify({
		"highest_unlocked_level": 12, "player_age": 41, "player_current_hp": 7,
		"circe_moly_found": true, "circe_search_completed": true, "circe_battle_completed": true,
		"underworld_crossing_completed": true, "underworld_vision_index": 3, "underworld_prophecy_completed": true,
		"sirens_completed": true, "scylla_completed": true, "mutiny_completed": true,
		"ogygia_paths_completed": true, "calypso_completed": true, "charybdis_completed": true, "final_poseidon_completed": true,
	}))
	save.close()
	check(manager.load_game() and manager.highest_unlocked_level == 13 and not manager.ithaca_completed, "An older post-Poseidon save unlocks the hall")
	manager.complete_ithaca(6)
	manager.reset()
	check(not manager.ithaca_completed and manager.load_game() and manager.ithaca_completed and manager.player_current_hp == 6 and manager.player_age == 41, "The ending survives reload and resets for a new campaign")
	DirAccess.remove_absolute(manager.save_file_path)
	manager.free()

func check_agility() -> void:
	for profile in [Vector3(0.3, 3.0, 3), Vector3(1.72, 0.5, 8)]:
		var combat := FIGHT.new()
		combat.apply_stats({"max_hp": 10, "current_hp": 1, "damage": int(profile.z), "speed_mult": profile.x, "dash_cooldown": profile.y})
		combat.start()
		aim_bow(combat, combat.ring_at(11), 0.66)
		advance(combat, 2.58)
		for frame in 21500:
			if combat.phase in [FIGHT.Phase.EPILOGUE, FIGHT.Phase.LOST]:
				break
			fight_step(combat)
		check(combat.phase == FIGHT.Phase.EPILOGUE, "All waves are passable with one HP at agility %.2f" % profile.x)
		print("Ithaca agility=", profile.x, " t=", snappedf(combat.clock, 0.1), " wave=", combat.wave + 1, " remaining=", combat.remaining(), " hp=", combat.hp)

func check_cover_and_shield() -> void:
	var model := FIGHT.new()
	model.position = Vector2(422, 340)
	var arrow := FIGHT.Arrow.new()
	arrow.position = Vector2(300, 340)
	arrow.direction = Vector2.RIGHT
	model.arrows.append(arrow)
	for step in 32: model._arrows_tick(STEP)
	check(model.arrows.is_empty() and model.hp == 10, "An actual arrow stops at the column before the player")
	model.position = Vector2(560, 300)
	model._spawn_round(1)
	var shield := model.fighters[0]
	shield.position = Vector2(697, 300)
	shield.facing = Vector2.LEFT
	model.attack_direction = Vector2.RIGHT
	model._swing()
	check(shield.hp == shield.max_hp, "A shield stops frontal damage while the guard is up")
	model._set_fighter(shield, FIGHT.State.REST)
	model._swing()
	check(shield.hp == shield.max_hp - model.damage, "The sword lands during the shield user's recovery")

func run() -> void:
	var manager: Node = root.get_node("GameManager")
	var preview: bool = manager.standalone_stage_preview
	manager.persistence_enabled = false
	manager.reset()
	manager.player_age = 35
	manager.player_current_hp = 8
	manager.complete_ithaca(6)
	check(not manager.ithaca_completed, "The victory requires the final Poseidon milestone")
	var scene: Control = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	check(scene.locked != preview, "F6 starts independently while campaign access is gated")
	scene.queue_free()
	await process_frame
	manager.charybdis_completed = true
	manager.complete_final_poseidon(8)
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check(manager.highest_unlocked_level == 13 and map.stops.size() == 19 and map.stops[18].level_scene == SCENE and map.stops[18].is_unlocked(), "The palace appears after winning against Poseidon")
	map.queue_free()
	await process_frame

	scene = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.restart_checkpoint()
	var model: FIGHT = scene.fight
	aim_bow(model, model.ring_at(11), 0.13)
	check(model.bow_age < 0.0, "The bow requires tension before release")
	aim_bow(model, Vector2(850, 501), 0.52)
	advance(model, 1.0)
	check(model.phase == FIGHT.Phase.BOW and not model.bow_passed, "A bad angle can be retried without damage")
	model.set_input(Vector2.ZERO, model.ring_at(11), false)
	model.attack_down()
	advance(model, 0.66)
	scene._refresh()
	await capture("bow")
	model.attack_up()
	advance(model, 2.58)
	check(model.phase == FIGHT.Phase.FIGHT and model.remaining() == 4, "A single arrow through the twelve axes opens the first round")
	check(not model.clear_segment(Vector2(250, 340), Vector2(440, 340)) and model.clear_segment(Vector2(250, 400), Vector2(440, 400)), "A column blocks attacks and sight while the aisle is open")
	var life := model.hp
	model._hurt(model.position + Vector2(100, 0))
	check(model.hp == life - 1, "A normal hit deals one damage")
	model.retry()
	check(model.hp == life and model.phase == FIGHT.Phase.FIGHT and model.wave == 0, "Retry resumes the round without replaying the bow")
	advance(model, 1.6)
	scene._refresh()
	await capture("hall")
	for frame in 21000:
		if model.phase == FIGHT.Phase.EPILOGUE or model.phase == FIGHT.Phase.LOST:
			break
		fight_step(model)
	print("Ithaca route time=", snappedf(model.clock, 0.1), " wave=", model.wave + 1, " remaining=", model.remaining(), " hp=", model.hp)
	check(model.phase == FIGHT.Phase.EPILOGUE, "A route through all three live waves reaches the epilogue")
	check(not manager.ithaca_completed, "The final scene precedes the campaign milestone")
	advance(model, 3.4)
	scene._refresh()
	await capture("home")
	advance(model, FIGHT.END_TIME)
	check(model.phase == FIGHT.Phase.WON and manager.ithaca_completed != preview, "The campaign saves the win and preview stays isolated")
	check(manager.player_age == 35 and manager.player_current_hp == (8 if preview else model.hp), "The win preserves age and carries remaining health")
	check_old_save()
	check_agility()
	check_cover_and_shield()
	scene.queue_free()
	await process_frame
	print("ITHACA: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
