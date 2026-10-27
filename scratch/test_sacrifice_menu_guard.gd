extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func run() -> void:
	var gm: Node=root.get_node("GameManager")
	var menu: Node=root.get_node("PlayerStatsMenu")
	var before: PackedByteArray=FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var fixture: String=OS.get_environment("TEMP").path_join("odisseia_menu_sacrifice_%d.json" % Time.get_ticks_usec())
	gm.save_file_path=fixture
	gm.reset()
	gm.highest_unlocked_level=4
	gm.save_game()
	var stored: PackedByteArray=FileAccess.get_file_as_bytes(fixture)
	var title: Node=load("res://Scenes/TitleScreen.tscn").instantiate()
	root.add_child(title)
	current_scene=title
	menu.toggle_menu()
	check(not menu.control.visible and not paused,"The title screen cannot open a sacrifice menu or pause")
	menu._on_sacrifice_pressed()
	check(gm.player_age==20 and stored==FileAccess.get_file_as_bytes(fixture),"A stale sacrifice callback cannot overwrite campaign data from the title")
	var gameplay:=Node2D.new()
	root.add_child(gameplay)
	current_scene=gameplay
	menu.toggle_menu()
	check(menu.control.visible and paused,"An active gameplay scene still opens and pauses the attribute menu")
	menu._on_sacrifice_pressed()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(gm.player_age==21 and saved.player_age==21 and saved.highest_unlocked_level==4,"An in-game sacrifice autosaves age while preserving campaign progression")
	menu.toggle_menu()
	check(not menu.control.visible and not paused,"Closing the attribute menu resumes gameplay")
	var echo:=InputEventKey.new()
	echo.keycode=KEY_TAB
	echo.pressed=true
	echo.echo=true
	menu._input(echo)
	check(not menu.control.visible,"Keyboard repeat cannot reopen the sacrifice menu")
	menu.toggle_menu()
	current_scene=title
	menu._process(0.0)
	check(not menu.control.visible and not paused,"A transition to the title hides attributes and releases their pause")
	paused=false
	gameplay.queue_free()
	title.queue_free()
	await process_frame
	gm.persistence_enabled=false
	gm.save_file_path=gm.SAVE_FILE_PATH
	check(before==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"Real campaign save is untouched by menu guard verification")
	DirAccess.remove_absolute(fixture)
	print("SACRIFICE_MENU_GUARD ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
