extends Node

const SCENE := preload("res://Ato4_Tempestade/Cutscenes/LuckRunsOut.tscn")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var completed: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func snapshot(label: String) -> void:
	if not capture:
		return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://scratch/luck_preview"
	DirAccess.make_dir_recursive_absolute(path)
	get_viewport().get_texture().get_image().save_png(path+"/"+label+".png")
	get_tree().paused = false

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	capture = "--capture" in OS.get_cmdline_user_args()
	var scene: Control = SCENE.instantiate()
	scene.standalone_ascent = false
	scene.autoplay = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.conversation_finished.connect(func(): completed += 1)
	await get_tree().create_timer(1.3).timeout
	check(scene.can_advance and scene.current_beat == 0, "The scene must reach the first supplied line.")
	check(scene.beats.size() == 33 and scene.beats[32].text == "Obrigado", "The supplied dialogue must end at Odysseus's final thanks.")
	scene.input_cooldown = 0.0
	scene._advance_requested()
	check(scene.current_beat == 0 and scene.dialogue.visible_characters == scene.dialogue.get_total_character_count(), "The first input must reveal the current line without skipping it.")
	scene._advance_requested()
	check(scene.current_beat == 0, "Repeated input must not skip the conversation.")
	var shots: Dictionary = {}
	for index in scene.beats.size():
		scene._show_beat(index)
		scene.type_elapsed = 10.0
		await get_tree().process_frame
		check(scene.dialogue.text == scene.beats[index].text and scene.dialogue.get_content_height() <= int(scene.dialogue.size.y), "Every word must remain visible on line %d." % index)
		shots[scene.director.current_shot] = true
		if index in [0,2,4,7,8,10,11,12,13,16,18,22,24,25,26,27,28,30,31,32]:
			await get_tree().create_timer(1.6 if index not in [24,25] else 3.2).timeout
			await snapshot("%02d_%s" % [index,scene.director.current_shot])
	check(shots.size() >= 18, "The conversation must have distinct rope, reaction, contact, crew, tracking and private compositions.")
	scene._show_beat(24)
	var before: Vector2 = scene.director.odysseus.position
	await get_tree().create_timer(0.5).timeout
	check(scene.director.odysseus.position.distance_to(before) > 2.0, "The characters must actually move across the deck during the private transition.")
	var clock: float = scene.director.elapsed
	var camera: Transform2D = scene.director.camera.transform
	get_tree().paused = true
	await get_tree().create_timer(0.2,true).timeout
	check(scene.director.elapsed == clock and scene.director.camera.transform == camera, "Pause must freeze actor, camera and atmospheric animation together.")
	get_tree().paused = false
	for dimensions in [Vector2i(800,1000),Vector2i(640,360)]:
		get_viewport().size = dimensions
		await get_tree().process_frame
		scene._fit_stage()
		var bounds := Rect2(scene.stage.position,scene.DESIGN_SIZE*scene.stage.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= dimensions.x+0.1 and bounds.end.y <= dimensions.y+0.1,"Resizing must keep every caption and control on screen.")
	get_viewport().size = Vector2i(1152,648)
	scene._show_beat(32)
	scene._finish()
	scene._finish()
	await get_tree().create_timer(2.6).timeout
	check(completed == 1 and scene.director.ending,"Finishing twice must emit only one completion and lead toward the rope.")
	scene.queue_free()
	await get_tree().process_frame
	print("LUCK DIALOGUE: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
