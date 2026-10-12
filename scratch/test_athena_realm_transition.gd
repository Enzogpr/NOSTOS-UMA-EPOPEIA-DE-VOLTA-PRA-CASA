extends Node

const SCENE := preload("res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.tscn")
var failures: int = 0
var checks: int = 0
var capture: bool = false
var completed: int = 0
var scene: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frame(label: String) -> void:
	if not capture:
		return
	get_tree().paused = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://scratch/athena_animatic_preview"
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory + "/realm_" + label + ".png")
	get_tree().paused = false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	capture = "--capture" in OS.get_cmdline_user_args()
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152, 648)
	scene = SCENE.instantiate()
	scene.autoplay = false
	scene.next_scene_path = ""
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.cinematic_finished.connect(func(): completed += 1)
	var director: Node2D = scene.animatic
	var portrait: Texture2D = director.odysseus.texture
	var region: Rect2 = director.odysseus.region_rect
	var scale_before: Vector2 = director.odysseus.scale
	await get_tree().create_timer(1.1).timeout
	check(director.realm < 0.001 and scene.presence < 0.001, "The opening must establish the real deck without Athena.")
	check(not scene.can_advance and scene.current_beat == -1, "No line may begin before Athena appears.")
	check(director.deck.visible and scene.sea_ambience.playing, "The real world must have its own visible deck and ambient sea.")
	scene._advance_requested()
	check(scene.current_beat == -1, "Input during the approach must not jump into the dialogue.")
	await frame("01_real")
	await get_tree().create_timer(1.3).timeout
	check(director.camera.scale.x > 2.9, "The camera must approach Odysseus before revealing the mind.")
	check(director.odysseus.texture == portrait and director.odysseus.region_rect == region and director.odysseus.scale == scale_before, "The eye transition must preserve the same pose instead of cutting to a different portrait.")
	await frame("02_eyes")
	await get_tree().create_timer(0.6).timeout
	check(director.realm > 0.1 and director.realm < 0.95, "The worlds must overlap during a continuous dissolve.")
	check(scene.presence < 0.001 and scene.sea_ambience.volume_db < -26.0, "The sea must recede before Athena manifests.")
	await frame("03_dissolve")
	var clock: float = director.transition_progress
	var transform_before: Transform2D = director.camera.transform
	var volume_before: float = scene.sea_ambience.volume_db
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	check(director.transition_progress == clock and director.camera.transform == transform_before and scene.sea_ambience.volume_db == volume_before, "Pause must freeze the dissolve, camera and audio envelope together.")
	get_tree().paused = false
	await get_tree().create_timer(0.8).timeout
	check(director.realm > 0.99 and scene.presence > 0.0 and scene.presence < 1.0, "Athena must form gradually after the deck dissolves.")
	await frame("04_apparition")
	await get_tree().create_timer(1.6).timeout
	check(scene.can_advance and scene.current_beat == 0 and scene.presence > 0.99, "The first original line must start only after the reveal is complete.")
	check(director.transition.is_empty() and director.camera.transform == Transform2D.IDENTITY, "The opening must settle into the existing shot compositions.")
	await frame("05_mind")
	scene._show_beat(33)
	scene.type_elapsed = 10.0
	await get_tree().create_timer(1.0).timeout
	scene._finish()
	scene._finish()
	await get_tree().create_timer(0.2).timeout
	check(director.realm > 0.999 and not director.deck.visible, "Ending a normal shot must preserve the mental world during Athena's departure.")
	await get_tree().create_timer(3.5).timeout
	check(scene.presence < 0.001 and director.transition == "return", "The return must begin only after Athena leaves.")
	check(completed == 0, "The ending must not change scenes in the middle of the return.")
	await frame("06_return_start")
	await get_tree().create_timer(1.3).timeout
	check(director.camera.scale.x > 2.9 and director.realm > 0.1 and director.realm < 0.99, "The exit must approach the same character while the deck gradually returns.")
	await frame("07_return_dissolve")
	await get_tree().create_timer(2.15).timeout
	check(director.realm < 0.001 and director.camera.transform == Transform2D.IDENTITY, "The ending must return fully to the real deck before fading out.")
	check(scene.sea_ambience.volume_db > -26.1 and scene.get_node("MindAmbience").volume_db < -34.9, "The real sound must recover as the mental drone recedes.")
	await frame("08_real_again")
	await get_tree().create_timer(2.0).timeout
	check(completed == 1, "Finishing twice must still emit cinematic_finished exactly once.")
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ATHENA REALM TRANSITION: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
