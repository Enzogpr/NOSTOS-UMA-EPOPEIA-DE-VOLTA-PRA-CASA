extends Node
## Regression: a handled advance may synchronously detach its cinematic scene.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func enter_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	return event

func _ready() -> void:
	await get_tree().process_frame
	var viewport: Viewport = get_viewport()
	var scene: Control = load("res://Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.tscn").instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	scene.active_slides = scene.slides_part3_win
	scene.current_slide = scene.active_slides.size() - 1
	scene._update_slide()
	var cinema: Control = scene.cinematic
	cinema.autoplay = false
	cinema.dialogue.visible_characters = cinema.dialogue.get_total_character_count()
	cinema.input_cooldown = 0.0
	var handled_before_transition := [false]
	cinema.advance_requested.connect(func(): handled_before_transition[0] = viewport.is_input_handled())
	# Real input dispatch resets the handled flag and exercises the entire tree.
	viewport.push_input(enter_event())
	check(handled_before_transition[0], "Input must be consumed before the advance callback changes the scene.")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene.name == "Act3_AthenaFarewellCutscene", "Enter on the last escape caption must reach Athena's farewell.")
	# The same ordering applies to the farewell's inherited input handler.
	var farewell: Control = get_tree().current_scene
	if farewell.intro_tween and farewell.intro_tween.is_running():
		farewell.intro_tween.kill()
	farewell.autoplay = false
	farewell.can_advance = true
	farewell._show_beat(0)
	farewell.input_cooldown = 0.0
	viewport.push_input(enter_event())
	check(farewell.current_beat == 0 and farewell.dialogue.visible_characters == farewell.dialogue.get_total_character_count(), "First Enter must reveal the farewell caption without skipping it.")
	farewell.input_cooldown = 0.0
	viewport.push_input(enter_event())
	check(farewell.current_beat == 1 and viewport.is_input_handled(), "Next Enter must advance the farewell caption and consume the input.")
	print("CINEMATIC INPUT TRANSITION: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
