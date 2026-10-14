extends Node
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const SCENE := preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var completions: int = 0

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
	release.pressed = false
	Input.parse_input_event(release)

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func snapshot(title: String) -> void:
	if not capture:
		return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/vigil_preview/"+title+".png")
	get_tree().paused = false

func _test_model() -> void:
	var model := MODEL.new(900)
	check(model.state == MODEL.State.READY and model.bag_sealed,"The bag starts sealed and the game waits for consent to begin.")
	model.start()
	check(model.state == MODEL.State.PLAYING and model.day_duration == 25.0,"Each of nine days must last 25 seconds.")
	var easy_rate: float = model.fatigue_rate()
	var easy_approach: float = model.approach_seconds()
	var easy_spawn: float = model.spawn_interval()
	model.day = 8
	check(model.fatigue_rate() > easy_rate and model.approach_seconds() < easy_approach and model.spawn_interval() < easy_spawn,"Later days must increase all three pressures.")
	model.day = 1
	check(not model.wake() and model.early_wakes == 1,"An early wake must not reward Space spam.")
	model.fatigue = 70
	check(not model.wake(),"A held/repeated input must respect the wake cooldown.")
	model.tick(0.81)
	check(model.wake() and model.fatigue < 40,"A timely wake must restore alertness.")
	var guarded: Dictionary = {"id":44,"side":1,"progress":0.75,"retreating":false}
	model.crew = [guarded]
	model.look(-1)
	check(not model.warn_crew() and not guarded.retreating,"The player must look toward the approaching crewman.")
	model.look(1)
	check(model.warn_crew() and guarded.retreating and model.prevented == 1,"Calling a visible crewman must send him away and credit the record.")
	check(not model.warn_crew(),"Repeated shouting must not duplicate credit.")
	model.crew = [{"id":45,"side":-1,"progress":0.995,"retreating":false}]
	model.tick(0.1)
	check(model.missed == 1 and not model.day_perfect and model.bag_sealed,"A missed approach costs concentration but cannot open the bag early.")
	model.fatigue = 99.9
	model.tick(0.1)
	check(model.microsleeps == 1 and model.state == MODEL.State.PLAYING and model.bag_sealed,"An early microsleep must continue the story.")
	var bot := MODEL.new(902)
	bot.start()
	var events: Array[int] = [0]
	bot.completed.connect(func(_record): events[0] += 1)
	var seen: Dictionary = {}
	for step in 18000:
		seen[bot.day] = true
		if bot.state == MODEL.State.PLAYING:
			if bot.fatigue >= 70:
				bot.wake()
			for visitor in bot.crew:
				if not visitor.retreating and float(visitor.progress) > 0.50:
					bot.look(int(visitor.side))
					bot.warn_crew()
		bot.tick(1.0/60.0)
		if bot.state == MODEL.State.ENDING:
			break
	check(seen.size() == 9 and bot.day == 9 and bot.state == MODEL.State.ENDING,"Good play must reach the inevitable event only after all nine days.")
	check(bot.perfect_days.size() == 9 and bot.microsleeps == 0 and bot.missed == 0 and bot.prevented > 15,"Skilled play must retain a meaningful perfect-run record.")
	var wakes: int = bot.successful_wakes
	check(not bot.wake() and not bot.warn_crew() and bot.successful_wakes == wakes,"The ninth-day narrative cannot be delayed by button presses.")
	bot.tick(7.2)
	check(bot.bag_sealed,"The bag must remain sealed until Eurylocus reaches it.")
	bot.tick(0.2)
	check(not bot.bag_sealed,"The winds must be released only in the final scene.")
	bot.tick(10)
	bot.tick(10)
	check(events[0] == 1 and bot.state == MODEL.State.COMPLETE and bot.record().story_complete,"Completion must emit once without Game Over.")
	var unattended := MODEL.new(903)
	unattended.start()
	for step in 18000:
		unattended.tick(1.0/60.0)
		if unattended.state == MODEL.State.COMPLETE:
			break
	check(unattended.state == MODEL.State.COMPLETE and unattended.microsleeps > 0 and unattended.perfect_days.size() < 9,"Mistakes must reduce the score without forcing a replay or ending before day nine.")

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
	var scene: Control = SCENE.instantiate()
	scene.persist_record = false
	scene.random_seed = 904
	scene.audio_enabled = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.vigilance_completed.connect(func(_record): completions += 1)
	await get_tree().create_timer(0.45).timeout
	check(scene.intro.visible and scene.model.state == MODEL.State.READY,"The game must explain its controls before the timer starts.")
	await snapshot("00_instructions")
	key(KEY_SPACE)
	await frames(2)
	check(scene.model.state == MODEL.State.PLAYING and not scene.intro.visible and scene.model.early_wakes == 0,"Starting with Space must not also trigger an early wake.")
	scene.model.fatigue = 67.0
	key(KEY_SPACE,true)
	await frames(2)
	check(scene.model.successful_wakes == 0,"Auto-repeat cannot wake Odysseus.")
	key(KEY_SPACE)
	await frames(2)
	check(scene.model.successful_wakes == 1 and scene.model.fatigue < 40.0,"The actual Space key must wake Odysseus.")
	scene.model.crew.clear()
	scene.model.crew.append({"id":91,"side":1,"progress":0.70,"retreating":false})
	key(KEY_A)
	key(KEY_E)
	await frames(2)
	check(scene.model.prevented == 0,"Wrong-side E input cannot repel the other crewman.")
	key(KEY_D)
	key(KEY_E)
	await frames(2)
	check(scene.model.look_side == 1 and scene.model.prevented == 1,"Actual A/D/E inputs must select the side and repel the approach.")
	await snapshot("01_awake_guard")
	key(KEY_ESCAPE)
	await frames(2)
	var clock: float = scene.model.day_clock
	var visual_clock: float = scene.visuals.elapsed
	await get_tree().create_timer(0.2,true).timeout
	check(get_tree().paused and scene.model.day_clock == clock and scene.visuals.elapsed == visual_clock,"Esc must pause both gameplay and the animated stage.")
	PauseMenu._on_resume_pressed()
	await frames(2)
	check(not get_tree().paused,"Resume must restore gameplay.")
	for dimensions in [Vector2i(800,1000),Vector2i(640,360)]:
		get_viewport().size = dimensions
		await frames(2)
		var bounds := Rect2(scene.stage.position,scene.DESIGN_SIZE*scene.stage.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= dimensions.x+0.1 and bounds.end.y <= dimensions.y+0.1,"Letterboxing must preserve HUD and all controls.")
	get_viewport().size = Vector2i(1152,648)
	scene.model.day = 5
	scene.model.day_clock = 12.5
	scene.model.fatigue = 85
	scene.model.crew.clear()
	await get_tree().create_timer(0.7).timeout
	check(scene.visuals.penelope.modulate.a > 0.04 and scene.visuals.odysseus.pose_index == 1,"Exhaustion after day five must show a Penelope vision and a sleepy pose.")
	await snapshot("05_penelope")
	scene.model.day = 9
	scene.model.day_clock = 20
	scene.model.fatigue = 72
	await get_tree().create_timer(0.7).timeout
	check(scene.visuals.home.modulate.a > 0.85,"Ithaca must fade into view on the ninth day.")
	await snapshot("09_ithaca")
	scene.model.day_clock = 24.95
	await get_tree().create_timer(0.2).timeout
	check(scene.model.state == MODEL.State.ENDING and not scene.result_panel.visible,"The ninth-day sleep must start a narrative scene, not an early result screen.")
	check(not scene.wake_button.visible and not scene.sleep_bar.visible,"The narrative must hide gameplay prompts so the ending is not a misleading reaction test.")
	key(KEY_SPACE)
	key(KEY_E)
	await get_tree().create_timer(2.4).timeout
	check(scene.visuals.odysseus.pose_index == 3 and scene.model.bag_sealed,"Odysseus must fall asleep before the bag opens.")
	await snapshot("10_sleep")
	await get_tree().create_timer(3.2).timeout
	check(scene.visuals.eurylochus.visible and scene.model.bag_sealed,"Eurylocus must visibly approach while the bag is still sealed.")
	await snapshot("11_eurylochus")
	await get_tree().create_timer(2.5).timeout
	check(not scene.model.bag_sealed and scene.visuals.burst > 0.0,"The scene must show the winds being released.")
	check(scene.visuals.contact.visible and scene.visuals.contact.pose_index == 1 and scene.visuals.odysseus.modulate.a == 0.0,"The opening must use the paired contact art with an actually open bag.")
	await snapshot("12_winds")
	await get_tree().create_timer(4.0).timeout
	check(scene.model.state == MODEL.State.COMPLETE and scene.result_panel.visible and completions == 1 and scene.completion_count == 1,"The result must appear once and permit an optional replay or map exit.")
	check(scene.result_panel.get_node("Record").text.contains("Dias impecáveis"),"The player must receive a performance record.")
	await snapshot("13_record")
	var final_campaign: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var final_score: PackedByteArray = FileAccess.get_file_as_bytes("user://vigil_record.json") if FileAccess.file_exists("user://vigil_record.json") else PackedByteArray()
	check(campaign_save == final_campaign and score_save == final_score and GameManager.inventory == inventory,"Tests must preserve campaign progress, inventory and any existing score file.")
	scene.return_to_map()
	await get_tree().create_timer(0.3).timeout
	check(get_tree().current_scene.name == "WorldMap","The result must provide a real map route.")
	print("NINE DAYS VIGIL: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
