extends Node
## Godot headless: full dialogue/resources/mechanics. -- --capture: real GL frames.
var failures := 0
var captions := 0
var snapshots := 0
const HOSTS := {
	"act1_intro": "res://Ato1_Troia/Cutscenes/Act1_IntroCutscene.tscn",
	"act1_invasion": "res://Ato1_Troia/Cutscenes/Act1_Cutscene_Invasao.tscn",
	"act1_palace": "res://Ato1_Troia/Cutscenes/Act1_Cutscene_Palacio.tscn",
	"act1_ending": "res://Ato1_Troia/Cutscenes/Act1_EndingCutscene.tscn",
	"act2_voyage": "res://Ato2_Lotofagos/Cutscenes/Act2_VoyageCutscene.tscn",
	"act2_landing": "res://Ato2_Lotofagos/Cutscenes/Act2_EndingCutscene.tscn",
	"cave_encounter": "res://Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.tscn",
	"blinding_1": "res://Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.tscn"
}

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	await get_tree().process_frame
	for key in HOSTS:
		var host: Control = load(HOSTS[key]).instantiate()
		get_tree().root.add_child(host)
		get_tree().current_scene = host
		var cinema: Control = host.cinematic
		cinema.autoplay = false
		check(cinema.get_script().resource_path == "res://Code/CinematicPresenter.gd", "Shared presenter must use its own script, not farewell UID.")
		await get_tree().process_frame
		var sequences := {key: get_slides(host)}
		if key == "cave_encounter":
			sequences["cave_resolution"] = host.resolution_slides
		if key == "blinding_1":
			sequences["blinding_1"] = host.slides_part1
			sequences["blinding_2"] = host.slides_part2
			sequences["blinding_win"] = host.slides_part3_win
			sequences["blinding_lose"] = host.slides_part3_lose
		for sequence in sequences:
			var slides: Array = sequences[sequence]
			check(slides.size() == cinema.library.sequences[sequence].beats.size(), "Missing direction beat: " + sequence)
			for i in slides.size():
				cinema.present(slides[i], sequence, i)
				check(cinema.resolve_texture(str(slides[i].get("image", ""))) != null, "Missing original image in " + sequence + str(i))
				check(cinema.get_node("Stage/World/Cave").texture != null, "Missing presented background")
				var rebuilt := ""
				for p in cinema.pages.size():
					cinema.page_index = p
					cinema._show_page()
					cinema.dialogue.visible_characters = -1
					await get_tree().process_frame
					captions += 1
					check(cinema.dialogue.get_content_height() <= int(cinema.dialogue.size.y), "Caption overflow: " + sequence + str(i) + str(p))
					rebuilt += " " + str(cinema.pages[p].text)
				var expected: String = str(slides[i].text)
				for prefix in ["Odisseu: ", "Euríloco: ", "Ancião dos Lotófagos: "]:
					expected = expected.replace(prefix, "")
				check(normalize(rebuilt) == normalize(expected), "Text lost during pagination in " + sequence + str(i))
				if "--capture" in OS.get_cmdline_user_args() and ((sequence == "act1_intro" and i == 3) or (sequence == "act1_ending" and i in [2,3,4]) or (sequence == "act2_voyage" and i in [0,2]) or (sequence == "cave_encounter" and i in [4,5]) or (sequence == "blinding_2" and i == 1) or (sequence == "blinding_win" and i == 5)):
					await capture(cinema, sequence + "_" + str(i))
		# Reading/reveal debounce never advances the owner's story prematurely.
		cinema.present(sequences[key][0], key, 0)
		cinema.input_cooldown = 0.0
		cinema._advance_requested()
		check(cinema.dialogue.visible_characters == cinema.dialogue.get_total_character_count(), "First click reveals the caption")
		cinema._advance_requested()
		check(cinema.page_index == 0, "Double click skips no page")
		if key == "act1_intro":
			var saved_size: Vector2i = get_viewport().size
			for window_size in [Vector2i(1280,720), Vector2i(800,900), Vector2i(640,360)]:
				get_viewport().size = window_size
				await get_tree().process_frame
				check(cinema.stage.position.x >= -0.1 and cinema.stage.position.y >= -0.1, "Cinematic stage fits resized viewport")
				check(cinema.stage.position + cinema.DESIGN_SIZE * cinema.stage.scale <= Vector2(window_size) + Vector2.ONE, "Cinematic artwork stays within viewport")
			get_viewport().size = saved_size
			await get_tree().process_frame
			var read_time: float = cinema.type_elapsed
			get_tree().paused = true
			await get_tree().create_timer(0.1, true).timeout
			check(cinema.type_elapsed == read_time, "Pause freezes shared presentation")
			get_tree().paused = false
			var owner_callback := Callable(host, "_on_cinematic_advance")
			cinema.advance_requested.disconnect(owner_callback)
			var automatic_requests := [0]
			var counter := func(): automatic_requests[0] += 1
			cinema.advance_requested.connect(counter)
			cinema.present({"text": "Teste de ritmo", "image": "res://Assets/cutscene_1.png"}, key, 0)
			cinema.playback_speed = 100.0
			cinema.autoplay = true
			await get_tree().create_timer(0.4).timeout
			check(automatic_requests[0] == 1, "Automatic playback requests the next story beat once")
			cinema.advance_requested.disconnect(counter)
			cinema.advance_requested.connect(owner_callback)
			cinema.autoplay = false
			cinema.playback_speed = 1.0
		if key == "act1_ending":
			host.current_slide = 4
			host._update_slide()
			check(not host.choice_container.visible, "Choice waits until the final narration is read")
			finish_pages(cinema)
			check(host.choice_container.visible and not cinema.active, "Automatic narration stops at the manual decision")
			if "--capture" in OS.get_cmdline_user_args():
				await capture(cinema, "act1_choice")
		if key == "cave_encounter":
			host.current_slide = 9
			host._update_slide()
			finish_pages(cinema)
			check(host.is_interactive_mode and host.panic_hud.visible and not cinema.active, "Survival preserves timer and controls")
			dismiss_tutorials(host)
			host._combine_lotus_and_wine()
			host._on_offer_wine_pressed()
			check(host.is_resolved and cinema.active and not host.panic_hud.visible, "Crafted wine resumes dialogue")
			host.resolution_index = 4
			host._show_resolution_slide()
			finish_pages(cinema)
			check(host.is_waiting_for_name and host.name_input_panel.visible and not cinema.active, "Name entry stops autoplay")
			host.name_line_edit.text = "Ninguém"
			host._on_confirm_name_pressed()
			check(not host.is_waiting_for_name and cinema.active and "Ninguém" in cinema.caption_text, "Chosen name appears without losing narration")
		if key == "blinding_1":
			host.active_slides = host.slides_part1
			host.current_slide = 3
			host._update_slide()
			finish_pages(cinema)
			check(host.in_minigame and host.minigame_panel.visible and not cinema.active, "Sharpening requires player input")
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(2100, 0)
			host._on_hit_area_gui_input(motion)
			check(not host.in_minigame and cinema.sequence_key == "blinding_2", "Sharpening completion resumes attack")
			GameManager.player_fake_name = "Ninguém"
			host._check_branch()
			check(cinema.sequence_key == "blinding_win", "Nobody name retains escape branch")
			GameManager.player_fake_name = "Outro"
			host._check_branch()
			check(cinema.sequence_key == "blinding_lose", "Other name retains failure branch")
			host.current_slide = 1
			host._update_slide()
			finish_pages(cinema)
			check(host.is_game_over and host.game_over_overlay.visible, "Failure still reaches game over")
		host.free()
		await get_tree().process_frame
	await test_lotus()
	await test_cards()
	print("CAMPAIGN CINEMATICS: ", captions, " captions; ", snapshots, " real-render captures; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func get_slides(host: Control) -> Array:
	if host.get("texts") != null:
		var slides := []
		for i in host.texts.size():
			slides.append({"text": host.texts[i], "image": host.images[i]})
		return slides
	if host.get("slides") != null:
		return host.slides
	return host.slides_part1

func normalize(text: String) -> String:
	return " ".join(text.replace("\n", " ").split(" ", false)).strip_edges()

func finish_pages(cinema: Control) -> void:
	for i in range(100):
		if not cinema.active:
			break
		var old_index: int = cinema.sequence_index
		cinema.dialogue.visible_characters = cinema.dialogue.get_total_character_count()
		cinema.input_cooldown = 0
		cinema._advance_requested()
		if cinema.sequence_index != old_index:
			break

func capture(cinema: Control, filename: String) -> void:
	cinema.autoplay = false
	cinema._update_auto_button()
	if not cinema.pages.is_empty():
		cinema.page_index = 0
		cinema._show_page()
	await get_tree().create_timer(1.6).timeout
	cinema.type_elapsed = 100.0
	cinema.dialogue.visible_characters = -1
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://scratch/campaign_review/previews")
	get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/" + filename + ".png")
	snapshots += 1

func test_lotus() -> void:
	var host: Control = load("res://Ato2_Lotofagos/Fase1_IlhaDosLotofagos.tscn").instantiate()
	get_tree().root.add_child(host)
	get_tree().current_scene = host
	dismiss_tutorials(host)
	host.cinematic.autoplay = false
	check(not host.cinematic.visible, "Lotus exploration starts without cinematic cover")
	for idx in [1, 2]:
		host._show_crew_dialogue(idx)
		var remaining: float = host.time_left
		await get_tree().process_frame
		check(host.time_left == remaining, "Crew conversation pauses exploration clock")
		check(host.cinematic.visible and host.cinematic.active, "Crew uses shared animated presentation")
		if "--capture" in OS.get_cmdline_user_args():
			# Hide unrelated opening tutorial in diagnostic captures.
			for child in host.get_children():
				if child.name.begins_with("Tutorial"):
					child.queue_free()
			await capture(host.cinematic, "lotus_crew_" + str(idx))
		finish_pages(host.cinematic)
		check(not host.is_dialogue_open and not host.cinematic.visible, "Crew dialogue returns to exploration")
	host._trigger_last_encounter_cutscene()
	for i in host.cutscene_slides.size():
		host.cutscene_slide = i
		host._update_cutscene_slide()
		for p in host.cinematic.pages.size():
			host.cinematic.page_index = p
			host.cinematic._show_page()
			host.cinematic.dialogue.visible_characters = -1
			await get_tree().process_frame
			check(host.cinematic.dialogue.get_content_height() <= int(host.cinematic.dialogue.size.y), "Lotus dialogue fits")
		if "--capture" in OS.get_cmdline_user_args() and i in [2, 4]:
			await capture(host.cinematic, "lotus_elder_" + str(i))
	finish_pages(host.cinematic)
	await get_tree().create_timer(0.7).timeout
	check(host.has_lotus_flower and not host.is_cutscene_open and not host.cinematic.visible, "Lotus encounter awards inventory and returns control")
	dismiss_tutorials(host)
	host.free()
	await get_tree().process_frame

func test_cards() -> void:
	for path in ["res://Ato1_Troia/Cutscenes/Act1_TitleCard.tscn", "res://Ato2_Lotofagos/Cutscenes/Act2_TitleCard.tscn", "res://Ato3_Ciclope/Cutscenes/Act3_TitleCard.tscn", "res://Ato3_Ciclope/Cutscenes/Act3_EndingCard.tscn"]:
		var card: Node = load(path).instantiate()
		get_tree().root.add_child(card)
		get_tree().current_scene = card
		check(card.has_node("CinematicBackdrop"), "Act card receives scenic background")
		await get_tree().process_frame
		check(not get_node("/root/MainHUD").visible, "Act cards hide gameplay HUD")
		if "--capture" in OS.get_cmdline_user_args():
			await get_tree().create_timer(6.0 if "Act1_" in path or "EndingCard" in path else 3.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/" + card.name + ".png")
			snapshots += 1
		card.free()

func dismiss_tutorials(host: Node) -> void:
	for child in host.get_children():
		if child.get_script() and child.get_script().resource_path == "res://Code/TutorialOverlay.gd":
			child.free()
	get_tree().paused = false
