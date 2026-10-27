extends SceneTree
const Manager := preload("res://Code/GameManager.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func file_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func run() -> void:
	var global_manager: Node = root.get_node("GameManager")
	var original_save := file_bytes(Manager.SAVE_FILE_PATH)
	var fixture_path: String = OS.get_environment("TEMP").path_join("odisseia_sacrifice_%d.json" % Time.get_ticks_usec())
	var manager := Manager.new()
	manager.save_file_path = fixture_path
	manager.sacrifice_year()
	check(FileAccess.file_exists(fixture_path),"A sacrifice writes its new attributes immediately")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(data.player_age == 21 and is_equal_approx(data.player_speed_mult,1.08),"Autosave contains the sacrificed age and speed")
	var loaded := Manager.new()
	loaded.save_file_path = fixture_path
	check(loaded.load_game() and loaded.player_age == 21 and is_equal_approx(loaded.player_dash_cooldown,2.85),"A fresh manager resumes the sacrificed attributes")
	manager.inventory = [{"id":"preserved"}]
	manager.highest_unlocked_level = 4
	manager.suspicion = 80
	manager.game_over = true
	manager.combat_mode = true
	manager.has_player_moved = true
	manager.reset_encounter()
	check(manager.player_age == 21 and manager.inventory[0].id == "preserved" and manager.highest_unlocked_level == 4,"Encounter reset preserves sacrificed age, inventory and unlocked acts")
	check(manager.suspicion == 0 and not manager.game_over and not manager.combat_mode and not manager.has_player_moved,"Encounter reset clears only transient encounter state")
	var previous_bytes := file_bytes(fixture_path)
	manager.persistence_enabled = false
	manager.sacrifice_year()
	check(manager.player_age == 22 and file_bytes(fixture_path) == previous_bytes,"Isolated previews can disable persistence without disabling attribute changes")
	manager.reset()
	check(manager.player_age == 20 and manager.player_damage == 3 and manager.inventory.is_empty() and manager.highest_unlocked_level == 1,"Explicit full reset still starts a new campaign")
	manager.free()
	loaded.free()

	global_manager.persistence_enabled = false
	global_manager.reset()
	for i in 9: global_manager.sacrifice_year()
	var actor := CharacterBody2D.new()
	actor.set_script(load("res://Code/Player.gd"))
	root.add_child(actor)
	actor.set_physics_process(false)
	global_manager.player_current_hp = 7
	global_manager.player_health_changed.emit(7)
	global_manager.sacrifice_year()
	check(actor.max_hp == 9 and actor.current_hp == 7 and global_manager.player_current_hp == 7,"A live player adopts reduced max HP without healing current wounds")
	check(global_manager.player_damage == 4,"The age30 damage increase remains available to the live player")
	for i in 9: global_manager.sacrifice_year()
	global_manager.player_current_hp = 8
	global_manager.player_health_changed.emit(8)
	actor._dash_cooldown_total = global_manager.player_dash_cooldown
	actor._dash_cooldown.start(global_manager.player_dash_cooldown*0.6)
	global_manager.sacrifice_year()
	check(actor.max_hp == 7 and actor.current_hp == 7,"Sacrifice clamps live HP immediately when capacity drops below current HP")
	check(is_equal_approx(actor._dash_cooldown_total,1.75) and absf(actor._dash_cooldown.time_left-1.05)<0.001,"Live dash cooldown retains its remaining fraction across an age change")
	global_manager.sacrifice_year()
	check(is_equal_approx(actor._dash_cooldown_total,1.85) and absf(actor._dash_cooldown.time_left-1.11)<0.001,"Repeated sacrifices cannot reset a partially charged dash")
	actor.queue_free()
	await process_frame
	await process_frame

	global_manager.reset()
	for i in 15: global_manager.sacrifice_year()
	global_manager.highest_unlocked_level = 4
	global_manager.inventory = [{"id":"troia_preserved"}]
	var gate: Node = load("res://Ato1_Troia/Fase1_PortaoDeTroia.tscn").instantiate()
	root.add_child(gate)
	current_scene = gate
	await process_frame
	check(global_manager.player_age == 35 and global_manager.player_damage == 9,"Entering the real Trojan gate scene preserves sacrificed attributes")
	check(global_manager.highest_unlocked_level == 4 and global_manager.inventory[0].id == "troia_preserved","Entering the real Trojan gate scene preserves inventory and progression")
	gate.queue_free()
	await process_frame
	await process_frame
	check(original_save == file_bytes(Manager.SAVE_FILE_PATH),"All verification leaves the real campaign save byte-identical")
	global_manager.reset()
	global_manager.persistence_enabled = true
	DirAccess.remove_absolute(fixture_path)
	print("SACRIFICE_PERSISTENCE ", checks, " CHECKS ", failures, " FAILURES")
	quit(0 if failures == 0 else 1)
