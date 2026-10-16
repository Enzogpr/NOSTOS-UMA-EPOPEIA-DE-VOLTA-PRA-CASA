extends Node
var checks: int = 0
var failures: int = 0
var capture: bool = false
var finished: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)

func snapshot(title: String) -> void:
	if not capture: return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	if title != "shot_99_end":
		var outside: Color = frame.get_pixel(85,180)
		var other: Color = frame.get_pixel(1090,360)
		check(maxf(outside.r+outside.g+outside.b,other.r+other.g+other.b) > 0.12,"The rendered world must remain visible behind the actors in "+title)
	frame.save_png("res://scratch/poseidon_preview/"+title+".png")
	get_tree().paused = false

func _ready() -> void:
	set_meta("hide_main_hud",true)
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://scratch/poseidon_preview")
	var save_before: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var score_before: PackedByteArray = FileAccess.get_file_as_bytes("user://vigil_record.json") if FileAccess.file_exists("user://vigil_record.json") else PackedByteArray()
	var inventory: Array = GameManager.inventory.duplicate(true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	var scene: Control = preload("res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn").instantiate()
	scene.continue_to_escape = false
	scene.autoplay = false
	scene.audio_enabled = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.cinematic_finished.connect(func(): finished += 1)
	await get_tree().create_timer(1.5).timeout
	check(scene.current_beat == 0 and scene.beats.size() == 39,"The continuation must start with Odysseus's identification and include every supplied block.")
	check(scene.beats[0].speaker == "Odisseu" and scene.beats[0].text == "Poseidon" and scene.beats[-1].text == "Morra","The cinematic must preserve the requested endpoints.")
	var speak_count: int = 0
	for beat in scene.beats:
		if not str(beat.text).is_empty(): speak_count += 1
	check(speak_count == 38 and scene.beats[24].text.is_empty(),"Removed refrains must become silent choreography, without invented dialogue.")
	for index in scene.beats.size():
		scene._show_beat(index)
		scene.can_advance = false
		scene.dialogue.visible_characters = -1
		var t: float = float(scene.beats[index].duration)*0.65
		if index == 0: t = 3.0
		if index == 5: t = 0.8
		if index == 11: t = 5.0
		if index == 12: t = 3.0
		if index == 24: t = 6.0
		if index == 38: t = 2.1
		scene.director.seek(t,0.8)
		await get_tree().create_timer(0.32).timeout
		check(scene.dialogue.text == scene.beats[index].text and scene.dialogue.get_content_height() <= int(scene.dialogue.size.y),"The entire Portuguese caption must fit in shot %d." % index)
		check(scene.director.deck.visible != scene.director.ocean.visible,"Exactly one physical environment must be active in shot %d." % index)
		await snapshot("shot_%02d_%s" % [index,scene.beats[index].shot])
		if index in [4,5,6,20,21,22]:
			check(scene.director.contact.visible and not scene.director.god.visible and not scene.director.odysseus.visible,"The actual grip must stay connected in a joint drawing in shot %d." % index)
			check(scene.director.contact.modulate.a > 0.98,"The contact drawing must actually be opaque after its entry, in shot %d." % index)
		if index == 1:
			scene.director.seek(0.6,0.2)
			check(scene.director.face.pose_index == 0,"Poseidon must begin with closed eyes.")
			scene.director.seek(4.9,0.2)
			check(scene.director.face.pose_index == 2,"His eyes must open before the accusation.")
		if index == 11:
			var first: Vector2 = scene.director.horse.position
			scene.director.seek(7.0,0.2)
			check(scene.director.horse.position.x > first.x+200,"The horse must actually gallop through the fleet.")
		if index == 12:
			scene.director.seek(5.0,0.2)
			check(scene.director.horse.pose_index == 4,"The leap must turn into a head-first dive.")
		if index == 24:
			check(scene.director.contact.pose_index == 3 and scene.director.contact.height < 400,"Eurylochus must visibly support Odysseus after the release.")
		if index == 23:
			check(scene.director.god.visible and scene.director.god.position.x == 810 and scene.director.odysseus.visible and scene.director.odysseus.position.x < 450,"Poseidon must stay anchored while only Odysseus is projected toward Eurylochus.")
		if index == 25:
			check(scene.director.kneeling.pose_index == 1,"The threat must bring Odysseus down to prostration before the plea.")
		if index in [29,30,31,32]:
			check(scene.director.kneeling.visible and not scene.director.odysseus.visible,"Odysseus must plead from his knees.")
		if index == 38:
			check(scene.director.impact_wave.visible and scene.director.impact_wave.position.x < 1300,"A real foreground water front must reach the fleet at the first impact.")
			var sound_count: int = scene.sound_events.count("impact")
			scene.director.seek(2.2,0.1)
			check(scene.director.impact_fired and scene.sound_events.count("impact") == sound_count,"The first impact must be timed and emitted only once.")
	scene._show_beat(4)
	scene.can_advance = true
	scene.dialogue.visible_characters = -1
	scene.type_elapsed = 1000
	scene.input_cooldown = 0
	scene._advance_requested()
	check(scene.current_beat == 4,"Manual advance cannot skip the physical action before it finishes.")
	scene.shot_clock = scene.beats[4].duration
	scene.input_cooldown = 0
	scene._advance_requested()
	check(scene.current_beat == 5,"Manual advance becomes available after the contact action.")
	var clock: float = scene.shot_clock
	var ambient_clock: float = scene.director.elapsed
	key(KEY_ESCAPE)
	await get_tree().create_timer(0.15,true).timeout
	check(get_tree().paused and scene.shot_clock == clock and scene.director.elapsed == ambient_clock,"Esc must freeze speech, camera, actors, water and events together.")
	key(KEY_ESCAPE)
	await get_tree().process_frame
	get_viewport().size = Vector2i(800,1000)
	await get_tree().process_frame
	check(scene.stage.scale.x < 0.7 and scene.stage.position.y > 200,"Portrait windows must letterbox without stretching the actors.")
	get_viewport().size = Vector2i(1152,648)
	await get_tree().process_frame
	scene.autoplay = true
	for index in scene.beats.size():
		scene._show_beat(index)
		scene.shot_clock = float(scene.beats[index].duration)-0.01
		scene._process(0.02)
	check(scene.is_ending and scene.complete_count == 1 and finished == 1,"Automatic playback must finish the whole timeline exactly once.")
	scene._finish()
	check(scene.complete_count == 1 and scene.end_panel.visible,"The end is idempotent and retains replay/map controls.")
	await snapshot("shot_99_end")
	scene.queue_free()
	await get_tree().process_frame
	# Real integration: the last supplied question must lead to Poseidon, without a score card.
	var previous: Control = preload("res://Ato4_Tempestade/Cutscenes/ReleasedWindsPreview.tscn").instantiate()
	previous.persist_record = false
	previous.audio_enabled = false
	previous.autoplay_thoughts = false
	get_tree().root.add_child(previous)
	get_tree().current_scene = previous
	await get_tree().create_timer(0.6).timeout
	previous._show_thought(previous.thoughts.size()-1)
	previous.model.finish_thoughts()
	await get_tree().create_timer(0.9).timeout
	var next: Control = get_tree().current_scene
	check(next.name == "Ruthlessness" and not is_instance_valid(previous),"The actual preceding cutscene must hand off directly and release its scene.")
	check(next.handoff_record.get("story_complete",false),"The handoff must retain the voyage record without replaying the vigil.")
	next.audio_enabled = false
	next.stop_audio()
	await get_tree().create_timer(0.15).timeout
	next.queue_free()
	await get_tree().process_frame
	var save_after: PackedByteArray = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if FileAccess.file_exists(GameManager.SAVE_FILE_PATH) else PackedByteArray()
	var score_after: PackedByteArray = FileAccess.get_file_as_bytes("user://vigil_record.json") if FileAccess.file_exists("user://vigil_record.json") else PackedByteArray()
	check(save_before == save_after and score_before == score_after and GameManager.inventory == inventory,"Preview, tests and handoff must preserve campaign, record file and inventory.")
	print("POSEIDON: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
