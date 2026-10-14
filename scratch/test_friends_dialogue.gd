extends Node
const SCENE := preload("res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var completed: int = 0
var bag_rewards: int = 0
var portraits_only: bool = false

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
	get_viewport().get_texture().get_image().save_png("res://scratch/friends_preview/"+label+".png")
	get_tree().paused = false

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	capture = "--capture" in OS.get_cmdline_user_args()
	portraits_only = "--portraits-only" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://scratch/friends_preview")
	var inventory: Array = GameManager.inventory.duplicate(true)
	var scene: Control = SCENE.instantiate()
	scene.autoplay = false
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.conversation_finished.connect(func(): completed += 1)
	scene.wind_bag_received.connect(func(): bag_rewards += 1)
	await get_tree().create_timer(1.3).timeout
	check(scene.can_advance and scene.current_beat == 0,"The encounter must begin after arrival.")
	check(scene.beats.size() == 34 and scene.beats[-1].text == "Tentaremos","The supplied conversation must stop exactly at the crew's assent.")
	scene.input_cooldown = 0
	scene._advance_requested()
	check(scene.current_beat == 0 and scene.dialogue.visible_characters == scene.dialogue.get_total_character_count(),"First input reveals the line.")
	scene._advance_requested()
	check(scene.current_beat == 0,"Repeated input cannot skip lines.")
	var shots: Dictionary = {}
	for index in scene.beats.size():
		scene._show_beat(index)
		scene.type_elapsed = 20
		await get_tree().process_frame
		check(scene.dialogue.text == scene.beats[index].text and scene.dialogue.get_content_height() <= int(scene.dialogue.size.y),"Caption must fit for beat %d." % index)
		shots[scene.director.current_shot] = true
		if index == 11:
			check(scene.director.bag_owner == "transferring","The wind bag must travel from Aeolus to Odysseus.")
			await get_tree().create_timer(1.5).timeout
			check(scene.director.bag_owner == "odysseus" and not scene.director.bag.visible,"The handoff must finish with one carried bag.")
		if index == 20:
			check(scene.director.transitioning and scene.director.phase == "palace","The return must start with a cloud transition.")
			scene.input_cooldown = 0
			scene._advance_requested()
			check(scene.current_beat == 20,"Input must wait for the scene change.")
			await get_tree().create_timer(2.4).timeout
			check(scene.director.phase == "ship" and not scene.director.transitioning,"The cloud transition must end on the deck.")
		var selected: Array = [0,7,12,21,28,33] if portraits_only else [0,4,5,7,9,10,11,12,14,15,17,19,20,21,22,23,25,26,27,28,29,30,31,33]
		if index in selected:
			await get_tree().create_timer(1.6 if index != 25 else 2.8).timeout
			await snapshot("%02d_%s" % [index,scene.director.current_shot])
	check(shots.size() >= 25,"The encounter needs distinct reactions, transfer, closeups and crew shots.")
	check(scene.director.bag_sealed and scene.director.bag_owner == "odysseus","The bag must stay sealed after the crew's assent.")
	scene._show_beat(14)
	await get_tree().create_timer(0.8).timeout
	var spirit_before: Vector2 = scene.director.winions[0].position
	await get_tree().create_timer(0.3).timeout
	check(spirit_before.distance_to(scene.director.winions[0].position) > 2,"Winions must move independently.")
	var clock: float = scene.director.elapsed
	var camera: Transform2D = scene.director.camera.transform
	get_tree().paused = true
	await get_tree().create_timer(0.2,true).timeout
	check(scene.director.elapsed == clock and scene.director.camera.transform == camera,"Pause must freeze all animation.")
	get_tree().paused = false
	for dimensions in [Vector2i(800,1000),Vector2i(640,360)]:
		get_viewport().size = dimensions
		await get_tree().process_frame
		scene._fit_stage()
		var bounds := Rect2(scene.stage.position,scene.DESIGN_SIZE*scene.stage.scale)
		check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= dimensions.x+0.1 and bounds.end.y <= dimensions.y+0.1,"The entire stage must remain visible after resizing.")
	get_viewport().size = Vector2i(1152,648)
	scene._show_beat(33)
	await get_tree().create_timer(2.4).timeout
	scene._finish()
	scene._finish()
	await get_tree().create_timer(2.3).timeout
	check(completed == 1 and bag_rewards == 1 and scene.ended and scene.end_panel.visible,"The encounter must finish once with replay and map controls.")
	check(GameManager.inventory == inventory,"Previewing this scene must preserve the existing campaign inventory.")
	await snapshot("34_journey")
	scene.queue_free()
	await get_tree().process_frame
	print("FRIENDS DIALOGUE: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures == 0 else 1)
