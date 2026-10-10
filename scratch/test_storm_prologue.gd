extends Node
## Tests the silence/reveal boundary, exact dialogue, pause and future handoff.

const SCENE := "res://Ato4_Tempestade/Cutscenes/Act4_StormCutscene.tscn"
const EXPECTED := [
	"Essas ondas e marés", "Cresceram em força e tamanho", "É natureza ou divino",
	"Ou uma bênção disfarçada?", "Nossa casa está à vista", "Esta tempestade é nossa luta final",
	"Não há tempo para morrer", "Camaradas!", "Senhor!", "Prepare-se para uma tempestade",
	"Como nunca vimos antes", "Com a casa tão perto, precisamos continuar avançando",
	"Vá em direção à ilha, mas evite as ondas quebrando", "Pise onde a maré está calma e então você será salvo",
	"Capitão, vamos virar com essas ondas, nossa frota vai falhar",
	"Faça-os seguir meu navio, eu garantirei que prevaleceremos"
]
var failures := 0
var captures := 0
var reveal_count := 0
var handoff_count := 0
var capture: bool = false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func enter_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event

func check_portrait(actor: Node2D, key: String) -> void:
	var sprite: Sprite2D = actor.get_node("Portrait")
	check(sprite.texture is AtlasTexture, key + ": render only the upper body.")
	if sprite.texture is AtlasTexture:
		var pose := sprite.texture as AtlasTexture
		check(pose.region.size.y < pose.atlas.get_height() / 3.0, key + ": legs must stay outside the portrait frame.")
		var expected: String = "odysseus_fullbody.png" if key == "odysseus_storm" else "eurylochus_fullbody.png"
		check(pose.atlas.resource_path.ends_with(expected), key + ": keep the new expression artwork.")

func save_frame(name: String) -> void:
	if not capture:
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	frame.save_png("res://scratch/campaign_review/previews/" + name + ".png")
	captures += 1
	if name == "storm_black":
		check(frame.get_pixel(frame.get_width() / 2, frame.get_height() / 5).r < 0.01, "The black opening must have a truly black background.")

func pause_check(scene: Control, label: String) -> void:
	var cinema: Control = scene.cinematic
	var clock: float = scene.storm_time
	var rain_clock: float = scene.rain.age
	var caption_clock: float = cinema.type_elapsed
	var sound_clock: float = scene.storm_audio.get_playback_position()
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	check(is_equal_approx(scene.storm_time, clock), label + ": storm motion must pause.")
	check(is_equal_approx(scene.rain.age, rain_clock), label + ": rain must pause.")
	check(is_equal_approx(cinema.type_elapsed, caption_clock), label + ": captions must pause.")
	check(absf(scene.storm_audio.get_playback_position() - sound_clock) < 0.08, label + ": storm sound must pause.")
	get_tree().paused = false
	await get_tree().process_frame

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	var music_volume: float = AudioManager.music_player.volume_db
	var music_stream: AudioStream = AudioManager.music_player.stream
	var music_was_playing: bool = AudioManager.music_player.playing
	AudioManager.music_player.volume_db = -6.0
	AudioManager.play_music(load("res://Assets/act4_storm/thunder.wav"))
	var scene: Control = load(SCENE).instantiate()
	check(scene.ship_scene_path == "res://Ato4_Tempestade/Gameplay/StormLevel.tscn", "Prologue must be connected to the playable crossing.")
	scene.ship_scene_path = "" # Isolate caption and audio checks from the next scene.
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var cinema: Control = scene.cinematic
	cinema.autoplay = false
	cinema._update_auto_button()
	scene.storm_revealed.connect(func(): reveal_count += 1)
	scene.ship_control_requested.connect(func(): handoff_count += 1)
	check(scene.beats.size() == EXPECTED.size(), "All 16 requested lines must be present.")
	check(AudioManager.music_player.volume_db <= -80.0, "Music must be silent during the black opening.")
	check(not scene.storm_audio.playing and not scene.thunder_audio.playing, "Storm sounds must wait for the reveal.")
	check(not cinema.get_node("MindAmbience").playing, "Athena's mind ambience must not play.")
	await pause_check(scene, "Opening")
	# First real Enter completes a caption; it must never skip the first verse.
	cinema.input_cooldown = 0.0
	get_viewport().push_input(enter_event())
	check(scene.beat_index == 0 and cinema.dialogue.visible_characters == cinema.dialogue.get_total_character_count(), "First Enter must reveal, not skip, the opening verse.")
	for index in range(EXPECTED.size()):
		check(scene.beat_index == index, "Dialogue must advance in the requested order.")
		check(str(scene.beats[index].text) == EXPECTED[index], "Requested dialogue must remain verbatim.")
		var rendered: Array[String] = []
		for page in cinema.pages:
			rendered.append(str(page.text))
		check(" ".join(rendered) == EXPECTED[index], "Caption pagination must preserve every word.")
		check(cinema.dialogue.get_content_height() <= cinema.dialogue.size.y + 3.0, "Caption must fit the available height.")
		if index < 9:
			check(not cinema.get_node("Stage/World").visible, "No image may appear before 'Prepare-se'.")
			check(not scene.storm_audio.playing and not scene.thunder_audio.playing, "No storm may be heard before 'Prepare-se'.")
			check(not scene.rain.visible, "No rain may appear on the black background.")
		else:
			check(cinema.get_node("Stage/World").visible and scene.rain.visible, "The revealed storm must stay visible during dialogue.")
			check(scene.storm_audio.playing, "Wind/waves must continue throughout the storm dialogue.")
		if index == 9:
			check(reveal_count == 1 and scene.thunder_audio.playing, "Exactly one hard reveal must start both picture and thunder.")
			check(cinema.get_node("Stage/World/Cave").modulate.a == 1.0, "Reveal must be an immediate cut, not a crossfade.")
			check(scene.storm_audio.bus == "SFX" and scene.thunder_audio.bus == "SFX", "Storm effects must obey the existing SFX settings.")
			await pause_check(scene, "Storm")
		if index > 9:
			check(cinema.current_direction.left == "odysseus_storm", "Storm must keep the new confident Odysseus.")
			check_portrait(cinema.odysseus, "odysseus_storm")
		if index >= 14:
			check(cinema.current_direction.right == "eurylochus_storm", "Storm must keep the new Eurylocus expressions.")
			check_portrait(cinema.athena, "eurylochus_storm")
		if index == 14:
			check(cinema.current_direction.left_pose == 0, "Odysseus must listen with calm confidence, not near tears.")
		if index == 15:
			check(cinema.current_direction.left_pose == 3 and cinema.current_direction.right_pose == 3, "Final order must show reassurance and a crewman gathering courage.")
		if index in [0, 8, 9, 14, 15]:
			cinema.dialogue.visible_characters = -1
			cinema.type_elapsed = 1000.0
			await get_tree().create_timer(0.65).timeout
			await save_frame("storm_black" if index == 0 else "storm_crew_black" if index == 8 else "storm_reveal" if index == 9 else "storm_eurylochus" if index == 14 else "storm_final_order")
		for _page in range(cinema.pages.size()):
			cinema.dialogue.visible_characters = cinema.dialogue.get_total_character_count()
			cinema.input_cooldown = 0.0
			get_viewport().push_input(enter_event())
	await get_tree().create_timer(1.3).timeout
	check(handoff_count == 1, "The ship handoff must occur once, after the final order.")
	check(not cinema.active and scene.storm_audio.playing, "Captions must finish while the storm remains alive at the gameplay boundary.")
	check(not cinema.get_node("Stage/Controls").visible, "Dialogue controls must disappear at the handoff.")
	scene._begin_handoff()
	check(handoff_count == 1, "Repeated input must not request ship control twice.")
	await save_frame("storm_handoff")
	# Real resize keeps the stage within the viewport, including portrait shapes.
	get_viewport().size = Vector2i(800, 1000)
	await get_tree().process_frame
	await get_tree().process_frame
	check(cinema.stage.position.x >= -1 and cinema.stage.position.y >= -1, "Stage must letterbox inside a portrait viewport.")
	get_viewport().size = Vector2i(1152, 648)
	scene.free()
	await get_tree().process_frame
	check(is_equal_approx(AudioManager.music_player.volume_db, -6.0), "Leaving the scene must restore the previous music volume.")
	# The complete automatic path must also reveal once and reach the handoff.
	var automatic: Control = load(SCENE).instantiate()
	automatic.ship_scene_path = ""
	get_tree().root.add_child(automatic)
	get_tree().current_scene = automatic
	var automatic_reveals := [0]
	var automatic_handoffs := [0]
	automatic.storm_revealed.connect(func(): automatic_reveals[0] += 1)
	automatic.ship_control_requested.connect(func(): automatic_handoffs[0] += 1)
	automatic.cinematic.playback_speed = 100.0
	var deadline: int = Time.get_ticks_msec() + 10000
	while not automatic.handoff_started and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(1.3).timeout
	check(automatic.beat_index == 15 and automatic_reveals[0] == 1 and automatic_handoffs[0] == 1, "Autoplay must read all lines, reveal exactly once and reach ship handoff.")
	automatic.free()
	await get_tree().process_frame
	# The actual act-three ending card must route directly into this prologue.
	var ending: CanvasLayer = load("res://Ato3_Ciclope/Cutscenes/Act3_EndingCard.tscn").instantiate()
	get_tree().root.add_child(ending)
	get_tree().current_scene = ending
	ending.can_continue = true
	get_viewport().push_input(enter_event())
	await get_tree().create_timer(1.3).timeout
	check(get_tree().current_scene.name == "Act4_StormCutscene", "Act three must lead into the storm instead of the world map.")
	get_tree().current_scene.free()
	await get_tree().process_frame
	AudioManager.music_player.volume_db = music_volume
	AudioManager.music_player.stream = music_stream
	if music_was_playing:
		AudioManager.music_player.play()
	else:
		AudioManager.music_player.stop()
	print("STORM PROLOGUE: 16 lines; ", captures, " captures; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
