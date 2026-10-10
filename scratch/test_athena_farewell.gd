extends Node
## Run with Godot --path . res://scratch/test_athena_farewell.tscn.
## Add -- --capture to also save real renderer frames for visual inspection.

var failures: int = 0
var completed: bool = false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	await get_tree().process_frame
	var scene: Control = load("res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.tscn").instantiate()
	scene.autoplay = false
	scene.next_scene_path = ""
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.cinematic_finished.connect(func(): completed = true)
	await get_tree().create_timer(4.8).timeout
	check(scene.can_advance and scene.current_beat == 0, "A abertura deve chegar à primeira fala.")
	check(scene.beats.size() == 34, "Todas as 34 falas devem estar presentes.")
	check(not get_node("/root/MainHUD").visible, "O HUD de combate deve estar oculto na conversa.")
	check(scene.presence > 0.99, "Atena deve se manifestar completamente na abertura.")
	# Reveal, then advance; a held/double event must not skip a beat.
	scene._show_beat(14)
	scene.input_cooldown = 0.0
	scene._advance_requested()
	check(scene.current_beat == 14 and scene.dialogue.visible_characters == scene.dialogue.get_total_character_count(), "O primeiro comando deve revelar a fala sem pulá-la.")
	scene._advance_requested()
	check(scene.current_beat == 14, "O intervalo de entrada deve bloquear o duplo avanço.")
	scene.input_cooldown = 0.0
	scene._advance_requested()
	check(scene.current_beat == 15, "O próximo comando deve avançar uma fala.")
	# The longest captions must fit completely in the reserved area.
	for i in range(scene.beats.size()):
		scene._show_beat(i)
		scene.dialogue.visible_characters = -1
		await get_tree().process_frame
		check(scene.dialogue.get_content_height() <= int(scene.dialogue.size.y), "Legenda cortada na fala %d." % i)
	if "--capture" in OS.get_cmdline_user_args():
		await capture(scene, 4, "anger")
		await capture(scene, 15, "friendship")
		await capture(scene, 27, "loneliness")
		await capture(scene, 33, "farewell")
	# Resize to both widescreen and tall windows: artwork/UI share one scale.
	for viewport_size in [Vector2i(1280, 720), Vector2i(800, 900), Vector2i(640, 360)]:
		get_viewport().size = viewport_size
		await get_tree().process_frame
		scene._fit_stage()
		var bounds := Rect2(scene.stage.position, scene.DESIGN_SIZE * scene.stage.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1, "A cena deve ficar dentro da janela.")
		check(bounds.end.x <= viewport_size.x + 0.1 and bounds.end.y <= viewport_size.y + 0.1, "A cena deve manter todas as legendas visíveis ao redimensionar.")
	# Automatic progression and pause must preserve the reading clock.
	scene._show_beat(0)
	scene.autoplay = true
	scene.playback_speed = 3.0
	await get_tree().create_timer(1.8).timeout
	check(scene.current_beat > 0, "O modo automático deve avançar sozinho.")
	var paused_time: float = scene.type_elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.3, true).timeout
	check(scene.type_elapsed == paused_time, "A pausa deve congelar a cena e a leitura.")
	get_tree().paused = false
	# Exit after the final beat, with no lingering apparition.
	get_viewport().size = Vector2i(1152, 648)
	await get_tree().process_frame
	scene.autoplay = false
	scene._show_beat(33)
	scene._finish()
	await get_tree().create_timer(3.8).timeout
	check(scene.presence < 0.001, "Atena deve desaparecer completamente após seu adeus.")
	if "--capture" in OS.get_cmdline_user_args():
		await save_frame("absence")
	await get_tree().create_timer(3.6).timeout
	check(completed, "A cena deve emitir cinematic_finished ao terminar.")
	scene.queue_free()
	await get_tree().process_frame
	# Verify actual campaign routing, including the existing failure branch.
	var blinding: Control = load("res://Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.tscn").instantiate()
	get_tree().root.add_child(blinding)
	get_tree().current_scene = blinding
	blinding.active_slides = blinding.slides_part3_lose
	blinding._handle_slide_end()
	check(blinding.is_game_over and blinding.game_over_overlay.visible, "A derrota na caverna deve continuar levando ao game over.")
	blinding.active_slides = blinding.slides_part3_win
	blinding._handle_slide_end()
	await get_tree().process_frame
	await get_tree().process_frame
	var farewell: Node = get_tree().current_scene
	check(farewell.name == "Act3_AthenaFarewellCutscene", "A vitória na caverna deve levar ao novo confronto.")
	if farewell.name == "Act3_AthenaFarewellCutscene":
		farewell._finish()
		farewell.ending_tween.set_speed_scale(100.0)
		await get_tree().create_timer(0.3).timeout
		check(get_tree().current_scene.name == "Act3_EndingCard", "O adeus deve levar ao encerramento do Ato III.")
		check(not get_node("/root/MainHUD").visible, "O cartão de encerramento deve ocultar o HUD.")
	print("ATHENA_FAREWELL_TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func capture(scene: Control, index: int, file_name: String) -> void:
	scene._show_beat(index)
	scene.autoplay = false
	scene.presence = 1.0
	await get_tree().create_timer(1.3).timeout
	scene.type_elapsed = float(scene.dialogue.get_total_character_count()) / scene.characters_per_second + 1.0
	await get_tree().process_frame
	await save_frame(file_name)

func save_frame(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := "res://scratch/athena_farewell_preview"
	DirAccess.make_dir_recursive_absolute(dir)
	var frame: Image = get_viewport().get_texture().get_image()
	check(not frame.is_empty(), "O renderer deve produzir uma imagem de prévia.")
	if not frame.is_empty():
		frame.save_png(dir + "/" + file_name + ".png")
