extends SceneTree
const CROSSING := preload("res://Ato6_Submundo/Gameplay/UnderworldCrossingModel.gd")
const ORACLE := preload("res://Ato6_Submundo/Gameplay/UnderworldOracleModel.gd")
const MANAGER := preload("res://Code/GameManager.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func advance(m: RefCounted,seconds: float) -> void:
	for _i in ceili(seconds*120): m.tick(1.0/120)
func walk(m: RefCounted,target: Vector2,limit: float=15) -> float:
	var elapsed := 0.0
	while m.position.distance_to(target)>3 and elapsed<limit and m.phase==m.Phase.ACTIVE:
		var difference: Vector2=target-m.position
		m.set_input(difference.normalized()*minf(1,difference.length()/15)); m.tick(1.0/120); elapsed+=1.0/120
	m.set_input(Vector2.ZERO); advance(m,0.12)
	return elapsed+0.12

func run_course(model: CROSSING, use_slide := true) -> float:
	var elapsed := 0.0
	while elapsed < 85.0 and model.phase in [model.Phase.ACTIVE, model.Phase.REST]:
		if model.phase == model.Phase.REST:
			model.leave_rest()
		if model.next_obstacle < CROSSING.COURSE.size():
			var row: Array = CROSSING.COURSE[model.next_obstacle]
			var gap := float(row[0]) - model.distance
			var mask := int(row[1])
			if gap < 22.0:
				if mask == 7:
					match row[2]:
						CROSSING.Obstacle.DEBRIS:
							if gap <= model.forward_speed() * 0.34: model.request_jump()
						CROSSING.Obstacle.LINTEL:
							if use_slide and gap <= model.forward_speed() * 0.24: model.request_slide()
				elif (mask & (1 << (model.target_lane + 1))) != 0:
					for option in [0, -1, 1]:
						if (mask & (1 << (option + 1))) == 0:
							model.change_lane(signi(option - model.target_lane))
							break
		model.tick(1.0 / 120.0)
		elapsed += 1.0 / 120.0
	return elapsed

func wait_for_bridge(model: ORACLE, bridge: int) -> void:
	for _frame in ceili((model.echo_interval * 2.0 + 1.0) * 120):
		if model.bridge_open(bridge): return
		model.tick(1.0 / 120.0)

func cross_bridge(model: ORACLE, index: int, waiting: Vector2, across: Vector2) -> void:
	var role := model.pad_actors[index]
	var pad := model.pads[index]
	walk(model, pad)
	var travel := pad.distance_to(waiting) / (model.SPEED * model.speed_mult)
	advance(model, maxf(0.4, model.echo_interval * role - travel - 0.42))
	walk(model, waiting)
	wait_for_bridge(model, index)
	walk(model, across)

func confirm_vision(model: ORACLE, index: int) -> bool:
	var solved := model.puzzle == index and model.phase == model.Phase.MEMORY
	check(solved, "Proof %d resolves at speed %.2f (at %s, bridge/seal state %s)" % [index, model.speed_mult, model.position, model.activated])
	if solved: model.finish_dialogue("vision_%d" % index)
	return solved

func solve_oracle(m: ORACLE) -> void:
	walk(m, m.pads[0]); advance(m, m.echo_interval + 0.65)
	walk(m, m.pads[1]); advance(m, 0.65)
	if not confirm_vision(m, 1): return

	cross_bridge(m, 0, Vector2(505, 415), Vector2(845, 415))
	if not confirm_vision(m, 2): return

	cross_bridge(m, 0, Vector2(365, 415), Vector2(560, 415))
	cross_bridge(m, 1, Vector2(727, 415), Vector2(959, 415))
	if not confirm_vision(m, 3): return

	walk(m, Vector2(360, 385)); advance(m, m.echo_interval + 0.7)
	walk(m, m.pads[1]); advance(m, 0.65)
	if not confirm_vision(m, 4): return

	var walking_speed := m.SPEED * m.speed_mult
	walk(m, m.pads[0])
	advance(m, m.echo_interval - m.pads[0].distance_to(m.pads[1]) / walking_speed + 0.6)
	walk(m, m.pads[1]); advance(m, 0.55)
	walk(m, m.pads[2]); advance(m, m.echo_interval)
	if not confirm_vision(m, 5): return

	walk(m, m.pads[0])
	var first_echo_arrival := m.recording_clock + m.echo_interval * 2.0
	advance(m, m.echo_interval - m.pads[0].distance_to(m.pads[1]) / walking_speed + 0.6)
	walk(m, m.pads[1])
	var entrance := Vector2(455, 418)
	var approach_time := m.pads[1].distance_to(entrance) / walking_speed
	advance(m, maxf(0.5, first_echo_arrival - m.recording_clock - approach_time - 0.45))
	walk(m, entrance)
	wait_for_bridge(m, 0)
	walk(m, Vector2(930, 418))
	if not confirm_vision(m, 6): return
	check(m.phase == m.Phase.ACTIVE and m.bridge_open(0) and m.bridge_open(1), "The last vision leaves a permanent way to Tiresias")
	walk(m, m.prophet)
	m.request_interact()
	check(m.phase == m.Phase.MEMORY, "The final prophecy requires approaching Tiresias himself")
	m.finish_dialogue("prophet")
	check(m.phase == m.Phase.COMPLETE, "Prophecy completes only after hearing the final conversation")

func run() -> void:
	var gm: Node=root.get_node("GameManager"); gm.persistence_enabled=false
	var save_before := FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var crossing := CROSSING.new()
	crossing.begin()
	advance(crossing, 1.8)
	check(crossing.distance > 42.0 and crossing.pressure > 50.0 and crossing.stumble_time > 0.0,
		"Running into a stone slows Odisseu and brings the souls closer")
	var before_dash := crossing.pressure
	crossing.request_dash()
	check(crossing.pressure < before_dash and crossing.dash_recharge > 0.0, "Dash creates room and uses its cooldown")
	advance(crossing, 30)
	check(crossing.phase == crossing.Phase.FAILED and crossing.distance < CROSSING.FINISH,
		"The souls can catch a runner who never avoids obstacles")
	crossing.resume(1, false)
	crossing.retry()
	check(crossing.distance == CROSSING.CHECKPOINTS[1] and crossing.pressure < 40.0 and crossing.target_lane == 0,
		"Retry restarts at the saved lantern without inherited stumble")
	crossing.resume(2, false)
	crossing.phase = crossing.Phase.READY
	crossing.begin()
	crossing.request_interact()
	var frozen := crossing.distance
	advance(crossing, 5)
	check(crossing.phase == crossing.Phase.MEMORY and crossing.distance == frozen, "Anticleia suspends the pursuit")
	crossing.finish_dialogue("mother")
	check(crossing.heard_mother and crossing.phase == crossing.Phase.REST, "The encounter stays optional and persists when read")
	crossing.leave_rest()
	check(crossing.phase == crossing.Phase.ACTIVE, "Continue resumes the chase from the second lantern")

	var illusion := CROSSING.new()
	illusion.begin()
	illusion.change_lane(-1)
	advance(illusion, 2.0)
	illusion.change_lane(1)
	advance(illusion, 1.9)
	var before_stretch := illusion.apparent_gap(200.0 - illusion.distance)
	var distance_before := illusion.distance
	advance(illusion, 1.18)
	check(illusion.distance > distance_before and illusion.apparent_gap(200.0 - illusion.distance) > before_stretch + 5.0,
		"The echo of the arch recedes while actual distance advances")
	check(is_equal_approx(illusion.apparent_gap(5.0), 5.0), "Distortion leaves collision distance readable")
	var ramp := CROSSING.new()
	var opening_speed := ramp.forward_speed()
	ramp.distance = CROSSING.CHECKPOINTS[2]
	var middle_speed := ramp.forward_speed()
	ramp.distance = CROSSING.FINISH - 10.0
	check(opening_speed < middle_speed and middle_speed < ramp.forward_speed() and ramp.forward_speed() > opening_speed * 1.7,
		"The floor accelerates with distance, including through the final chase")
	var beam := CROSSING.new()
	beam.begin()
	var low_beam := [257.0, 7, CROSSING.Obstacle.LINTEL]
	check(beam._hits(low_beam), "The first full-width beam blocks all standing runners")
	beam.request_jump(); advance(beam, 0.34)
	check(beam._hits(low_beam), "Jumping cannot clear a low beam")
	beam.request_slide()
	check(beam.slide_time == 0.0 and beam.queued_move == CROSSING.Move.NONE, "A slide cannot start in midair")
	advance(beam, 0.37)
	beam.request_slide(); advance(beam, 0.10)
	check(beam.slide_time > 0.0 and not beam._hits(low_beam), "A slide pressed just before landing clears the beam after touching down")
	check(beam._hits([beam.distance, 7, CROSSING.Obstacle.DEBRIS]), "A slide cannot clear low rocks")
	advance(beam, CROSSING.SLIDE_DURATION)
	check(beam._hits(low_beam), "An early slide wears off before reaching the beam")
	beam.request_slide(); beam.retry()
	check(beam.slide_time == 0.0 and beam.queued_move == CROSSING.Move.NONE, "Retry clears slide and buffered inputs")
	var no_slide := CROSSING.new()
	no_slide.begin(); run_course(no_slide, false)
	check(no_slide.phase == no_slide.Phase.FAILED, "Dodging and jumping alone cannot finish the revised course")

	for speed in [0.3, 1.0, 1.72, 2.0]:
		var route := CROSSING.new()
		route.apply_player_stats({"speed_mult": speed})
		var collisions: Array[float] = []
		var record_hit := func(kind: String) -> void:
			if kind == "hit": collisions.append(route.distance)
		route.cue.connect(record_hit)
		route.begin()
		var seconds := run_course(route)
		route.cue.disconnect(record_hit)
		check(route.phase == route.Phase.COMPLETE and route.checkpoint == 2 and collisions.is_empty(),
			"All obstacles can be avoided at speed %.2f (%.1f s, at %.1f, hits %s)" % [speed, seconds, route.distance, collisions])
	var oracle := ORACLE.new(); oracle.begin()
	check(not oracle.walkable(Vector2(680,340)) and not oracle.walkable(Vector2(900,292)),"Oracle islands remain inaccessible until their proofs are solved")
	advance(oracle,1)
	check(oracle.echoes.is_empty(),"An echo cannot appear before its recording exists")
	advance(oracle,2)
	check(oracle.echoes.size()==1 and oracle.echoes[0].p.distance_to(oracle.position)<1,"Echo samples the actual earlier position")
	oracle.set_input(Vector2.RIGHT); advance(oracle,0.5)
	check(oracle.echoes[0].p.distance_to(oracle.position)>50,"Echo does not track or teleport with the current player")
	oracle.retry(); solve_oracle(oracle)
	var falling_bridge := ORACLE.new(); falling_bridge.resume(1); falling_bridge.begin()
	falling_bridge.activated[0] = true
	falling_bridge.position = Vector2(600, 415)
	falling_bridge.last_stable = Vector2(493, 415)
	falling_bridge.tick(0.01)
	check(falling_bridge.position == falling_bridge.last_stable and not falling_bridge.bridge_open(0) and falling_bridge.puzzle == 1,
		"A disappearing bridge returns Odisseu to solid ground without losing a solved proof")
	var older := ORACLE.new(); older.apply_player_stats({"speed_mult":0.3,"intellect":25,"dash_cooldown":4.5}); older.begin()
	check(older.echo_interval>4.5,"Slow sacrifice builds receive enough echo interval to solve the same distances")
	solve_oracle(older)
	var faster := ORACLE.new(); faster.apply_player_stats({"speed_mult": 1.72}); faster.begin()
	solve_oracle(faster)
	var reapply := ORACLE.new(); reapply.begin(); advance(reapply,4); reapply.apply_player_stats({"speed_mult":0.8})
	check(reapply.echoes.is_empty() and reapply.history.is_empty(),"Changing sacrifices safely discards a recording made at the previous speed")
	var manager := MANAGER.new(); manager.persistence_enabled=false
	manager.complete_underworld_crossing(); manager.complete_underworld_prophecy()
	check(not manager.underworld_crossing_completed and not manager.underworld_prophecy_completed,"Progress cannot bypass Circe or the temporal trials")
	manager.circe_moly_found=true; manager.circe_search_completed=true; manager.complete_circe_battle()
	manager.record_underworld_checkpoint(2); manager.record_underworld_checkpoint(0); manager.record_underworld_mother(); manager.complete_underworld_crossing()
	manager.record_underworld_vision(1); manager.complete_underworld_prophecy()
	check(manager.underworld_checkpoint==2 and manager.underworld_mother_heard and not manager.underworld_prophecy_completed,"Checkpoints are monotonic and incomplete visions never finish the act")
	manager.record_underworld_vision(6); manager.complete_underworld_prophecy()
	check(manager.underworld_prophecy_completed and manager.highest_unlocked_level==7,"Completing Tiresias unlocks the seventh act without marking it done")
	var temporary := OS.get_environment("TEMP").path_join("nostos_underworld_%d.json" % Time.get_ticks_usec())
	manager.save_file_path=temporary; manager.persistence_enabled=true; manager.player_current_hp=2; manager.player_damage=9; manager.player_age=38; manager.save_game()
	var restored := MANAGER.new(); restored.save_file_path=temporary
	check(restored.load_game() and restored.underworld_prophecy_completed and restored.underworld_vision_index==6 and restored.player_current_hp==2 and restored.player_damage==9 and restored.player_age==38,"Saving spiritual progress retains wounds, damage, age and every Underworld milestone")
	var completed_legacy := FileAccess.open(temporary, FileAccess.WRITE)
	completed_legacy.store_string(JSON.stringify({"circe_moly_found":true, "circe_search_completed":true, "circe_battle_completed":true, "underworld_crossing_completed":true, "underworld_vision_index":3, "underworld_prophecy_completed":true, "sirens_completed":true}))
	completed_legacy.close()
	check(restored.load_game() and restored.underworld_prophecy_completed and restored.underworld_vision_index==6 and restored.sirens_completed,"A previously finished three-vision campaign retains its later progress")
	var legacy := FileAccess.open(temporary,FileAccess.WRITE); legacy.store_string(JSON.stringify({"highest_unlocked_level":5,"circe_moly_found":true,"circe_search_completed":true,"circe_battle_completed":true,"player_current_hp":2})); legacy.close()
	check(restored.load_game() and not restored.underworld_prophecy_completed and not restored.underworld_crossing_completed and restored.underworld_checkpoint==0 and restored.underworld_vision_index==0 and restored.player_current_hp==2,"Loading an old save clears stale new milestones and preserves legitimate previous progress")
	restored.reset()
	check(not restored.underworld_crossing_completed and not restored.underworld_mother_heard and restored.underworld_vision_index==0 and restored.underworld_checkpoint==0,"New game clears every Underworld milestone")
	manager.free(); restored.free(); DirAccess.remove_absolute(temporary)
	gm.reset(); gm.player_current_hp=3; gm.player_damage=8; gm.player_age=37; gm.player_speed_mult=0.65; gm.player_intellect=15
	root.size=Vector2i(1152,648)
	var journey: Control=load("res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn").instantiate(); journey.audio_enabled=false
	root.add_child(journey); current_scene=journey; await process_frame
	journey.begin(); check(journey.model.phase==journey.model.Phase.READY,"Real controller refuses direct entry without the campaign prerequisite")
	journey.queue_free(); await process_frame
	gm.circe_moly_found=true; gm.circe_search_completed=true; gm.complete_circe_battle()
	journey=load("res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn").instantiate(); journey.audio_enabled=false
	root.add_child(journey); current_scene=journey; await process_frame; journey.begin()
	check(journey.model.speed_mult==0.65 and journey.model.intellect==15 and gm.player_current_hp==3,"Scene captures existing sacrifices without healing the living hero")
	var key := InputEventKey.new(); key.physical_keycode=KEY_RIGHT; key.pressed=true; Input.parse_input_event(key); Input.flush_buffered_events()
	for _frame in 14: await physics_frame
	var release := InputEventKey.new(); release.physical_keycode=KEY_RIGHT; release.pressed=false; Input.parse_input_event(release); Input.flush_buffered_events()
	check(journey.model.target_lane == 1 and journey.model.lane > 0.75, "Physical arrow changes the runner lane")
	var jump := InputEventKey.new(); jump.physical_keycode=KEY_SPACE; jump.pressed=true; Input.parse_input_event(jump); Input.flush_buffered_events()
	for _frame in 8: await physics_frame
	var release_jump := InputEventKey.new(); release_jump.physical_keycode=KEY_SPACE; release_jump.pressed=false; Input.parse_input_event(release_jump); Input.flush_buffered_events()
	check(journey.model.jump_height() > 0.25, "Physical Space jumps in the live scene")
	journey.model.jump_elapsed = CROSSING.JUMP_DURATION
	var slide := InputEventKey.new(); slide.physical_keycode=KEY_DOWN; slide.pressed=true; Input.parse_input_event(slide); Input.flush_buffered_events()
	await physics_frame
	var release_slide := InputEventKey.new(); release_slide.physical_keycode=KEY_DOWN; release_slide.pressed=false; Input.parse_input_event(release_slide); Input.flush_buffered_events()
	check(journey.model.slide_time > 0.4, "Physical Down slides in the live scene")
	var pause_clock: float=journey.model.clock; paused=true
	for _frame in 4: await process_frame
	check(journey.model.clock==pause_clock,"Global pause stops the actual gameplay simulation")
	paused=false
	var factor_before: Vector2=journey.stage.scale; journey.size=Vector2(900,700); journey._fit()
	check(journey.stage.scale.x<factor_before.x and journey.stage.position.y>0,"Narrow windows preserve the complete logical playfield and UI")
	journey.size=Vector2(1152,648); journey._fit()
	journey.model.distance = CROSSING.CHECKPOINTS[2] - 0.1
	journey.model.checkpoint = 1
	journey.model.next_obstacle = 19
	journey.model.tick(0.01)
	check(gm.underworld_checkpoint == 2 and journey.resting_place.visible, "The second lantern saves and opens Anticleia's clearing")
	journey.model.request_interact()
	check(journey.dialogue.visible and journey.speaker.text=="ODISSEU" and journey.sentence.text=="Mãe...?","Anticleia's original dialogue stays available in text")
	journey.restart_checkpoint(); check(journey.dialogue.visible,"Retry cannot skip an active memory")
	while journey.dialogue.visible: journey.advance_dialogue()
	check(gm.underworld_mother_heard and journey.resting_place.visible,"Reading the last line persists the encounter and returns to the clearing")
	journey._leave_rest()
	journey.model.distance = CROSSING.FINISH - 0.1
	journey.model.next_obstacle = CROSSING.COURSE.size()
	journey.model.tick(0.01)
	check(journey.result.visible and gm.underworld_crossing_completed,"Reaching the real arch unlocks the prophet through the live controller")
	journey.queue_free(); await process_frame
	var prophecy: Control=load("res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn").instantiate(); prophecy.audio_enabled=false
	root.add_child(prophecy); current_scene=prophecy; await process_frame; prophecy.begin(); prophecy.set_physics_process(false)
	var phrases := [
		"Eu vejo uma canção de um romance passado",
		"Vejo o sacrifício de homens",
		"Vejo retratos de traições, E a última resistência de um irmão",
		"Vejo você à beira da morte... Vejo você dar seu último suspiro",
		"Eu vejo seu palácio coberto de vermelho, Rostos de homens que há muito acreditam que você está morto",
		"Vejo sua esposa com um homem que está assombrado, Um homem com um rastro de corpos",
	]
	for index in phrases.size():
		prophecy.model.puzzle=index+1; prophecy.model.phase=prophecy.model.Phase.MEMORY; prophecy._open_dialogue("vision_%d" % (index+1))
		check(prophecy.sentence.text == phrases[index], "The spoken vision matches line %d" % (index + 1))
		check(gm.underworld_vision_index==index,"Unheard prophecy cannot be silently persisted")
		while prophecy.dialogue.visible: prophecy.advance_dialogue()
	check(gm.underworld_vision_index==6 and not gm.underworld_prophecy_completed,"Six heard visions open the route, not the final completion flag")
	prophecy.model.position=prophecy.model.prophet; prophecy.model.request_interact()
	check(prophecy.sentence.text.begins_with("Vejo um homem") and not gm.underworld_prophecy_completed, "Tiresias starts the final prophecy face to face")
	prophecy.advance_dialogue()
	check(prophecy.sentence.text == "Mas não é você" and not gm.underworld_prophecy_completed, "The revelation gets its own dialogue beat")
	prophecy.advance_dialogue()
	check(gm.underworld_prophecy_completed and not prophecy.result.visible,"Final conversation triggers the reflection coda before the result screen")
	prophecy.visuals.update_visuals(2); prophecy._physics_process(3.2)
	check(prophecy.visuals.coda>1.9 and prophecy.result.visible and gm.player_current_hp==3 and gm.player_damage==8,"Moving reflection resolves without physical damage or changes to sacrifice attributes")
	prophecy.queue_free(); await process_frame
	var map: Control=load("res://Scenes/WorldMap.tscn").instantiate(); root.add_child(map); current_scene=map; await process_frame
	check(map.stops.size()==19 and map.stops[9].is_completed() and map.stops[10].is_completed() and map.stops[11].is_unlocked() and not map.stops[11].is_completed() and map.player.current_node==map.stops[11],"The two Underworld stops are completed and the map selects the newly unlocked Sirens")
	check(map.status_label.text.ends_with("VII") and map.stops[9].get_left()==map.stops[8] and map.stops[10].get_left()==map.stops[9],"Act numbering and navigable route include both new stages")
	map.queue_free(); await process_frame
	var music_paused: bool=root.get_node("AudioManager").music_player.stream_paused
	var prior_stream: AudioStream=root.get_node("AudioManager").music_player.stream
	root.get_node("AudioManager").play_music(load("res://Assets/act6_underworld/river_drone.wav"))
	journey=load("res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn").instantiate(); root.add_child(journey); current_scene=journey; await process_frame
	check(journey.ambience.playing and root.get_node("AudioManager").music_player.stream_paused,"Underworld uses its own ambient audio rather than overlapping campaign music")
	journey.begin()
	journey.model.phase = journey.model.Phase.REST
	journey.model.request_interact()
	journey.advance_dialogue()
	check(journey.sentence.text.begins_with("Meu filho"), "Anticleia's lines remain readable")
	var has_voice := false
	for player in journey.find_children("*", "AudioStreamPlayer", true, false):
		has_voice = has_voice or (player.stream != null and "/voices/" in player.stream.resource_path)
	check(not has_voice and journey.ambience.playing and journey.surge.playing,
		"The chase and Anticleia use ambience and effects without voice tracks")
	journey.queue_free(); await process_frame
	check(root.get_node("AudioManager").music_player.stream_paused==music_paused,"Leaving the stage restores the previous campaign music state")
	root.get_node("AudioManager").stop_music(); root.get_node("AudioManager").music_player.stream=prior_stream
	# Let the audio mix thread release stopped playbacks before this short-lived test exits.
	await create_timer(0.15).timeout
	check(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH)==save_before if not save_before.is_empty() else not FileAccess.file_exists(gm.SAVE_FILE_PATH),"Tests never write the player's campaign save")
	print("UNDERWORLD: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
