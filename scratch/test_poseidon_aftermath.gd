extends Node
## Full input-only crossing, real boarding victory and the authored final dialogue.
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
const Pilot = preload("res://scratch/PoseidonCadencePilot.gd")
var checks:=0
var failures:=0
var escaped_count:=0
var aftermath_count:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func drive(scene: Control, dt: float, input: Dictionary) -> void:
	scene.score.advance(dt)
	scene.model.set_score_time(maxf(0,scene.score.absolute_time))
	scene.model.escape_score_age=scene.score.section_elapsed if scene.score.section=="escape" else -1.0
	scene.model.set_combat_input(input.get("attack",false),input.get("guard",false))
	scene.model.tick(dt,input.get("move",0.0),input.get("duck",false),input.get("jump",false),input.get("held",false),input.get("interact",false))
	scene.visuals.update_visuals(dt)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	GameManager.persistence_enabled=false
	await get_tree().process_frame
	get_viewport().size=Vector2i(1152,648)
	var save_before:=bytes(GameManager.SAVE_FILE_PATH)
	var record_before:=bytes("user://poseidon_escape_record.json")
	var health_before: int=GameManager.player_current_hp
	var inventory_before: Array=GameManager.inventory.duplicate(true)
	var combat_before: bool=GameManager.combat_mode
	var scene: Control=preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.audio_enabled=false
	scene.persist_record=false
	scene.manual_score_clock=true
	scene.handoff_record={"after_fight_test":"preserved","seconds":9999.0}
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().process_frame
	scene.set_physics_process(false)
	scene.score.set_process(false)
	scene.visuals.set_process(false)
	scene.ready_delay=0
	scene.escaped.connect(func(_record): escaped_count+=1)
	scene.begin()
	check(scene.aftermath_enabled and scene.model.cinematic_after_boarding,"Campaign enables the new post-boarding cinematic by default")
	var pilot:=Pilot.new()
	var saw_boarding:=false
	for frame in 60*230:
		if scene.model.phase in [Model.Phase.CINEMATIC,Model.Phase.COMPLETE,Model.Phase.FAILED]: break
		var input: Dictionary=pilot.controls(scene.model)
		drive(scene,1.0/60,input)
		if scene.model.boarding.active: saw_boarding=true
		if frame%600==0: await get_tree().process_frame
	check(saw_boarding and scene.model.boarding.kills==3 and scene.model.boarding.cleared,"Actual sword and movement inputs defeat all water soldiers after crossing the fleet")
	check(scene.model.phase==Model.Phase.CINEMATIC and not scene.model.active(),"Victory leaves combat and freezes gameplay in the cinematic phase")
	check(not scene.model.record().escaped and not scene.model.has_bag and escaped_count==0 and scene.complete_count==0,"Boarding victory alone does not claim escape or recover the bag")
	var fight_seconds: float=scene.model.record().seconds
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(scene.aftermath_scene),"The real gameplay controller mounts the aftermath scene automatically")
	if not is_instance_valid(scene.aftermath_scene):
		print("AFTERMATH_CHECKS ",checks," FAILURES ",failures)
		get_tree().quit(1)
		return
	var aftermath: Control=scene.aftermath_scene
	check(aftermath.handoff_record.after_fight_test=="preserved" and aftermath.handoff_record.seconds==fight_seconds,"Cutscene input preserves narrative metadata and the real gameplay duration")
	check(not scene.stage.visible and not scene.allow_input and not scene.result.visible,"Cinematic handoff removes gameplay HUD and controls until the final line")
	check(not scene.score.running,"Gameplay score does not continue under the aftermath's owned audio")
	check(bytes("user://poseidon_escape_record.json")==record_before,"No escape record is written at the combat-to-cinematic handoff")
	aftermath.aftermath_finished.connect(func(_record): aftermath_count+=1)
	for frame in 90:
		if aftermath.can_advance: break
		await get_tree().create_timer(0.02).timeout
	aftermath.set_process(false)
	var shots: Array=[]
	var lines: Array=[]
	for beat in aftermath.beats:
		shots.append(str(beat.shot))
		if not str(beat.text).is_empty(): lines.append(str(beat.speaker)+":"+str(beat.text))
	check(shots==["scan","wrecks","question","forty_three","reaction","last_words","bag_reveal","bag_open","surprise","escape","look_back","remember"],"Authored shots show destroyed fleet, confrontation, bag opening, escape and the distant final threat in order")
	check(lines.size()==5 and lines[0].begins_with("Odisseu:") and lines[0].contains("meus homens"),"Odisseu asks what happened to his men before Poseidon answers")
	check(lines.has("Poseidon:Sobraram quarenta e três sob seu comando.") and lines.has("Poseidon:Últimas palavras?") and lines.has("Poseidon:O que?") and lines.has("Poseidon:Lembre de mim."),"Poseidon's four requested lines are assigned exactly and in the requested language")
	check(not lines.any(func(line): return line.begins_with("Odisseu:") and not line.contains("meus homens")),"The adaptation does not add sung reply lyrics to Odisseu")
	aftermath.manual_score_clock=false
	aftermath.set_process(true)
	get_tree().paused=true
	var paused_clock: float=aftermath.shot_clock
	var paused_age: float=aftermath.director.age
	await get_tree().create_timer(0.08,true).timeout
	check(aftermath.shot_clock==paused_clock and aftermath.director.age==paused_age,"Pause freezes both narrative and stage action clocks")
	get_tree().paused=false
	aftermath.manual_score_clock=true
	aftermath.set_process(false)
	var seen: Array=[]
	var reached_last_line:=false
	var checked_last_line:=false
	var checked_action_gate:=false
	for frame in 60*90:
		if not is_instance_valid(aftermath) or scene.complete_count>0: break
		var shot: String=str(aftermath.beats[aftermath.current_beat].shot)
		if not shot in seen: seen.append(shot)
		if shot=="bag_open" and not checked_action_gate:
			checked_action_gate=true
			for press in 6:
				aftermath.input_cooldown=0
				aftermath._advance_requested()
			check(aftermath.current_beat==7,"Repeated advance input cannot skip the authored bag-opening action")
		if shot=="remember":
			reached_last_line=true
			if not checked_last_line:
				checked_last_line=true
				check(escaped_count==0,"Distant 'Lembre de mim' is shown before gameplay completion is emitted")
		aftermath.advance(1.0/60)
		if frame%120==0: await get_tree().process_frame
	for frame in 100:
		if scene.complete_count>0: break
		await get_tree().create_timer(0.02).timeout
	check(reached_last_line and seen==shots,"Autoplay visits every requested shot without jumping from victory directly to results")
	check(scene.model.phase==Model.Phase.COMPLETE and scene.result.visible,"Results appear only after the complete aftermath scene")
	check(escaped_count==1 and aftermath_count==1 and scene.complete_count==1 and scene.model.completion_count==1,"Aftermath and gameplay complete exactly once")
	check(scene.model.has_bag and scene.model.wind_released and scene.model.fleet_remaining()==1,"Cinematic recovery opens the bag and leaves one escaping vessel")
	check(scene.model.record().captain_ship_intact and scene.model.record().water_soldiers_defeated==3,"Final result preserves the surviving captain ship and the completed battle")
	check(scene.model.record().get("survivors",0)==43,"The post-fleet record retains forty-three survivors")
	check(scene.handoff_record.after_fight_test=="preserved","The incoming narrative handoff record remains intact")
	check(scene.aftermath_record.seconds==fight_seconds and scene.model.record().seconds==fight_seconds,"Cutscene output does not overwrite gameplay seconds with its own duration")
	check(save_before==bytes(GameManager.SAVE_FILE_PATH) and record_before==bytes("user://poseidon_escape_record.json") and health_before==GameManager.player_current_hp and inventory_before==GameManager.inventory,"Testing cutscene completion preserves campaign save, records, health and inventory")
	scene.stop_audio()
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.combat_mode==combat_before,"Scene cleanup restores the prior combat ownership")
	print("AFTERMATH_SHOTS ",JSON.stringify(seen))
	print("AFTERMATH_CHECKS ",checks," FAILURES ",failures)
	get_tree().quit(0 if failures==0 else 1)
