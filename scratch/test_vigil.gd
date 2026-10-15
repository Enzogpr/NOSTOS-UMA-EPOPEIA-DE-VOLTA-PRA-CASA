extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const SCENE := preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var completions: int = 0
var early_losses: int = 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	release.physical_keycode = code
	Input.parse_input_event(release)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func snapshot(title: String) -> void:
	if not capture: return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/vigil_preview/"+title+".png")
	get_tree().paused = false

func play_optimal(model: MODEL) -> void:
	if model.state != MODEL.State.PLAYING: return
	if model.is_sleepy(): model.wake()
	if model.is_sleepy() or model.shout_cooldown > 0.0: return
	var chosen: Dictionary = {}
	for visitor in model.crew:
		if not visitor.retreating and float(visitor.progress) > 0.19:
			if chosen.is_empty() or float(visitor.progress) > float(chosen.progress): chosen = visitor
	if not chosen.is_empty():
		model.look(int(chosen.side))
		model.warn_crew()

func _test_model() -> void:
	var model := MODEL.new(900)
	model.start()
	check(model.day_duration == 25.0 and model.bag_sealed,"The bag starts sealed and campaign days last 25 seconds.")
	var previous_rate: float = 0
	var previous_time: float = 100
	var previous_interval: float = 100
	for day in range(1,10):
		model.day = day
		check(model.fatigue_rate() > previous_rate and model.approach_seconds() < previous_time and model.spawn_interval() < previous_interval,"All three pressures must strictly increase on day %d." % day)
		previous_rate = model.fatigue_rate()
		previous_time = model.approach_seconds()
		previous_interval = model.spawn_interval()
	model.day = 1
	model.fatigue = 65
	var visitor: Dictionary = {"id":40,"side":1,"progress":0.65,"retreating":false}
	model.crew.append(visitor)
	model.look(1)
	check(not model.warn_crew() and not visitor.retreating and model.prevented == 0,"Sleepy Odysseus cannot repel anyone, even on the watched side.")
	check(model.wake() and model.fatigue < MODEL.WAKE_START,"Only the player's wake action restores alertness.")
	check(model.warn_crew() and visitor.retreating and model.prevented == 1,"An alert Odysseus can repel the visitor.")
	check(not model.warn_crew() and not model.wake(),"Cooldowns must block duplicate actions.")
	var sleeper := MODEL.new(901)
	sleeper.start()
	sleeper.fatigue = 99.9
	var loss_count: Array[int] = [0]
	sleeper.failed.connect(func(_reason): loss_count[0] += 1)
	sleeper.tick(0.1)
	check(sleeper.state == MODEL.State.FAILED and sleeper.loss_reason == "sono" and sleeper.fatigue == 100.0,"100% fatigue causes a real early loss.")
	var failed_clock: float = sleeper.day_clock
	sleeper.tick(50)
	check(not sleeper.wake() and not sleeper.warn_crew() and sleeper.day_clock == failed_clock and loss_count[0] == 1,"The failed run cannot wake automatically, advance days or emit another loss.")
	var breach := MODEL.new(902)
	breach.start()
	var intruder: Dictionary = {"id":41,"side":-1,"progress":0.999,"retreating":false}
	breach.crew.append(intruder)
	breach.tick(0.1)
	check(breach.state == MODEL.State.FAILED and breach.loss_reason == "bolsa" and not breach.bag_sealed and not intruder.retreating,"An intruder reaching the bag must end the run, with no automatic rescue.")
	var dawn := MODEL.new(903)
	dawn.start()
	dawn.fatigue = 75
	dawn.day_clock = 24.99
	dawn.tick(0.02)
	var before_dawn: float = dawn.fatigue
	dawn.tick(1.66)
	check(dawn.day == 2 and dawn.fatigue >= before_dawn and dawn.successful_wakes == 0,"Changing days must not restore alertness.")
	var pair := MODEL.new(904)
	pair.start()
	pair.day = 8
	pair._spawn_crew()
	check(pair.crew.size() == 2 and int(pair.crew[0].side) == -int(pair.crew[1].side) and pair.crew[0].progress == pair.crew[1].progress,"Later waves must really spawn both sides at the same instant.")
	for seed_value in range(910,922):
		var bot := MODEL.new(seed_value)
		bot.start()
		for step in 36000:
			play_optimal(bot)
			bot.tick(1.0/120.0)
			if bot.state in [MODEL.State.FAILED,MODEL.State.ENDING]: break
		check(bot.state == MODEL.State.ENDING and bot.day == 9 and bot.days_completed == 8,"Responsive play must survive days 1–8, then lose on day 9 (seed %d)." % seed_value)
		check(bot.day_clock < bot.day_duration and bot.loss_reason in ["sono","bolsa"],"Day nine must overwhelm the real mechanics before its timer expires.")
		check(not bot.wake() and not bot.warn_crew() and bot.bag_sealed,"The inner monologue must start without revealing an opener.")
		bot.tick(60)
		check(bot.state == MODEL.State.ENDING and bot.bag_sealed,"A timer must not skip the supplied dialogue or reveal the bag.")
		bot.ending_alarm()
		var finished: Array[int] = [0]
		bot.completed.connect(func(_record): finished[0] += 1)
		bot.finish_thoughts()
		bot.finish_thoughts()
		check(bot.state == MODEL.State.COMPLETE and finished[0] == 1,"The last supplied line completes the narrative exactly once.")

func new_game() -> Control:
	var scene: Control = SCENE.instantiate()
	scene.persist_record = false
	scene.random_seed = 933
	scene.audio_enabled = false
	scene.autoplay_thoughts = false
	scene.continue_to_poseidon = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	return scene

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://scratch/vigil_preview")
	_test_model()
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var campaign_save: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var score_save: PackedByteArray = FileAccess.get_file_as_bytes("user://vigil_record.json") if FileAccess.file_exists("user://vigil_record.json") else PackedByteArray()
	var inventory: Array = GameManager.inventory.duplicate(true)
	var scene: Control = new_game()
	scene.vigilance_failed.connect(func(_reason): early_losses += 1)
	await get_tree().create_timer(0.45).timeout
	check(scene.intro.visible and scene.model.state == MODEL.State.READY,"Instructions must precede the live timer.")
	await snapshot("loss_00_instructions")
	key(KEY_SPACE)
	await frames(2)
	check(scene.model.state == MODEL.State.PLAYING and scene.model.early_wakes == 0,"Starting with Space must not also wake.")
	scene.model.crew.append({"id":91,"side":1,"progress":0.5,"retreating":false})
	scene.model.fatigue = 67
	key(KEY_D)
	key(KEY_E)
	key(KEY_SPACE,true)
	await frames(2)
	check(scene.model.prevented == 0 and scene.model.successful_wakes == 0 and scene.warn_button.disabled,"Sleep blocks both keyboard E and its button; Space auto-repeat is ignored.")
	key(KEY_SPACE)
	await frames(2)
	key(KEY_E)
	await frames(2)
	check(scene.model.successful_wakes == 1 and scene.model.prevented == 1,"Real Space then E must restore control and repel the visitor.")
	key(KEY_ESCAPE)
	await frames(2)
	var clock: float = scene.model.day_clock
	var visual_clock: float = scene.visuals.elapsed
	await get_tree().create_timer(0.2,true).timeout
	check(get_tree().paused and scene.model.day_clock == clock and scene.visuals.elapsed == visual_clock,"Esc freezes mechanics and sight effects.")
	PauseMenu._on_resume_pressed()
	for dimensions in [Vector2i(800,1000),Vector2i(640,360)]:
		get_viewport().size = dimensions
		await frames(2)
		var bounds := Rect2(scene.stage.position,scene.DESIGN_SIZE*scene.stage.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= dimensions.x+0.1 and bounds.end.y <= dimensions.y+0.1,"Controls and dialogue must letterbox without clipping.")
	get_viewport().size = Vector2i(1152,648)
	scene.model.fatigue = 100
	await frames(2)
	check(scene.model.state == MODEL.State.FAILED and scene.result_panel.visible and not scene.thought_panel.visible and early_losses == 1,"An early loss shows defeat, not the ninth-day monologue.")
	key(KEY_SPACE)
	key(KEY_E)
	await get_tree().create_timer(0.65).timeout
	check(scene.model.state == MODEL.State.FAILED and scene.model.fatigue == 100,"Buttons cannot automatically recover a lost attempt.")
	await snapshot("loss_01_defeat")
	scene.queue_free()
	await frames(2)
	scene = new_game()
	scene.vigilance_completed.connect(func(_record): completions += 1)
	await get_tree().create_timer(0.4).timeout
	scene.begin()
	scene.model.day = 8
	scene.model.day_clock = 12.5
	scene.model.fatigue = 82
	scene.model._spawn_crew()
	await get_tree().create_timer(0.25).timeout
	check(scene.model.crew.size() == 2 and scene.warn_button.disabled,"Both attackers remain a real threat while sleepy.")
	var shader: ShaderMaterial = scene.visuals.blur.material
	check(float(shader.get_shader_parameter("day_pressure")) > 0.8 and float(shader.get_shader_parameter("fatigue")) > 0.8,"The vision must tighten with both the day and current sleep.")
	await snapshot("loss_08_blackout")
	scene.model.crew.clear()
	scene.model.day = 9
	scene.model.day_clock = 0
	scene.model.fatigue = 12
	await get_tree().create_timer(0.7).timeout
	check(scene.visuals.home.modulate.a > 0.85,"Ithaca remains visible before the ninth-day collapse.")
	await snapshot("loss_09_ithaca")
	scene.model.fatigue = 100
	await frames(3)
	check(scene.model.state == MODEL.State.ENDING and scene.thought_panel.visible and not scene.result_panel.visible,"The day-nine loss cuts directly into the supplied monologue.")
	check(scene.visuals.mental_background.visible and not scene.visuals.background.visible and not scene.visuals.home.visible and not scene.visuals.blur.visible,"The inner scene must have a dark background and no visible deck.")
	check(not scene.visuals.get("eurylochus") and not scene.visuals.get("contact"),"No character or contact art may identify the bag's opener.")
	check(not scene.wake_button.visible and not scene.sleep_bar.visible,"Gameplay prompts disappear when the thought dialogue begins.")
	scene.thought_cooldown = 0
	key(KEY_SPACE)
	await frames(2)
	check(scene.thought_index == 0 and scene.thought_text.visible_characters == scene.thought_text.get_total_character_count(),"First dialogue input reveals the current supplied lines.")
	for index in scene.thoughts.size():
		scene._show_thought(index)
		scene.thought_type_clock = 1000
		await get_tree().create_timer(0.5).timeout
		check(scene.thought_text.text == scene.thoughts[index].text and scene.thought_text.get_content_height() <= int(scene.thought_text.size.y),"Every supplied line fits in thought beat %d." % index)
		if index in [0,2,4,5]: await snapshot("loss_thought_%d" % index)
		if index == 5:
			check(scene.visuals.thought_speaker == "Penélope" and scene.visuals.penelope.modulate.a > 0.8 and scene.visuals.released_winds == null,"Penelope's last warning stays in the dark before reality returns.")
		if index >= 6:
			var storm: Node2D = scene.visuals.released_winds
			check(storm != null and not scene.visuals.camera.visible and not scene.visuals.mental_background.visible,"Every new line must use the illustrated storm instead of the mental background.")
			check(storm.current_shot == scene.thoughts[index].shot,"Each new line must cue its own action shot.")
			if index == 8:
				check(storm.aeolus.visible and not storm.odysseus.visible and not storm.eurylochus.visible,"Aeolus's close-up must not overlap the soldiers' portraits.")
			if index == 9:
				storm.shot_elapsed = 1.3
				storm._process(0.0)
				var ship_start: Vector2 = storm.distant_ship.position
				var ship_size: float = storm.distant_ship.scale.x
				await snapshot("winds_09_departure_near")
				storm.shot_elapsed = 4.25
				storm._process(0.0)
				check(storm.exterior.visible and storm.distant_ship.position.x > ship_start.x+350 and storm.distant_ship.scale.x < ship_size*0.5,"The giant-land warning must visibly carry the ship far toward the horizon.")
				await snapshot("winds_09_departure_far")
			if index in [6,8,10,11,12,13,15]:
				await get_tree().create_timer(0.8).timeout
				await snapshot("winds_%02d_%s" % [index,storm.current_shot])
	check(scene.thoughts[5].speaker == "Penélope" and scene.thoughts[5].text == "Acorda!" and scene.thoughts[6].text == "Não!","The new sequence must continue directly after Penelope's supplied last warning.")
	check(scene.thoughts[-1].speaker == "Desconhecido" and scene.thoughts[-1].text == "Você sabe quem eu sou?","The adaptation must stop at the unidentified voice's supplied question.")
	check(scene.visuals.released_winds.bag_secured and scene.visuals.released_winds.atmosphere > 0.5,"The remaining wind is secured before the sea answers.")
	check(not scene.visuals.released_winds.odysseus.visible and not scene.visuals.released_winds.eurylochus.visible and not scene.visuals.released_winds.aeolus.visible,"The final voice must have no identifying portrait.")
	check(scene.visuals.released_winds.presence.visible and float(scene.visuals.released_winds.presence.material.get_shader_parameter("emergence")) > 0.5 and not scene.visuals.released_winds.exterior.visible,"The unknown voice must emerge as an indistinct fog form after the exterior shot.")
	var storm_clock: float = scene.visuals.released_winds.elapsed
	key(KEY_ESCAPE)
	await get_tree().create_timer(0.15,true).timeout
	check(get_tree().paused and scene.visuals.released_winds.elapsed == storm_clock,"Esc must freeze the illustrated ending and its weather too.")
	key(KEY_ESCAPE)
	await frames(2)
	scene.thought_cooldown = 0
	scene._advance_thought_requested()
	scene.model.finish_thoughts()
	await frames(2)
	check(scene.model.state == MODEL.State.COMPLETE and completions == 1 and scene.completion_count == 1 and scene.result_panel.visible,"The final line completes only the story and emits once.")
	await snapshot("loss_10_after_warning")
	var final_campaign: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var final_score: PackedByteArray = FileAccess.get_file_as_bytes("user://vigil_record.json") if FileAccess.file_exists("user://vigil_record.json") else PackedByteArray()
	check(campaign_save == final_campaign and score_save == final_score and GameManager.inventory == inventory,"Tests must preserve campaign and score saves.")
	scene.return_to_map()
	await get_tree().create_timer(0.3).timeout
	check(get_tree().current_scene.name == "WorldMap","The final card retains a working map route.")
	print("VIGIL LOSS AND THOUGHTS: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
