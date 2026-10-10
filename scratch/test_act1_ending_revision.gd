extends Node
## Checks the new prophetic image and the manual choice -> silent release -> map.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	await get_tree().process_frame
	var original_unlock: int = GameManager.highest_unlocked_level
	# Exercise the ending without writing to the player's progress file.
	GameManager.highest_unlocked_level = maxi(original_unlock, 2)
	var save_existed: bool = FileAccess.file_exists(GameManager.SAVE_FILE_PATH)
	var saved_text := FileAccess.get_file_as_string(GameManager.SAVE_FILE_PATH) if save_existed else ""
	var scene: Control = load("res://Ato1_Troia/Cutscenes/Act1_EndingCutscene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	var cinema: Control = scene.cinematic
	cinema.autoplay = false
	cinema._update_auto_button()
	check(cinema.image_path.ends_with("odysseus_stabbed_vision.png"), "The vision must show Odysseus being stabbed.")
	check(not cinema.odysseus.get_parent().visible and not cinema.athena.get_parent().visible, "The vision tableau must not be covered by extra portraits.")
	check(not scene.choice_container.visible and not scene.release_started, "Release must wait for the manual decision.")
	await get_tree().create_timer(0.8).timeout
	await capture(cinema, "act1_stabbed_vision")
	scene.current_slide = 4
	scene._update_slide()
	for i in range(20):
		if not cinema.active:
			break
		cinema.input_cooldown = 0.0
		cinema.dialogue.visible_characters = cinema.dialogue.get_total_character_count()
		cinema._advance_requested()
	check(scene.choice_container.visible and cinema.image_path.ends_with("balcony.png"), "Before the choice, Odysseus still holds the infant.")
	scene.drop_button.pressed.emit()
	check(scene.release_started and cinema.image_path.ends_with("balcony_release.png"), "The button must display the empty hands image.")
	check(not cinema.active and not cinema.get_node("Stage/Captions").visible and not cinema.get_node("Stage/Controls").visible, "The release is silent and cannot be advanced by autoplay.")
	check(not cinema.get_node("Stage/BottomShade").visible and not cinema.get_node("Stage/TopTitle").visible, "The release composition must be unobstructed.")
	var release_tween: Tween = scene.ending_tween
	scene.drop_button.pressed.emit()
	check(scene.ending_tween == release_tween, "A repeated press must not restart the ending.")
	await get_tree().create_timer(1.0).timeout
	check(cinema.black.color.a == 0.0 and scene.end_title.modulate.a == 0.0, "The empty hands must remain visible before fading and titles.")
	await capture(cinema, "act1_after_release")
	var paused_at: float = release_tween.get_total_elapsed_time()
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	check(release_tween.get_total_elapsed_time() == paused_at, "Pause must freeze the release timing.")
	get_tree().paused = false
	await get_tree().create_timer(5.1).timeout
	check(cinema.black.color.a > 0.99 and scene.end_title.modulate.a > 0.0, "The release must fade to black before the act title.")
	release_tween.set_speed_scale(100.0)
	await get_tree().create_timer(0.4).timeout
	check(get_tree().current_scene.name == "WorldMap", "The ending must still return to the world map.")
	check(FileAccess.file_exists(GameManager.SAVE_FILE_PATH) == save_existed, "The test must not create a progress file.")
	if save_existed:
		check(FileAccess.get_file_as_string(GameManager.SAVE_FILE_PATH) == saved_text, "The test must preserve the player's saved progress.")
	GameManager.highest_unlocked_level = original_unlock
	print("ACT1 ENDING REVISION: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func capture(cinema: Control, name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	cinema.type_elapsed = 100.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/" + name + ".png")
