extends Node

var checks: int = 0
var failures: int = 0
var capture: bool = false
var attached_count: int = 0
var completed_count: int = 0
var completed_in_correct_state: bool = false
var completed_hull: float = 0.0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func wait_scene(scene_name: String) -> Node:
	for _frame in 1200:
		await get_tree().physics_frame
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene != null and scene.name == scene_name:
			await get_tree().process_frame
			return scene
	check(false, "Scene handoff timed out: " + scene_name)
	get_tree().quit(1)
	return null

func screenshot(name: String) -> void:
	if not capture:
		return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/" + name + ".png")
	get_tree().paused = false

func solve_shot(game: Control) -> Vector2:
	# Search a ballistic shot, then use real firing input and wait for contact.
	var best: float = INF
	var solution := Vector2(50, 0.3)
	for degrees in range(30, 71, 5):
		var direction := Vector2.RIGHT.rotated(-deg_to_rad(float(degrees)))
		var origin: Vector2 = game.LAUNCHER + direction * 32
		for strength_step in range(5, 81, 2):
			var strength: float = strength_step / 100.0
			var speed: float = 370 + strength * 410
			if origin.y - pow(direction.y * speed, 2) / (2.0 * game.GRAVITY) < -100:
				continue
			for time_step in range(1, 181):
				var time: float = time_step / 60.0
				var point: Vector2 = origin + direction * speed * time + Vector2(game.wind, 360) * (0.5 * time * time)
				var future_target: Vector2 = game.island_position_at(game.clock + time) + game.ANCHOR_OFFSET
				var distance: float = point.distance_to(future_target)
				if distance < best:
					best = distance
					solution = Vector2(degrees, strength)
	check(best < 8, "The visible moving target must be reachable with an ordinary angle and charge.")
	return solution

func _ready() -> void:
	set_meta("hide_main_hud", true)
	capture = "--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152, 648)
	var original_progress: int = GameManager.highest_unlocked_level
	var original_inventory: Array = GameManager.inventory.duplicate(true)
	var save_bytes := FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var had_hull_meta: bool = GameManager.has_meta("aeolia_arrival_hull")
	var old_hull_meta: Variant = GameManager.get_meta("aeolia_arrival_hull", 100.0)
	var storm := preload("res://Ato4_Tempestade/Gameplay/StormLevel.tscn").instantiate()
	storm.persist_progress = false
	get_tree().root.add_child(storm)
	get_tree().current_scene = storm
	storm.ship.hull = 72.5
	storm.state = storm.State.ARRIVAL
	storm.finish(true)
	await frames(3)
	check(storm.hud.continue_button.visible, "Winning the crossing must offer a visible route to Aeolia.")
	check(storm.hud.continue_button.has_focus(), "The continue action must receive keyboard focus after victory.")
	storm.hud.continue_button.pressed.emit()
	var approach: Control = await wait_scene("AeoliaApproachCutscene")
	check(approach.beats.size() == 8 and approach.beats[0].speaker == "Euríloco", "The storm button must first open the supplied eight-part crew dialogue.")
	check(approach.beats[1].speaker == "Perimedes e Elpenor" and approach.beats[2].speaker == "Odisseu e Euríloco", "The joint speakers must retain their supplied names.")
	check(float(GameManager.get_meta("aeolia_arrival_hull")) == 72.5 and not MainHUD.visible, "The dialogue must retain arrival hull and keep the combat HUD hidden.")
	await get_tree().create_timer(0.7).timeout
	await screenshot("aeolia_approach")
	for index in approach.beats.size():
		check(approach.beat_index == index and approach.cinematic.caption_text == approach.beats[index].text, "The introduction must present the exact supplied dialogue in order: %d." % index)
		approach.cinematic.type_elapsed = 10.0
		approach.cinematic.dialogue.visible_characters = approach.cinematic.dialogue.get_total_character_count()
		await get_tree().process_frame
		check(approach.cinematic.dialogue.get_content_height() <= int(approach.cinematic.dialogue.size.y), "The introduction caption must fit: %d." % index)
		if index == 2:
			check(approach.cinematic.image_path == approach.DISCOVERY and not approach.cinematic.get_node("Stage/World/Odysseus").visible and not approach.cinematic.get_node("Stage/World/Athena").visible, "Discovery must show the unobstructed sky landscape, without ship portraits covering Aeolia.")
			check(approach.cinematic.get_node_or_null("Stage/World/SkyIsland") == null, "Aeolia must not be composited as a decal over the ship's sail.")
		if index == 7:
			check(approach.cinematic.get_node("Stage/World/Odysseus").visible and not approach.cinematic.get_node("Stage/World/Athena").visible, "The final command must have a dedicated shot of Odysseus.")
		if index in [0, 1, 2, 3, 4, 6, 7]:
			await get_tree().create_timer(0.3).timeout
			await screenshot("aeolia_approach_%d" % index)
		approach.cinematic.input_cooldown = 0
		approach.cinematic._advance_requested()
	check(approach.handoff_started, "Only finishing the last line must hand control to the harpoon scene.")
	var game: Control = await wait_scene("AeoliaHarpoon")
	check(game.name == "AeoliaHarpoon" and game.state == game.State.READY, "The actual storm button must load the safe harpoon instructions.")
	game.transition_enabled = false
	game.rope_attached.connect(func(): attached_count += 1)
	game.ascent_completed.connect(func():
		completed_count += 1
		completed_in_correct_state = game.state == game.State.COMPLETE
		completed_hull = game.arrival_hull
	)
	check(game.arrival_hull == 72.5 and not MainHUD.visible, "The minigame must preserve the arrival hull and use its own HUD.")
	check(game.get_node("ShotSound").bus == &"SFX" and game.get_node("ShotSound").stream != null, "The harpoon must use a valid effect on the SFX bus.")
	await screenshot("aeolia_instructions")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await frames(3)
	check(game.state == game.State.AIMING, "Real Enter must begin aiming.")
	var original_angle: float = game.angle_degrees
	for _frame in 15:
		key(KEY_D, true)
		await get_tree().physics_frame
	key(KEY_D, false)
	check(game.angle_degrees > original_angle + 5, "Real D input must adjust the launcher angle.")
	game.angle_degrees = 50
	key(KEY_SPACE, true)
	await frames(6)
	check(game.state == game.State.CHARGING and game.charge > 0.04, "Holding Space must charge the strength meter.")
	var paused_clock: float = game.clock
	var paused_charge: float = game.charge
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	check(game.clock == paused_clock and game.charge == paused_charge, "Pause must freeze the target, breeze and charge.")
	get_tree().paused = false
	game.charge = 0
	key(KEY_SPACE, false)
	await frames(1)
	check(game.state == game.State.FLYING and game.attempts == 1, "Releasing Space must fire exactly once.")
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await frames(1)
	check(game.attempts == 1, "Repeated presses must not create multiple projectiles in flight.")
	for _frame in 240:
		if game.state == game.State.AIMING:
			break
		await get_tree().physics_frame
	check(game.state == game.State.AIMING and attached_count == 0 and game.arrival_hull == 72.5, "A weak missed shot must retract and allow another try without hull loss.")
	await screenshot("aeolia_aiming")
	get_viewport().size = Vector2i(800, 1000)
	await frames(2)
	check(game.stage.scale.x < 0.7 and game.stage.position.y > 200, "A portrait window must letterbox the entire stage without changing aim coordinates.")
	await screenshot("aeolia_portrait")
	get_viewport().size = Vector2i(1152, 648)
	await frames(2)
	var target_before: Vector2 = game.anchor.position
	await frames(30)
	check(game.anchor.position.distance_to(target_before) > 1 and absf(game.wind) <= 22.01, "The island must move with a mild breeze.")
	var min_target := Vector2(INF, INF)
	var max_target := Vector2(-INF, -INF)
	for step in 1200:
		var position: Vector2 = game.island_position_at(step / 60.0) + game.ANCHOR_OFFSET
		min_target = min_target.min(position)
		max_target = max_target.max(position)
	check(max_target.x - min_target.x > 190 and max_target.y - min_target.y > 63, "The island must travel broadly in both axes.")
	check(min_target.x - game.LAUNCHER.x > 415 and max_target.x - game.LAUNCHER.x > 600, "Even the closest target must remain farther from the ship than before.")
	key(KEY_SPACE, true)
	await frames(1)
	# Hold simulation only while dispatching the known release input. Otherwise
	# headless/GL event ordering can add a physics tick of extra charge and drift.
	game.set_physics_process(false)
	var solution: Vector2 = solve_shot(game)
	game.angle_degrees = solution.x
	game.charge = solution.y
	key(KEY_SPACE, false)
	for _frame in 3:
		await get_tree().process_frame
		if game.state == game.State.FLYING:
			break
	game.set_physics_process(true)
	await frames(15)
	await screenshot("aeolia_harpoon_flight")
	for _frame in 240:
		if game.state >= game.State.LATCHED:
			break
		await get_tree().physics_frame
	check(game.state == game.State.LATCHED and attached_count == 1 and game.attempts == 2, "A real ballistic contact with the aro must attach the rope with one successful shot.")
	if game.state < game.State.LATCHED:
		get_tree().quit(1)
		return
	check(game.projectile.distance_to(game.anchor.position) < 1 and not game.map_button.visible, "A successful rope must stay fixed to the target and secure the ascent.")
	await screenshot("aeolia_rope_attached")
	for _frame in 100:
		if game.conversation != null:
			break
		await get_tree().physics_frame
	check(game.state == game.State.DIALOGUE and game.conversation != null and not game.climber.visible, "The secured rope must open Luck Runs Out before Odysseus climbs.")
	var conversation: Control = game.conversation
	conversation.autoplay = false
	await get_tree().create_timer(1.3).timeout
	check(conversation.beats.size() == 33 and conversation.can_advance, "The pre-ascent scene must load all supplied lines with working controls.")
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await frames(2)
	check(conversation.current_beat == 0 and conversation.dialogue.visible_characters == conversation.dialogue.get_total_character_count() and game.attempts == 2, "Real dialogue input must reveal the line without firing another harpoon.")
	await screenshot("aeolia_luck_before_ascent")
	var frozen_target: Vector2 = game.anchor.position
	await frames(20)
	check(game.state == game.State.DIALOGUE and game.anchor.position == frozen_target and game.arrival_hull == 72.5, "The dialogue must not move the secured island, begin ascent or damage the ship.")
	conversation._show_beat(32)
	conversation.input_cooldown = 0.0
	conversation.dialogue.visible_characters = conversation.dialogue.get_total_character_count()
	conversation._advance_requested()
	await get_tree().create_timer(2.6).timeout
	check(game.dialogue_completed and game.conversation == null and game.state == game.State.CLIMBING, "The final thanks must resume the same rope and begin ascent exactly once.")
	await frames(100)
	check(game.state == game.State.CLIMBING and game.climber.visible and game.climber.position.distance_to(game.LAUNCHER) > 15, "Odysseus must visibly climb the anchored rope.")
	await screenshot("aeolia_ascent")
	game.transition_enabled = true
	var meeting: Control = await wait_scene("AeoliaMeetingCutscene")
	check(completed_in_correct_state and completed_count == 1, "The ascent must complete once and automatically open the encounter.")
	await frames(5)
	check(completed_count == 1 and completed_hull == 72.5, "Completion must not repeat or alter the arrival hull.")
	check(meeting.name == "AeoliaMeetingCutscene" and meeting.beats.size() == 34, "Completing the ascent must load the full supplied encounter with Aeolus.")
	check(meeting.director.aeolus != null, "Aeolus must have an animated body in the encounter.")
	meeting.autoplay = false
	await get_tree().create_timer(1.3).timeout
	await screenshot("aeolia_meeting_odysseus")
	meeting._show_beat(5)
	await get_tree().create_timer(1.5).timeout
	await screenshot("aeolia_meeting_aeolus")
	meeting._show_beat(33)
	await get_tree().create_timer(2.4).timeout
	meeting.input_cooldown = 0
	meeting.dialogue.visible_characters = meeting.dialogue.get_total_character_count()
	meeting._advance_requested()
	await get_tree().create_timer(2.3).timeout
	check(meeting.end_panel.visible, "The encounter must finish with usable replay/map controls.")
	await screenshot("aeolia_meeting_complete")
	meeting.end_panel.get_node("Retry").pressed.emit()
	meeting = await wait_scene("AeoliaMeetingCutscene")
	check(meeting.name == "AeoliaMeetingCutscene" and meeting.current_beat == -1 and not meeting.ended, "Replay must restart the conversation.")
	meeting._leave("res://Scenes/WorldMap.tscn")
	await wait_scene("WorldMap")
	check(get_tree().current_scene.name == "WorldMap", "The minigame must provide an actual route back to the map.")
	check(GameManager.highest_unlocked_level == original_progress and GameManager.inventory == original_inventory, "The introductory encounter must neither unlock another act nor award story items.")
	var final_save := FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	check(final_save == save_bytes, "Testing the new minigame must leave saved progress unchanged.")
	if had_hull_meta:
		GameManager.set_meta("aeolia_arrival_hull", old_hull_meta)
	else:
		GameManager.remove_meta("aeolia_arrival_hull")
	print("AEOLIA HARPOON: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
