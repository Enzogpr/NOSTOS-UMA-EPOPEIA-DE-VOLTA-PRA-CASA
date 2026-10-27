extends Node
var checks:=0
var failures:=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	var combat_before: bool=GameManager.combat_mode
	var scene: Control=preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	scene.audio_enabled=false
	scene.autoplay=false
	scene.handoff_record={"source":"cadence_handoff_fixture"}
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().process_frame
	scene.set_process(false)
	scene._show_beat(scene.beats.size()-1)
	var music_volume: float=AudioManager.music_player.volume_db
	scene.audio_enabled=true
	scene._start_escape_score()
	check(AudioManager.music_player.volume_db==music_volume,"Creating a local score must not change the campaign music volume")
	scene.audio_enabled=false
	scene.escape_score.stop_audio()
	scene.escape_score.setup(false,true)
	scene.escape_score.transition_log.clear()
	scene.escape_score.start_entry()
	scene.escape_score.set_process(false)
	scene.escape_score.advance(0.7)
	var same_score: Node=scene.escape_score
	var score_id:=same_score.get_instance_id()
	var snapshot: Dictionary=same_score.get_snapshot().duplicate(true)
	scene._continue_to_escape()
	await get_tree().process_frame
	var next: Control=get_tree().current_scene
	next.set_physics_process(false)
	next.visuals.set_process(false)
	next.persist_record=false
	print("HANDOFF_SCORE before=",snapshot," after=",next.score.get_snapshot()," log=",next.score.transition_log)
	check(next.name=="PoseidonEscape" and next.cadence_enabled,"Morra handoff selects the musical platform scene")
	check(next.score.get_instance_id()==score_id and next.score.get_parent()==get_tree().root,"The actual score node is transferred, not recreated")
	check(next.score.section==snapshot.section and next.score.absolute_time==snapshot.absolute,"Clip playback position survives handoff without restarting")
	check(next.score.transition_log.size()==1 and next.score.section=="intro","Handoff does not start a second surge track")
	check(next.model.active() and not next.intro.visible,"The cinematic handoff enables controls automatically")
	check(next.handoff_record.source=="cadence_handoff_fixture","Narrative handoff data survives the music transition")
	next.stop_audio()
	next.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.combat_mode=combat_before
	print("CADENCE_HANDOFF ",checks," CHECKS ",failures," FAILURES")
	get_tree().quit(0 if failures==0 else 1)
