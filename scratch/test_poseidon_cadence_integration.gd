extends Node
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
const Pilot = preload("res://scratch/PoseidonCadencePilot.gd")
var checks:=0
var failures:=0
var escaped_count:=0
var capture:=false

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()

func advance(scene: Control, dt: float, input: Dictionary) -> void:
	scene.score.advance(dt)
	scene.model.set_score_time(maxf(0,scene.score.absolute_time))
	scene.model.escape_score_age=scene.score.section_elapsed if scene.score.section=="escape" else -1.0
	scene.model.set_combat_input(input.get("attack",false),input.get("guard",false))
	scene.model.tick(dt,input.get("move",0.0),input.get("duck",false),input.get("jump",false),input.get("held",false),input.get("interact",false))
	scene.visuals.update_visuals(dt)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture="--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	get_viewport().size=Vector2i(1152,648)
	var save_before:=bytes(GameManager.SAVE_FILE_PATH)
	var record_before:=bytes("user://poseidon_escape_record.json")
	var health: int=GameManager.player_current_hp
	var inventory: Array=GameManager.inventory.duplicate(true)
	var combat_before: bool=GameManager.combat_mode
	var scene: Control=preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	# Retain the manual-bag rehearsal; test_poseidon_aftermath covers campaign default.
	scene.aftermath_enabled=false
	scene.audio_enabled=false
	scene.persist_record=false
	scene.manual_score_clock=true
	scene.handoff_record={"story_complete":true,"cadence_test":"incoming_record"}
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().process_frame
	scene.set_physics_process(false)
	scene.score.set_process(false)
	scene.visuals.set_process(false)
	check(scene.cadence_enabled and scene.model is Model and not scene.proof_enabled,"Campaign entry selects full musical route")
	check(scene.score.deterministic and not scene.score.enabled and scene.score.voices.size()==2,"Silent deterministic score uses real section metadata and two player nodes")
	scene.ready_delay=0
	scene.escaped.connect(func(_record): escaped_count+=1)
	scene.begin()
	check(scene.model.active() and scene.score.running and not scene.intro.visible,"Beginning starts both score and free gameplay")
	check(not scene.warning_label.visible and not scene.action_label.visible,"Attack warning HUD remains absent")
	for i in 45: advance(scene,1.0/60,{"move":1.0})
	scene.score.request_section("wrecks")
	scene.model._save_checkpoint()
	var snapshot: Dictionary=scene.model.checkpoint.music.duplicate(true)
	var geometry: Array=scene.model.platforms.duplicate(true)
	var checkpoint_position: Vector2=scene.model.position
	var checkpoint_clock: float=scene.model.clock
	check(snapshot.pending=="wrecks" and snapshot.pending_at>snapshot.absolute,"Checkpoint retains a queued musical section")
	for i in 30: advance(scene,1.0/60,{"move":1.0})
	scene.model._fail("Integration failure fixture")
	var failure_clock: float=scene.model.clock
	var failure_score: float=scene.score.absolute_time
	for i in 50: advance(scene,1.0/60,{"move":1.0,"jump":true,"held":true})
	check(scene.failure_panel.visible and scene.score.frozen,"Failure panel freezes the score immediately")
	check(scene.model.clock==failure_clock and scene.score.absolute_time==failure_score,"Failure advances neither world nor score")
	var all_voices_paused:=true
	for voice in scene.score.voices: all_voices_paused=all_voices_paused and (voice.stream_paused or not voice.playing)
	check(all_voices_paused,"Failure leaves both music nodes paused or silent")
	scene.retry_checkpoint()
	check(scene.model.active() and not scene.failure_panel.visible and not scene.score.frozen,"Explicit retry resumes the same score and gameplay")
	check(scene.model.position==checkpoint_position and scene.model.clock==checkpoint_clock and scene.model.platforms==geometry,"Checkpoint restores exact collision geometry and physics time")
	check(scene.score.get_snapshot()==snapshot,"Retry restores clip, absolute time, queued section and playback position exactly")
	# SceneTree pause must affect controller physics, renderer and the score's nodes.
	scene.set_physics_process(true)
	scene.visuals.set_process(true)
	await get_tree().physics_frame
	get_tree().paused=true
	var paused_clock: float=scene.model.clock
	var paused_score: float=scene.score.absolute_time
	var paused_visual: float=scene.visuals.elapsed
	await get_tree().create_timer(0.08,true).timeout
	check(scene.model.clock==paused_clock and scene.score.absolute_time==paused_score and scene.visuals.elapsed==paused_visual,"Pause freezes collision, score and rendered animation clocks")
	var nodes_paused:=true
	for voice in scene.score.voices: nodes_paused=nodes_paused and not voice.can_process()
	check(nodes_paused,"SceneTree pause also suspends both music nodes")
	get_tree().paused=false
	scene.set_physics_process(false)
	scene.visuals.set_process(false)
	# Resume from the initial checkpoint to exercise the real director transitions.
	scene.model._fail("Reset to the initial checkpoint")
	scene.retry_checkpoint()
	scene.score.pending_section=""
	scene.score.pending_at=-1
	scene.model.capture_score(scene.score.get_snapshot())
	var pilot:=Pilot.new()
	var captured: Dictionary={}
	var saw_release:=false
	var saw_boarding:=false
	var saw_god_during_boarding:=false
	if capture: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/poseidon_cadence_preview/"))
	for frame in 60*240:
		var input: Dictionary=pilot.controls(scene.model)
		advance(scene,1.0/60,input)
		if scene.model.boarding.active:
			saw_boarding=true
			for h in scene.model.hazards:
				if int(h.boat)==10: saw_god_during_boarding=true
		if scene.model.wind_released: saw_release=true
		var title:=""
		if scene.model.visited_boat==0 and scene.model.position.x>800: title="01_opening"
		if scene.model.visited_boat==2: title="02_refuge"
		if scene.model.visited_boat==4 and scene.model.position.x>scene.model.boats[4].rect.position.x+300: title="03_wrecks"
		if scene.model.visited_boat==7: title="04_onslaught"
		if scene.model.phase==Model.Phase.FINAL_SHIP and not scene.model.has_bag: title="05_final_ship"
		if scene.model.has_bag: title="06_bag_return"
		if scene.model.phase==Model.Phase.ESCAPING and scene.model.wind_released: title="07_wind_release"
		if scene.model.phase==Model.Phase.COMPLETE: title="08_complete"
		if capture and not title.is_empty() and not captured.has(title):
			captured[title]=true
			scene._update_interface()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://scratch/poseidon_cadence_preview/"+title+".png")
		if scene.model.phase in [Model.Phase.COMPLETE,Model.Phase.FAILED]: break
		if frame%600==0: await get_tree().process_frame
	check(scene.model.phase==Model.Phase.COMPLETE and scene.result.visible,"Full route completes through the real controller result panel")
	check(scene.complete_count==1 and escaped_count==1 and scene.model.completion_count==1,"Full escape emits exactly once")
	check(scene.model.has_bag and saw_boarding and scene.model.boarding.kills==3 and saw_god_during_boarding and saw_release,"Run defeats boarders under divine attacks, retrieves bag and releases instrumental escape")
	check(not scene.model.mast_broken and not scene.model.platforms[scene.model.final_middle].gone and scene.model.sunk_at[10]<0,"Captain hull and mast survive the final fight and the escape")
	check(scene.model.fleet_remaining()==1 and scene.model.record().ships_lost==11,"Only Odysseus's ship survives")
	var sections_seen: Array=[]
	for event in scene.score.transition_log: sections_seen.append(event.section)
	check(sections_seen.has("surge") and sections_seen.has("wrecks") and sections_seen.has("onslaught") and sections_seen.has("bag") and sections_seen.has("escape"),"Director traverses all authored musical sections")
	check(not scene.score.running and absf(scene.score.section_elapsed-scene.score.sections.escape.duration)<0.001,"Results wait until actual escape musical cue finishes")
	check(save_before==bytes(GameManager.SAVE_FILE_PATH) and record_before==bytes("user://poseidon_escape_record.json") and health==GameManager.player_current_hp and inventory==GameManager.inventory,"Preview preserves health, inventory and persistent campaign records")
	check(scene.handoff_record.cadence_test=="incoming_record","Incoming cinematic record preserved")
	if capture: check(captured.size()==8,"Visual samples include all musical sequences and the final return")
	print("CADENCE_INTEGRATION_RECORD ",JSON.stringify(scene.model.record()))
	print("CADENCE_MUSICAL_TRANSITIONS ",JSON.stringify(scene.score.transition_log))
	scene.stop_audio()
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.combat_mode==combat_before,"Final scene owner restores prior combat mode")
	print("CADENCE_INTEGRATION ",checks," CHECKS ",failures," FAILURES")
	get_tree().quit(0 if failures==0 else 1)
