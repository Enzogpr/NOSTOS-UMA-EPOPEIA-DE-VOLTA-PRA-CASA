extends Node
## Healthy expressions and the immediate injured state have separate resources.
var failures := 0
var checked := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	await get_tree().process_frame
	var owner := Control.new()
	owner.name = "CutscenePolyphemusContinuity"
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(owner)
	get_tree().current_scene = owner
	var stage: Control = load("res://Scenes/CinematicPresenter.tscn").instantiate()
	owner.add_child(stage)
	stage.autoplay = false
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scratch/campaign_review/original_story.json"))
	var sequence_sources := {
		"cave_encounter": "Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.gd:slides",
		"cave_resolution": "Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.gd:resolution_slides",
		"blinding_1": "Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part1",
		"blinding_2": "Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part2",
		"blinding_win": "Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part3_win",
		"blinding_lose": "Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part3_lose"
	}
	for actor_key in stage.library.actors:
		check(not str(stage.library.actors[actor_key].texture).ends_with("/polyphemus.png"), "The inconsistent blindfold atlas must not be referenced by any active actor.")
	for sequence in sequence_sources:
		var slides: Array = original.arrays[sequence_sources[sequence]]
		for i in slides.size():
			stage.present(slides[i], sequence, i)
			checked += 1
			var right_key: String = str(stage.current_direction.get("right", ""))
			var before_blinding: bool = sequence in ["cave_encounter", "cave_resolution", "blinding_1"] or (sequence == "blinding_2" and i <= 1)
			if before_blinding:
				check(not right_key.ends_with("_blinded"), "Injured Polyphemus appeared before the stake in " + sequence + str(i))
			if right_key.begins_with("polyphemus"):
				var portrait: Sprite2D = stage.athena.get_node("Portrait")
				var actor: Dictionary = stage.library.actors[right_key]
				check(not portrait.flip_h, "Polyphemus must face Odysseus, matching the reference portraits.")
				check(stage.athena.get_parent().position.y == -44.0, "Both states must retain giant staging.")
				if before_blinding:
					check(not actor.injured and portrait.texture.resource_path.ends_with("polyphemus_uninjured.png"), "All early expressions must use the intact-eye atlas.")
				else:
					check(actor.injured and portrait.texture.resource_path.ends_with("polyphemus_blinded.png"), "Post-stake dialogue must show the same injured giant without a blindfold.")
			if "--capture" in OS.get_cmdline_user_args() and ((sequence == "cave_encounter" and i in [4,5]) or (sequence == "cave_resolution" and i == 4) or (sequence == "blinding_2" and i == 4)):
				stage.page_index = 0
				stage._show_page()
				await get_tree().create_timer(1.1).timeout
				stage.type_elapsed = 100.0
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/polyphemus_" + sequence + "_" + str(i) + ".png")
	print("POLYPHEMUS CONTINUITY: ", checked, " beats; ", failures, " failures")
	owner.free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
