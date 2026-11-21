extends SceneTree
const CROSSING := preload("res://Ato6_Submundo/Gameplay/UnderworldCrossingModel.gd")
func _initialize() -> void: call_deferred("run")
func snapshot(label: String) -> void:
	await process_frame; await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://scratch/underworld_preview/"+label+".png")
func position_crossing(scene: Control, distance: float, pressure: float, stretch: float = 0.0) -> void:
	scene.model.distance = distance
	scene.model.pressure = pressure
	scene.model.stretch = stretch
	scene.model.clock = distance / 26.0
	scene.model.next_obstacle = 0
	while scene.model.next_obstacle < CROSSING.COURSE.size() and CROSSING.COURSE[scene.model.next_obstacle][0] < distance:
		scene.model.next_obstacle += 1
	scene.visuals.update_visuals(0)
	scene._update_ui()
func run() -> void:
	var gm: Node=root.get_node("GameManager"); gm.persistence_enabled=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/underworld_preview"))
	root.size=Vector2i(1152,648)
	var scene: Control=load("res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn").instantiate()
	scene.audio_enabled=false; scene.enforce_campaign_gate=false; root.add_child(scene); current_scene=scene
	await process_frame; scene.begin(); scene.set_physics_process(false); scene.set_process(false)
	position_crossing(scene, 27.0, 31.0); await snapshot("runner_chase")
	position_crossing(scene, 173.0, 67.0, 0.91); await snapshot("runner_distortion")
	position_crossing(scene, 245.0, 48.0); await snapshot("runner_low_beam")
	position_crossing(scene, 249.5, 48.0)
	scene.model.request_slide()
	for _step in 34:
		scene.model.tick(1.0 / 120.0)
		scene.visuals.update_visuals(1.0 / 120.0)
	scene._update_ui(); await snapshot("runner_slide")
	scene.model.slide_time = 0.0
	position_crossing(scene, CROSSING.FINISH - 15.0, 34.0); await snapshot("runner_exit")
	position_crossing(scene, CROSSING.CHECKPOINTS[2], 35.0)
	scene.model.phase = scene.model.Phase.REST
	scene.model.request_interact()
	scene.visuals.update_visuals(0)
	await snapshot("runner_mother"); scene.queue_free(); await process_frame
	scene=load("res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn").instantiate()
	scene.audio_enabled=false; scene.enforce_campaign_gate=false; root.add_child(scene); current_scene=scene
	await process_frame; scene.begin(); scene.set_physics_process(false); scene.set_process(false)
	scene.model.position=Vector2(560,425); scene.model.echoes.assign([{"p":Vector2(330,425),"f":Vector2.RIGHT}]); scene.model.activated.assign([true,true])
	scene.visuals.update_visuals(0); scene._update_ui(); await snapshot("oracle_first")
	scene.model.resume(3); scene.model.position=Vector2(360,385); scene.model.echoes.assign([{"p":Vector2(792,385),"f":Vector2.LEFT}]); scene.model.activated.assign([true,false])
	scene.visuals.update_visuals(0); scene._update_ui(); await snapshot("oracle_mirror")
	scene.model.resume(4); scene.model.position=Vector2(633,430); scene.model.sequence_step=2
	scene.model.echoes.assign([{"p":Vector2(545,460),"f":Vector2.RIGHT},{"p":Vector2(290,402),"f":Vector2.RIGHT}])
	scene.visuals.update_visuals(0); scene._update_ui(); await snapshot("oracle_order")
	scene.model.resume(5); scene.model.position=Vector2(700,418); scene.model.echoes.assign([{"p":Vector2(365,449),"f":Vector2.RIGHT},{"p":Vector2(245,389),"f":Vector2.RIGHT}]); scene.model.activated.assign([true,true])
	scene.visuals.update_visuals(0); scene._update_ui(); await snapshot("oracle_final")
	scene.model.phase=scene.model.Phase.MEMORY; scene._open_dialogue("vision_5"); scene.visuals.update_visuals(1); await snapshot("vision")
	scene.dialogue.hide(); scene.visuals.vision=0; scene.visuals.vision_blend=0
	scene.model.resume(scene.model.proof_count()); scene.model.position=Vector2(956,380); scene.model.phase=scene.model.Phase.ACTIVE
	scene.model.request_interact(); scene.advance_dialogue(); scene.visuals.update_visuals(0); scene._update_ui(); await snapshot("oracle_revelation")
	scene.advance_dialogue()
	scene.visuals.update_visuals(2); scene._update_ui(); await snapshot("reflection")
	scene.queue_free(); await process_frame
	gm.highest_unlocked_level=6; gm.act4_completed=true; gm.act4_unlocked_stage=3; gm.circe_moly_found=true; gm.circe_search_completed=true; gm.circe_battle_completed=true
	gm.underworld_crossing_completed=true; gm.underworld_prophecy_completed=true
	var map: Control=load("res://Scenes/WorldMap.tscn").instantiate(); root.add_child(map); current_scene=map
	await snapshot("map"); map.queue_free(); await process_frame; quit()
