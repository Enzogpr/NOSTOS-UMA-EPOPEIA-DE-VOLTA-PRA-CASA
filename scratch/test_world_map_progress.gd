extends SceneTree
const Manager:=preload("res://Code/GameManager.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func write(path: String, data: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	var gm: Node=root.get_node("GameManager")
	gm.persistence_enabled=false
	var original: PackedByteArray=FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var folder: String=OS.get_environment("TEMP").path_join("odisseia_map_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var save: String=folder.path_join("campaign.json")
	var manager:=Manager.new()
	manager.save_file_path=save
	manager.player_age=35
	manager.player_damage=9
	manager.inventory=[{"id":"kept"}]
	manager.highest_unlocked_level=4
	manager.unlock_act4_stage(1)
	check(manager.act4_unlocked_stage==1 and manager.highest_unlocked_level==4,"Éolia unlock preserves the four-act numbering")
	var resumed:=Manager.new()
	resumed.save_file_path=save
	check(resumed.load_game() and resumed.act4_unlocked_stage==1 and resumed.player_age==35 and resumed.player_damage==9 and resumed.inventory[0].id=="kept","Saved chapter resumes without changing sacrifices or inventory")
	resumed.unlock_act4_stage(0)
	check(resumed.act4_unlocked_stage==1,"Replaying an earlier chapter cannot relock progress")
	resumed.unlock_act4_stage(99)
	check(resumed.act4_unlocked_stage==3 and resumed.highest_unlocked_level==4 and not resumed.act4_completed,"Chapter limits do not create an unimplemented act5 or complete Poseidon early")
	resumed.complete_act4()
	check(resumed.act4_completed and resumed.act4_unlocked_stage==3,"Only explicit completion marks the final chapter done")
	resumed.reset_encounter()
	check(resumed.act4_completed and resumed.act4_unlocked_stage==3,"Encounter reset preserves completed chapters")
	resumed.reset()
	check(resumed.act4_unlocked_stage==0 and not resumed.act4_completed and resumed.highest_unlocked_level==1,"New campaign clears chapter progress")
	write(save,{"highest_unlocked_level":4,"player_age":35,"player_damage":9})
	write(folder.path_join("vigil_record.json"),{"last_run":{"story_complete":true}})
	var legacy_bytes:=FileAccess.get_file_as_bytes(save)
	check(resumed.load_game() and resumed.act4_unlocked_stage==3 and not resumed.act4_completed,"Legacy completed vigil unlocks Poseidon for replay")
	check(FileAccess.get_file_as_bytes(save)==legacy_bytes,"Migration reads old progress without rewriting the save on load")
	write(folder.path_join("poseidon_escape_record.json"),{"escaped":true,"aftermath_completed":true})
	check(resumed.load_game() and resumed.act4_completed,"Legacy completed ending restores all four AtoIV milestones")
	write(save,{"highest_unlocked_level":1})
	check(resumed.load_game() and resumed.act4_unlocked_stage==0 and not resumed.act4_completed,"New campaign never inherits records from a previous campaign")
	manager.free()
	resumed.free()
	gm.reset()
	root.size=Vector2i(1152,648)
	var map: Control=load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene=map
	await process_frame
	check(map.stops.size()==7 and map.player.current_node==map.stops[0],"Map contains seven stops and begins at the latest unlocked destination")
	check(map.info_label.text.contains("Troia"),"Unlocked current act has a real title rather than an anonymous station")
	check(not map.player.request_travel(map.stops[6]),"Click travel cannot bypass a locked Poseidon chapter")
	map.player.current_node=map.stops[6]
	check(map.player.entry_path().is_empty() and not map.player.enter_current(),"Entry also refuses a locked destination even if selected programmatically")
	map.player.entry_requested.disconnect(map._on_entry_requested)
	var entries: Array[String]=[]
	map.player.entry_requested.connect(func(path: String): entries.append(path))
	gm.highest_unlocked_level=4
	for stage in 4:
		gm.act4_unlocked_stage=stage
		gm.act4_progress_changed.emit()
		var available:=0
		for stop in map.stops:
			if stop.is_unlocked(): available+=1
		check(available==4+stage,"Each chapter unlock exposes exactly the next implemented stop")
		map.player.snap_to(map.stops[3+stage])
		check(map.player.enter_current() and ResourceLoader.exists(entries.back()),"Every unlocked stop launches an existing campaign scene")
	gm.act4_unlocked_stage=0
	map.player.snap_to(map.stops[3])
	var key:=InputEventKey.new()
	key.keycode=KEY_D
	key.pressed=true
	map.player._unhandled_input(key)
	check(not map.player.is_moving,"Keyboard navigation respects chapter locks")
	gm.act4_unlocked_stage=1
	gm.act4_progress_changed.emit()
	map.player._unhandled_input(key)
	check(map.player.is_moving and not map.player.enter_current(),"Keyboard starts travel and blocks entry mid-movement")
	map.player.travel_tween.custom_step(1.0)
	check(map.player.current_node==map.stops[4] and map.info_label.text.contains("Éolia"),"Arrival updates selection and contextual information")
	gm.act4_unlocked_stage=3
	gm.act4_progress_changed.emit()
	map.player.request_travel(map.stops[5])
	map.size=Vector2(900,700)
	map._fit_chart()
	map.player.travel_tween.custom_step(1.0)
	check(map.player.global_position.distance_to(map.stops[5].global_position)<0.01,"Resizing during travel keeps the avatar attached to its destination")
	gm.complete_act4()
	check(map.progress_label.text.begins_with("7 / 7") and map.stops[6].is_completed(),"Final completion lights the last route segment and all seven finished stops")
	map.player.snap_to(map.stops[6])
	check(map.enter_button.text.contains("REJOGAR"),"Completed Poseidon remains replayable")
	for stop in map.stops:
		check(stop.real_name.length()>0 and not stop.level_scene.is_empty(),"All route markers retain a named destination")
	if "--capture" in OS.get_cmdline_user_args():
		map.size=Vector2(1152,648)
		map._fit_chart()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("odisseia_map_updated.png"))
	map.queue_free()
	await process_frame
	await process_frame
	check(original==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"Verification preserves the real campaign save")
	for filename in ["campaign.json","vigil_record.json","poseidon_escape_record.json"]: DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("WORLD_MAP_PROGRESS ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
