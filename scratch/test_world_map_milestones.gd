extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
func run() -> void:
	var gm: Node=root.get_node("GameManager")
	var original:=bytes(gm.SAVE_FILE_PATH)
	var old_vigil:=bytes("user://vigil_record.json")
	var old_escape:=bytes("user://poseidon_escape_record.json")
	var folder: String=OS.get_environment("TEMP").path_join("odisseia_milestones_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	gm.save_file_path=folder.path_join("campaign.json")
	gm.reset()
	gm.highest_unlocked_level=4
	var storm: Node=load("res://Ato4_Tempestade/Gameplay/StormLevel.tscn").instantiate()
	root.add_child(storm)
	current_scene=storm
	storm.set_physics_process(false)
	storm.state=storm.State.SAILING
	storm.finish(false)
	check(gm.act4_unlocked_stage==0,"Losing the storm cannot unlock Éolia")
	storm.state=storm.State.SAILING
	storm.finish(true)
	check(gm.act4_unlocked_stage==1,"The actual storm victory unlocks Éolia")
	storm.queue_free()
	await process_frame
	var meeting: Control=load("res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn").instantiate()
	root.add_child(meeting)
	current_scene=meeting
	check(gm.act4_unlocked_stage==1,"Simply opening Éolo's dialogue does not unlock the vigil")
	meeting._finish()
	await create_timer(2.0).timeout
	check(gm.act4_unlocked_stage==2,"Finishing Éolo's dialogue unlocks the nine-day voyage")
	meeting.queue_free()
	await process_frame
	var vigil: Control=load("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn").instantiate()
	vigil.audio_enabled=false
	vigil.continue_to_poseidon=false
	vigil.record_file_path=folder.path_join("vigil_record.json")
	root.add_child(vigil)
	current_scene=vigil
	vigil.set_process(false)
	vigil.set_physics_process(false)
	vigil._failed("sono")
	check(gm.act4_unlocked_stage==2,"An early vigil loss cannot unlock Poseidon")
	vigil.model.day=9
	vigil.model.days_completed=8
	vigil.model.state=vigil.model.State.COMPLETE
	vigil._completed(vigil.model.record())
	check(gm.act4_unlocked_stage==3,"The actual completed vigil narrative unlocks Poseidon")
	vigil.queue_free()
	await process_frame
	var escape: Control=load("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	escape.audio_enabled=false
	escape.manual_score_clock=true
	escape.record_file_path=folder.path_join("poseidon_escape_record.json")
	root.add_child(escape)
	current_scene=escape
	escape.set_physics_process(false)
	check(not gm.act4_completed,"Entering Poseidon's phase does not mark its ending complete")
	var record: Dictionary=escape.model.record()
	record.escaped=true
	record.aftermath_completed=true
	record.survivors=43
	record.ships_lost=11
	record.ships_remaining=1
	escape._completed(record)
	check(gm.act4_completed and gm.act4_unlocked_stage==3,"The gameplay completion after the ending marks all AtoIV chapters complete")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(gm.save_file_path))
	check(data.act4_completed and data.highest_unlocked_level==4,"The final milestone is saved without unlocking a nonexistent act")
	escape.queue_free()
	await process_frame
	await process_frame
	check(original==bytes(gm.SAVE_FILE_PATH) and old_vigil==bytes("user://vigil_record.json") and old_escape==bytes("user://poseidon_escape_record.json"),"Milestone integration leaves real saves and records untouched")
	gm.persistence_enabled=false
	gm.save_file_path=gm.SAVE_FILE_PATH
	for filename in ["campaign.json","vigil_record.json","poseidon_escape_record.json"]: DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("WORLD_MAP_MILESTONES ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
