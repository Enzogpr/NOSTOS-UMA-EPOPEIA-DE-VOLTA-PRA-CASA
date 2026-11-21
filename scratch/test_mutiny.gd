extends SceneTree

const FIGHT := preload("res://Ato9_Motim/Gameplay/MutinyFight.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const SCENE := "res://Ato9_Motim/Gameplay/Mutiny.tscn"
const STEP := 1.0 / 120.0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh(hp: int = 10, speed: float = 1.0, damage: int = 3) -> FIGHT:
	var duel := FIGHT.new()
	duel.apply_attributes({"max_hp": hp, "current_hp": hp, "damage": damage, "speed_mult": speed, "dash_cooldown": 3.0})
	duel.begin()
	return duel

func advance(duel: FIGHT, duration: float, axis: Vector2 = Vector2.ZERO, guard: bool = false) -> void:
	for frame in ceili(duration / STEP):
		duel.tick(STEP, axis, duel.enemy - duel.position, guard)

func attack_at(duel: FIGHT, gap: float = 65.0) -> void:
	duel.enemy = duel.position + Vector2(gap, 0)
	duel.enemy_facing = Vector2.LEFT
	duel.stance = FIGHT.Stance.STRIKE
	duel.stance_age = 0.0
	duel.contacted = false

func duel_route(hp: int, speed: float, damage: int) -> FIGHT:
	var duel := fresh(hp, speed, damage)
	for frame in 100 * 120:
		if duel.phase != FIGHT.Phase.DUEL:
			break
		var to_enemy := duel.enemy - duel.position
		var axis := Vector2.ZERO
		var guard := false
		var windup := duel.windup_duration()
		if duel.stance == FIGHT.Stance.WINDUP:
			guard = duel.stance_age >= windup - 0.045
		elif duel.stance == FIGHT.Stance.STRIKE:
			guard = true
		elif duel.stance == FIGHT.Stance.RECOVERY:
			axis = to_enemy.normalized() if to_enemy.length() > 67.0 else Vector2.ZERO
			if to_enemy.length() <= FIGHT.SWORD_REACH - 3.0 and duel.recovery - duel.stance_age >= 0.175:
				duel.attack(to_enemy)
		elif to_enemy.length() > 170.0:
			axis = to_enemy.normalized()
		duel.tick(STEP, axis, to_enemy, guard)
	return duel

func run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.persistence_enabled = false
	var duel := fresh()
	check(duel.resolve == 15, "Eurylochus starts the duel at fifteen health")
	attack_at(duel)
	advance(duel, 0.15)
	check(duel.hp == 8, "An unblocked sword hit costs exactly two life points")
	duel = fresh()
	attack_at(duel, 146.0)
	advance(duel, 0.08)
	check(duel.hp == 8, "The greatsword sweep reaches farther than the former sword")
	duel = fresh()
	attack_at(duel)
	advance(duel, 0.14, Vector2.ZERO, true)
	check(duel.hp == 10 and duel.guard == 85.0 and duel.stance == FIGHT.Stance.RECOVERY and duel.recovery > 1.0, "A timed frontal guard opens a longer counterattack window")
	duel = fresh()
	attack_at(duel)
	for frame in 12:
		duel.tick(STEP, Vector2.ZERO, Vector2.LEFT, true)
	check(duel.hp == 8 and duel.guard_break > 0.0, "Facing away cannot block the attack")
	duel = fresh()
	duel.pressured = true
	attack_at(duel)
	duel.enemy_facing = Vector2.RIGHT
	advance(duel, 0.24)
	check(duel.hp == 10 and duel.stance == FIGHT.Stance.WINDUP and duel.second_swing and duel.pattern == 1, "Dodging the first late sweep exposes the shorter follow-up instead of an early counterattack window")
	duel = fresh()
	duel.enemy = duel.position + Vector2(72, 0)
	duel.stance = FIGHT.Stance.WINDUP
	duel.attack(Vector2.RIGHT)
	advance(duel, 0.18)
	check(duel.resolve == FIGHT.RESOLVE_MAX, "Attacking a closed stance cannot brute-force the duel")
	duel.enemy = duel.position + Vector2(113, 0)
	duel.stance = FIGHT.Stance.RECOVERY
	duel.recovery = 10.0
	duel.stance_age = 0.0
	advance(duel, 0.45)
	duel.attack(Vector2.RIGHT)
	advance(duel, 0.18)
	check(duel.resolve == FIGHT.RESOLVE_MAX - duel.damage, "Odisseu applies campaign damage beyond his former sword reach")
	duel = fresh(1)
	attack_at(duel)
	advance(duel, 0.1)
	check(duel.phase == FIGHT.Phase.LOST and duel.hp == 0, "Running out of life is a retry, separate from the mutiny scene")
	duel.restart()
	duel.dash(Vector2.UP)
	advance(duel, 0.16)
	check(duel.hp == 1 and duel.position.y < 358.0 and duel.dash_recharge > 2.5, "Retry preserves entry HP and the dash uses the campaign cooldown")
	for profile in [[10, 1.0, 3], [1, 0.3, 3], [6, 1.72, 13]]:
		duel = duel_route(profile[0], profile[1], profile[2])
		check(duel.phase == FIGHT.Phase.DISARMED and duel.hp == profile[0] and duel.pressured, "A complete counterattack route disarms Eurylochus at speed %.2f and %d HP" % [profile[1], profile[0]])
		print("Mutiny route speed=", profile[1], " time=", snappedf(duel.clock, 0.01), " hp=", duel.hp, " resolve=", duel.resolve)
	gm.complete_mutiny(8)
	check(not gm.mutiny_completed, "Completion cannot skip Cila")
	gm.sirens_completed = true
	gm.complete_scylla()
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	check(map.stops.size() == 19 and map.stops[13].is_unlocked() and map.stops[13].level_scene == SCENE, "Cila opens the actual Motim scene on the campaign map")
	map.queue_free()
	await process_frame
	var scene: Control = load(SCENE).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	check(scene.mode == scene.Mode.INTRO, "The scene starts with the confrontation before arming the player")
	for duration in [4.5, 4.5, 1.0]:
		scene._update_story(duration)
	scene.advance_story()
	check(scene.mode == scene.Mode.DUEL and scene.fight.phase == FIGHT.Phase.DUEL, "The final intro beat hands control to the real duel scene")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame in 12:
		await physics_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	check(scene.fight.position.y < 391.0, "The controller accepts real vertical movement")
	check(not scene.arena.dash_bar.visible and not scene.hero_label.text.contains("DASH"), "The duel has no footer timer or idle recharge bar")
	var dash_key := InputEventKey.new()
	dash_key.physical_keycode = KEY_Q
	dash_key.pressed = true
	scene._unhandled_input(dash_key)
	advance(scene.fight, 0.45)
	scene.arena.update_view(0.0)
	check(scene.arena.dash_bar.visible and scene.arena.dash_bar.position.is_equal_approx(scene.fight.position), "The recharge bar follows Odisseu across the deck")
	check(is_equal_approx(scene.arena.dash_bar.progress, 0.45 / scene.fight.dash_cooldown), "The recharge bar fills with the actual dash cooldown")
	var capture_dash := OS.get_cmdline_user_args().has("--capture-dash")
	if capture_dash or OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(1152, 648)
		scene.set_physics_process(false)
		scene.fight.position = Vector2(445, 411)
		scene.fight.facing = Vector2.RIGHT
		scene.fight.enemy = Vector2(612, 409)
		scene.fight.enemy_facing = Vector2.LEFT
		scene.fight.stance = FIGHT.Stance.STRIKE
		scene.fight.stance_age = 0.105
		scene.fight.dash_recharge = scene.fight.dash_cooldown * 0.35 if capture_dash else 0.0
		scene.arena.update_view(0.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var folder := "res://scratch/campaign_review/mutiny"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		root.get_texture().get_image().save_png(folder.path_join("dash_motim.png" if capture_dash else "espadão.png"))
	scene.fight.dash_recharge = 0.0
	scene.arena.update_view(0.0)
	check(not scene.arena.dash_bar.visible, "The recharge bar hides when the dash is ready again")
	scene.fight.hp = 7
	scene.fight.phase = FIGHT.Phase.DISARMED
	scene._physics_process(0.9)
	check(scene.mode == scene.Mode.AFTER and scene.story.shot == "intervene" and not gm.mutiny_completed, "The crew intervenes before completion can be recorded")
	for duration in [2.7, 4.2, 4.6, 4.4, 2.1, 4.1, 3.7]:
		scene._update_story(duration)
	check(scene.mode == scene.Mode.DONE and gm.mutiny_completed and gm.player_current_hp == 7 and gm.highest_unlocked_level == 10, "The thunder ending records the first victory and preserves remaining HP")
	gm.complete_mutiny(1)
	check(gm.player_current_hp == 7, "Replaying the Motim cannot apply campaign damage a second time")
	scene.queue_free()
	await process_frame
	var save := MANAGER.new()
	save.save_file_path = OS.get_environment("TEMP").path_join("nostos_mutiny_%d.json" % Time.get_ticks_usec())
	var old := FileAccess.open(save.save_file_path, FileAccess.WRITE)
	old.store_string(JSON.stringify({"highest_unlocked_level": 8, "circe_moly_found": true, "circe_search_completed": true, "circe_battle_completed": true, "underworld_crossing_completed": true, "underworld_vision_index": 3, "underworld_prophecy_completed": true, "sirens_completed": true, "scylla_completed": true}))
	old.close()
	check(save.load_game() and save.highest_unlocked_level == 9 and not save.mutiny_completed, "An existing Cila save migrates to the new available stop")
	save.complete_mutiny(4)
	save.reset()
	check(not save.mutiny_completed and save.load_game() and save.mutiny_completed and save.player_current_hp == 4, "The Motim flag survives reload and is cleared in a new game")
	DirAccess.remove_absolute(save.save_file_path)
	save.free()
	print("MUTINY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
