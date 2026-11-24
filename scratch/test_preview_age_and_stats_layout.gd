extends SceneTree

const MANAGER := preload("res://Code/GameManager.gd")
const CHRONOLOGY := preload("res://Code/JourneyChronology.gd")
const CARIBDIS := "res://Ato11_Caribdis/Gameplay/Charybdis.tscn"
const CALYPSO := "res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn"
var checks := 0
var failures := 0
var artifacts: String

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func preview_checks() -> void:
	for path in MANAGER.STANDALONE_STAGES:
		var manager := MANAGER.new()
		manager.persistence_enabled = false
		check(manager.prepare_standalone_stage(path), "Every isolated scene has a chronology entry: " + path)
		check(manager.player_age == 20 + CHRONOLOGY.years(CHRONOLOGY.stage_entry_day(path)), "Direct scene uses the age at its narrative entry")
		check(not manager.persistence_enabled and not manager.calypso_completed and not manager.circe_battle_completed, "Age simulation neither saves nor grants campaign completion")
		manager.free()
	var manager := MANAGER.new()
	manager.persistence_enabled = false
	manager.prepare_standalone_stage(CARIBDIS)
	check(manager.player_age == 29 and manager.story_days == 3632 and manager.sacrificed_years == 0, "Caribdis begins after Calypso's seven years, at age29 without sacrifices")
	check(is_equal_approx(manager.player_speed_mult, 1.72) and is_equal_approx(manager.player_dash_cooldown, 1.65), "The preview uses real natural-aging attributes")
	manager.prepare_standalone_stage(CARIBDIS)
	check(manager.player_age == 29, "Repeating an entry cannot add the nine years again")
	manager.free()
	manager = MANAGER.new()
	manager.persistence_enabled = false
	manager.prepare_standalone_stage(CALYPSO)
	manager.player_current_hp = 6
	check(manager.player_age == 22, "Direct Calypso begins before the seven-year captivity")
	manager.record_calypso_years(3)
	check(manager.player_age == 25 and manager.player_current_hp == 6, "The first three visible island years affect preview age without healing")
	manager.record_calypso_years(7)
	check(manager.player_age == 29 and manager.sacrificed_years == 0, "The seven-year time cut affects previews as well as campaigns")
	manager.prepare_standalone_stage(CARIBDIS)
	check(manager.player_age == 29 and manager.story_days == 3632, "Following Calypso to Caribdis does not reset or duplicate age")
	manager.sacrifice_year()
	check(manager.player_age == 30 and manager.sacrificed_years == 1 and manager.story_days == 3632, "A preview sacrifice remains separate from natural years")
	manager.free()

func inconsistent_save_checks() -> void:
	var fixture := artifacts.path_join("inconsistent_save.json")
	var data := {
		"chronology_version":1, "story_days":0, "sacrificed_years":5,
		"player_age":25, "player_current_hp":6, "player_max_hp":10,
		"player_speed_mult":1.4, "player_dash_cooldown":2.25,
		"highest_unlocked_level":11, "circe_moly_found":true,
		"circe_search_completed":true, "circe_battle_completed":true,
		"underworld_crossing_completed":true, "underworld_vision_index":6,
		"underworld_prophecy_completed":true, "sirens_completed":true,
		"scylla_completed":true, "mutiny_completed":true,
		"ogygia_paths_completed":true, "calypso_completed":true,
	}
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var before := bytes(fixture)
	var manager := MANAGER.new()
	manager.save_file_path = fixture
	check(manager.load_game() and manager.player_age == 34 and manager.story_days == 3632, "A progressed version1 save with zero days recovers its missing natural years")
	check(manager.sacrificed_years == 5 and manager.player_current_hp == 6, "Repair preserves sacrifices and wounds")
	manager.load_game()
	check(manager.player_age == 34 and bytes(fixture) == before, "Repair is idempotent and never rewrites on load")
	manager.save_game()
	manager.load_game()
	check(manager.player_age == 34 and manager.story_days == 3632, "Saving the repaired calendar prevents a second aging")
	manager.free()
	DirAccess.remove_absolute(fixture)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(artifacts.path_join(name+".png"))

func layout_checks(manager: Node) -> void:
	manager.reset()
	manager.prepare_standalone_stage(CARIBDIS)
	var scene: Control = load(CARIBDIS).instantiate()
	scene.audio_enabled = false
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var menu: Node = root.get_node("PlayerStatsMenu")
	menu.toggle_menu()
	check(menu.control.visible and paused and menu.age_label.text == "Idade: 29", "Opening TAB in Caribdis shows the simulated age and pauses gameplay")
	check(menu.status_label.text.contains("9 anos") and menu.status_label.text.contains("sem salvar"), "The panel explains the temporary preview and its elapsed return time")
	var diagram: Control = menu.get_node("Control/Layout/Diagram")
	var centers := {"CenterNode":Vector2(251,247),"TopNode":Vector2(247,81),"LeftNode":Vector2(91,198),"RightNode":Vector2(409,203),"BottomLeftNode":Vector2(154,386),"BottomRightNode":Vector2(350,390)}
	for dimensions in [Vector2i(1152,648),Vector2i(900,620),Vector2i(1600,900)]:
		root.size = dimensions
		await create_timer(0.12).timeout
		menu.control.size = Vector2(dimensions)
		menu._fit_menu()
		check(is_equal_approx(diagram.size.x,diagram.size.y), "The diagram remains square at " + str(dimensions))
		var window := Rect2(Vector2.ZERO,Vector2(dimensions))
		check(window.encloses(menu.layout.get_global_rect()), "The full menu stays inside the viewport at " + str(dimensions))
		for node_name: String in centers:
			var group: Control = diagram.get_node(node_name)
			check((group.position+group.size*0.5).distance_to(centers[node_name])<0.1, "Attribute text matches its painted circle center: "+node_name)
		check(window.encloses(menu.sacrifice_btn.get_global_rect()) and window.encloses(menu.close_btn.get_global_rect()), "Both buttons stay on screen and below the diagram")
		await capture("attributes_%dx%d" % [dimensions.x,dimensions.y])
	var before_days: int = manager.story_days
	menu._on_sacrifice_pressed()
	check(manager.player_age == 30 and manager.sacrificed_years == 1 and manager.story_days == before_days, "The framed sacrifice button still uses the separate aging mechanic")
	menu.toggle_menu()
	check(not paused, "Closing the menu restores gameplay")
	scene.queue_free()
	await process_frame

func run() -> void:
	var manager: Node = root.get_node("GameManager")
	var before := bytes(manager.SAVE_FILE_PATH)
	manager.persistence_enabled = false
	artifacts = OS.get_environment("TEMP").path_join("nostos_stats_frame_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(artifacts)
	preview_checks()
	inconsistent_save_checks()
	await layout_checks(manager)
	check(bytes(manager.SAVE_FILE_PATH) == before, "Preview, layout tests, and save repair leave the real campaign save byte-identical")
	print("PREVIEW_AGE_AND_STATS: %d checks, %d failures; artifacts: %s" % [checks,failures,artifacts])
	quit(0 if failures == 0 else 1)
