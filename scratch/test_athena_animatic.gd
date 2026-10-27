extends Node

const SCENE := preload("res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.tscn")
var checks: int = 0
var failures: int = 0
var capture: bool = false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func snapshot(scene: Control, index: int, file_name: String) -> void:
	if not capture:
		return
	scene.type_elapsed = float(scene.dialogue.get_total_character_count()) / scene.characters_per_second + 1.0
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://scratch/athena_animatic_preview"
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory + "/%02d_%s.png" % [index, file_name])
	get_tree().paused = false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	capture = "--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152, 648)
	var scene: Control = SCENE.instantiate()
	scene.autoplay = false
	scene.next_scene_path = ""
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(5.6).timeout
	check(scene.use_animatic and scene.animatic != null and not scene.world.visible, "The campaign scene must use the animatic by default.")
	check(scene.beats.size() == 34 and scene.animatic.SHOTS.size() == 34, "All 34 existing lines must have a staged shot.")
	check(scene.can_advance and scene.current_beat == 0, "The existing opening must reach the first shot.")
	var kinds: Dictionary = {}
	for index in scene.beats.size():
		scene._show_beat(index)
		await get_tree().process_frame
		var director: Node2D = scene.animatic
		kinds[director.current_shot] = true
		check(director.current_index == index and scene.dialogue.text == scene.beats[index].text, "Shot %d must follow the original dialogue exactly." % index)
		var regions_valid: bool = true
		for actor in [director.odysseus, director.athena]:
			if actor.visible:
				regions_valid = regions_valid and actor.texture != null and Rect2(Vector2.ZERO, actor.texture.get_size()).encloses(actor.region_rect)
		check(regions_valid, "Shot %d must select complete poses inside the original image." % index)
		if index == 0:
			var athena_height: float = director.athena.region_rect.size.y * director.athena.scale.y
			var odysseus_height: float = director.odysseus.region_rect.size.y * director.odysseus.scale.y
			check(athena_height > odysseus_height * 1.5, "The opening must give Athena the reference's imposing height.")
		if index in [0, 2, 4, 6, 8, 13, 15, 17, 21, 23, 27, 30, 32, 33]:
			await snapshot(scene, index, director.current_shot)
	check(kinds.size() >= 12, "The sequence must use distinct full, close, shoulder, confrontation and departure views.")
	check(scene.animatic.current_shot == "farewell", "The last existing line must end the shot sequence.")
	var before: float = scene.animatic.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	check(scene.animatic.elapsed == before, "Pause must also freeze the new character and camera motion.")
	get_tree().paused = false
	scene._finish()
	await get_tree().create_timer(3.8).timeout
	check(scene.presence < 0.001 and scene.animatic.ending, "Athena must depart and fully dissolve after the existing final line.")
	await snapshot(scene, 34, "absence")
	scene.queue_free()
	await get_tree().process_frame
	# The Inspector switch must actually restore the previous presentation.
	scene = SCENE.instantiate()
	scene.use_animatic = false
	scene.autoplay = false
	scene.next_scene_path = ""
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(4.8).timeout
	check(scene.animatic == null and scene.world.visible, "Disabling use_animatic must restore the previous cave and portrait scene.")
	check(scene.beats.size() == 34 and scene.can_advance, "The fallback must retain the same dialogue and working controls.")
	scene._show_beat(15)
	await snapshot(scene, 35, "previous_version")
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ATHENA ANIMATIC: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
