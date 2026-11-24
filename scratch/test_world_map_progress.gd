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
	check(map.stops.size()==12 and map.player.current_node==map.destination("troy"),"The map has twelve unique places and starts in Troy")
	check(map.get_node("Chart/BG").texture.resource_path=="res://Assets/world_map/islands_v2.png","The map uses a new painting of all destinations, not the old three-island art")
	check(map.info_label.text.contains("Troia"),"The selected chapter keeps its own playable title")
	var place_ids: Array[String]=[]
	var chapters: Array[String]=[]
	for stop in map.stops:
		check(stop.destination_id not in place_ids,"Each geographic destination has exactly one pin")
		place_ids.append(stop.destination_id)
		for entry in stop.chapters:
			check(entry.id not in chapters and ResourceLoader.exists(entry.scene),"Each original chapter has exactly one existing entry scene")
			chapters.append(entry.id)
	check(chapters.size()==19,"All nineteen prior entries remain playable within destinations")
	check(not map.player.request_travel(map.destination("aeaea")),"A locked destination refuses travel")
	map.player.current_node=map.destination("aeaea")
	check(map.player.entry_path().is_empty() and not map.player.enter_current(),"A locked destination cannot launch through a forced selection")
	map.player.entry_requested.disconnect(map._on_entry_requested)
	var entries: Array[String]=[]
	map.player.entry_requested.connect(func(path: String): entries.append(path))
	gm.highest_unlocked_level=4
	var aeolia: MapNode=map.destination("aeolia")
	for stage in 4:
		gm.act4_unlocked_stage=stage
		gm.act4_progress_changed.emit()
		var available:=0
		for stop in map.stops:
			if stop.is_unlocked(): available+=1
		check(available==(5 if stage==3 else 4),"Act IV chapters reuse Aeolia, with one separate coast for the first Poseidon encounter")
		var current: MapNode=map.destination("giants") if stage==3 else aeolia
		map.player.snap_to(current)
		check(map.player.enter_current() and ResourceLoader.exists(entries.back()),"The island recommends the next unlocked chapter")
	gm.act4_unlocked_stage=0
	map.player.snap_to(aeolia)
	check(map.chapter_buttons.size()==3 and not map.select_chapter("harpoon"),"Aeolia exposes its three chapters with individual locks")
	check(map.select_chapter("storm") and map.player.entry_path().contains("StormCutscene"),"The storm remains separately replayable from Aeolia")
	var key:=InputEventKey.new()
	key.keycode=KEY_D
	key.pressed=true
	map.player._unhandled_input(key)
	check(not map.player.is_moving,"Navigation refuses the still-locked giant coast")
	gm.act4_unlocked_stage=3
	gm.act4_progress_changed.emit()
	map.player._unhandled_input(key)
	check(map.player.is_moving and not map.player.enter_current(),"Travel blocks stage entry while the ship is moving")
	map.size=Vector2(900,700)
	map._fit_chart()
	map.player.travel_tween.custom_step(1.0)
	check(map.player.current_node==map.destination("giants") and map.player.global_position.distance_to(map.destination("giants").global_position)<0.01,"Travel stays attached to the island when resizing")
	gm.complete_act4()
	check(map.progress_label.text.begins_with("5 / 12") and map.destination("aeaea").is_unlocked(),"The first escape clears five destinations and opens Circe's island")
	gm.collect_circe_moly()
	gm.complete_circe_search()
	map.player.snap_to(map.destination("aeaea"))
	check(map.chapter_buttons.size()==2 and map.destination("aeaea").completed_chapters()==1 and not map.destination("aeaea").is_completed(),"One Circe pin contains search and confrontation, with separate progress")
	check(map.player.entry_path().ends_with("CirceBattle.tscn"),"Returning with the flower recommends the battle")
	check(map.select_chapter("moly") and map.player.enter_current() and entries.back().ends_with("CirceForest.tscn"),"The search remains directly replayable after unlocking the battle")
	gm.complete_circe_battle()
	map.player.snap_to(map.destination("underworld"))
	check(not map.select_chapter("prophet") and map.chapter_buttons.size()==2,"The prophet cannot be selected before the crossing")
	gm.complete_underworld_crossing()
	map.player.snap_to(map.destination("underworld"))
	check(map.player.entry_path().ends_with("UnderworldOracle.tscn") and map.select_chapter("souls"),"The same Underworld pin offers the oracle and replay of the crossing")
	gm.record_underworld_vision(gm.UNDERWORLD_VISION_COUNT)
	gm.complete_underworld_prophecy()
	gm.complete_sirens(gm.player_current_hp)
	gm.complete_scylla()
	gm.complete_mutiny(gm.player_current_hp)
	gm.complete_ogygia_paths()
	gm.complete_calypso()
	map.queue_free()
	await process_frame
	map=load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene=map
	await process_frame
	map.player.entry_requested.disconnect(map._on_entry_requested)
	map.player.entry_requested.connect(func(path: String): entries.append(path))
	check(map.stops.size()==12 and map.player.current_node==map.destination("strait"),"After Calypso the next chapter returns to the existing strait instead of adding another pin")
	check(map.player.entry_path().ends_with("Charybdis.tscn") and map.destination("strait").completed_chapters()==1,"The strait now recommends Caribdis while preserving Cila's completion")
	check(map.select_chapter("scylla") and map.player.entry_path().ends_with("ScyllaPassage.tscn"),"Cila remains independently replayable on the same strait")
	gm.complete_charybdis()
	map.player.snap_to(map.destination("ithaca"))
	check(not map.select_chapter("suitors") and map.player.entry_path().ends_with("FinalPoseidon.tscn"),"Ithaca's approach opens Poseidon while the palace remains locked")
	gm.complete_final_poseidon(gm.player_current_hp)
	map.player.snap_to(map.destination("ithaca"))
	check(map.player.entry_path().ends_with("Ithaca.tscn") and map.select_chapter("final_poseidon"),"The Ithaca pin offers the palace and independent replay of Poseidon")
	gm.complete_ithaca(gm.player_current_hp)
	check(map.progress_label.text.begins_with("12 / 12"),"Complete campaign clears twelve destinations without counting chapters as islands")
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
