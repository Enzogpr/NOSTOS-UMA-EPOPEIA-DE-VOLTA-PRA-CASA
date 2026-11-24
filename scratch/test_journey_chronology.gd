extends SceneTree

const MANAGER := preload("res://Code/GameManager.gd")
const TIME := preload("res://Code/JourneyChronology.gd")
var checks := 0
var failures := 0
var folder: String

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> Node:
	var manager := MANAGER.new()
	manager.persistence_enabled = false
	return manager

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func reach_calypso(manager: Node) -> void:
	manager.unlock_level(2)
	manager.unlock_level(3)
	manager.unlock_level(4)
	manager.unlock_act4_stage(1)
	manager.unlock_act4_stage(2)
	manager.unlock_act4_stage(3)
	manager.complete_act4()
	manager.collect_circe_moly()
	manager.complete_circe_search()
	manager.complete_circe_battle()
	manager.complete_underworld_crossing()
	manager.record_underworld_vision(manager.UNDERWORLD_VISION_COUNT)
	manager.complete_underworld_prophecy()
	manager.complete_sirens(manager.player_current_hp)
	manager.complete_scylla()
	manager.complete_mutiny(manager.player_current_hp)
	manager.begin_calypso_stay()

func clocks_and_attributes() -> void:
	var manager := fresh()
	check(manager.player_age == 20 and manager.story_days == 0 and manager.sacrificed_years == 0, "The existing starting age is preserved")
	manager.complete_calypso()
	manager.record_calypso_years(7)
	manager.begin_calypso_stay()
	check(manager.story_days == 0 and manager.player_age == 20, "Locked or unsuccessful progression never ages the campaign")
	manager.unlock_level(2)
	check(manager.story_days == 0, "The earlier Trojan war is not charged again")
	manager.unlock_level(3)
	check(manager.story_days == 12 and manager.player_age == 20, "Lotus-eater travel and visit have a recorded duration")
	manager.unlock_level(4)
	check(manager.story_days == 47, "The Cyclops has its own distinct calendar milestone")
	manager.unlock_act4_stage(1)
	manager.unlock_act4_stage(2)
	check(manager.story_days == 200, "Aeolus adds a month after arrival")
	manager.unlock_act4_stage(3)
	check(manager.story_days == 209, "The vigil adds nine days")
	manager.complete_act4()
	manager.collect_circe_moly()
	manager.complete_circe_search()
	check(manager.story_days == 300 and manager.player_age == 20, "Travel fractions accumulate without rounding every island to a year")
	manager.player_current_hp = 4
	manager.complete_circe_battle()
	check(manager.story_days == 665 and manager.player_age == 21 and manager.sacrificed_years == 0, "Circe's year ages the hero without recording a sacrifice")
	check(is_equal_approx(manager.player_speed_mult, 1.08) and is_equal_approx(manager.player_dash_cooldown, 2.85), "Natural aging applies the existing age attributes")
	check(manager.player_current_hp == 4, "Natural aging never heals existing wounds")
	manager.complete_circe_battle()
	manager.complete_circe_search()
	manager.unlock_level(3)
	check(manager.story_days == 665 and manager.player_age == 21, "Replaying earlier completed stages neither rewinds nor duplicates time")
	manager.reset_encounter()
	check(manager.story_days == 665 and manager.player_age == 21, "Death and encounter reset preserve the calendar")
	var world_before: int = manager.story_days
	manager.sacrifice_year()
	check(manager.story_days == world_before and manager.player_age == 22 and manager.sacrificed_years == 1, "Sacrifice ages only Odisseu, leaving the world calendar unchanged")
	manager.free()

	manager = fresh()
	for year in 5: manager.sacrifice_year()
	reach_calypso(manager)
	var arrival_age: int = manager.player_age
	check(manager.story_days == 1077 and arrival_age == 27, "The whole pre-Calypso campaign includes lotophagi and Cyclops travel")
	manager.record_calypso_years(3)
	check(manager.player_age == arrival_age + 3 and manager.story_days == 2172, "The first visible Calypso time cut adds three years")
	manager.record_calypso_years(2)
	manager.begin_calypso_stay()
	check(manager.player_age == arrival_age + 3 and manager.story_days == 2172, "Reloading the island or repeating old seasons cannot charge them twice")
	manager.record_calypso_years(7)
	check(manager.player_age == arrival_age + 7 and manager.story_days == 3632, "All seven captivity years are applied exactly once")
	manager.complete_ogygia_paths()
	manager.complete_calypso()
	manager.complete_calypso()
	check(manager.player_age == arrival_age + 7 and manager.sacrificed_years == 5, "Freedom and raft departure do not add another seven years")
	manager.complete_charybdis()
	manager.complete_final_poseidon(manager.player_current_hp)
	manager.complete_ithaca(manager.player_current_hp)
	check(manager.story_days == TIME.RETURN_DAYS and manager.story_years() == 10, "The completed campaign spans exactly ten return years")
	check(manager.player_age == 35 and manager.sacrificed_years == 5, "Final age equals starting age plus ten natural years plus five sacrifices")
	var reference := fresh()
	for year in 15: reference.sacrifice_year()
	check(manager.player_damage == reference.player_damage and manager.player_max_hp == reference.player_max_hp and is_equal_approx(manager.player_speed_mult, reference.player_speed_mult) and is_equal_approx(manager.player_dash_cooldown, reference.player_dash_cooldown), "Mixed natural and sacrifice aging follows the same uninterrupted age curve")
	manager.record_calypso_years(7)
	manager.complete_act4()
	check(manager.story_days == 3650 and manager.player_age == 35, "Postgame replays cannot age the world again")
	manager.reset()
	check(manager.story_days == 0 and manager.sacrificed_years == 0 and manager.player_age == 20, "A new campaign resets both counters and age")
	reference.free()
	manager.free()

	manager = fresh()
	manager.standalone_stage_preview = true
	manager.mutiny_completed = true
	manager.begin_calypso_stay()
	manager.record_calypso_years(7)
	manager.complete_ogygia_paths()
	manager.complete_calypso()
	check(manager.story_days == 3632 and manager.player_age == 29 and not manager.persistence_enabled, "Independent F6 previews simulate narrative age without writing campaign years")
	manager.free()

func persistence_and_migration() -> void:
	var manager := fresh()
	manager.persistence_enabled = true
	manager.save_file_path = folder.path_join("campaign.json")
	for year in 3: manager.sacrifice_year()
	reach_calypso(manager)
	manager.record_calypso_years(3)
	var age: int = manager.player_age
	var days: int = manager.story_days
	var loaded := fresh()
	loaded.save_file_path = manager.save_file_path
	check(loaded.load_game() and loaded.player_age == age and loaded.story_days == days and loaded.sacrificed_years == 3, "Partial Calypso aging and separate sacrifice count survive reload")
	var stored := bytes(manager.save_file_path)
	loaded.load_game()
	loaded.begin_calypso_stay()
	loaded.record_calypso_years(3)
	check(loaded.player_age == age and loaded.story_days == days and bytes(manager.save_file_path) == stored, "Repeated loads and old seasons never duplicate time or rewrite the save")
	loaded.persistence_enabled = true
	loaded.record_calypso_years(7)
	check(loaded.player_age == age + 4, "A resumed captivity applies only its four remaining years")
	manager.load_game()
	check(manager.player_age == age + 4 and manager.story_days == 3632, "The remaining years autosave immediately")
	var old_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manager.save_file_path))
	old_data.erase("chronology_version")
	old_data.erase("story_days")
	old_data.erase("sacrificed_years")
	old_data.player_age = 35
	old_data.player_max_hp = 8
	old_data.player_current_hp = 4
	old_data.player_damage = 9
	old_data.player_speed_mult = 1.48
	old_data.player_dash_cooldown = 1.65
	old_data.ogygia_paths_completed = true
	old_data.calypso_completed = true
	var file := FileAccess.open(manager.save_file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()
	stored = bytes(manager.save_file_path)
	check(loaded.load_game() and loaded.player_age == 44 and loaded.story_days == 3632 and loaded.sacrificed_years == 15, "Legacy progression adds only missing natural years and preserves its fifteen sacrificed years")
	check(loaded.player_current_hp == 3 and loaded.player_max_hp == 3, "Legacy aging clamps wounds to reduced capacity without granting healing")
	var legacy_age: int = loaded.player_age
	loaded.load_game()
	check(loaded.player_age == legacy_age and bytes(manager.save_file_path) == stored, "Legacy migration is repeatable and does not overwrite the original file on load")
	loaded.save_game()
	loaded.load_game()
	check(loaded.player_age == legacy_age and loaded.sacrificed_years == 15, "Saving the migrated version prevents any second migration")
	manager.free()
	loaded.free()

func view_checks(manager: Node) -> void:
	manager.reset()
	for year in 5: manager.sacrifice_year()
	reach_calypso(manager)
	manager.record_calypso_years(7)
	root.size = Vector2i(1152, 648)
	var map: Control = load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await process_frame
	check(map.get_node("Chart/UI/TimeLabel").text.contains("9 anos") and map.get_node("Chart/UI/TimeLabel").text.contains("34"), "The map distinguishes story duration from Odisseu's age")
	var stats: Node = root.get_node("PlayerStatsMenu")
	stats.toggle_menu()
	check(stats.status_label.text.contains("Anos sacrificados: 5") and stats.status_label.text.contains("Retorno: 9 anos"), "Attributes show natural time and sacrifice years separately")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("chronology_attributes.png"))
	stats.toggle_menu()
	manager.sacrifice_year()
	check(map.get_node("Chart/UI/TimeLabel").text.contains("35") and manager.story_days == 3632, "The map updates age after sacrifice without advancing world time")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder.path_join("chronology_map.png"))
	map.queue_free()
	await process_frame

func run() -> void:
	var manager: Node = root.get_node("GameManager")
	var original := bytes(MANAGER.SAVE_FILE_PATH)
	manager.persistence_enabled = false
	folder = OS.get_environment("TEMP").path_join("nostos_chronology_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	clocks_and_attributes()
	persistence_and_migration()
	await view_checks(manager)
	check(bytes(MANAGER.SAVE_FILE_PATH) == original, "Every test leaves the real player save byte-identical")
	manager.reset()
	print("CHRONOLOGY: %d checks, %d failures; artifacts: %s" % [checks, failures, folder])
	quit(0 if failures == 0 else 1)
