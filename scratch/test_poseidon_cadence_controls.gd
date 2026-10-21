extends Node
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
var checks := 0
var failures := 0
var scene: Control

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(450,300)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func step(seconds: float = 1.0/60.0) -> void:
	scene._physics_process(seconds)

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	get_viewport().size = Vector2i(1152,648)
	scene = preload("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.audio_enabled = false
	scene.persist_record = false
	scene.manual_score_clock = true
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	scene.set_physics_process(false)
	scene.score.set_process(false)
	scene.visuals.set_process(false)
	scene.ready_delay = 0
	scene.begin()
	scene.model.obstacles.clear()
	scene.model.next_attack_score = 100000.0
	scene.model.fleet_next_score = 100000.0
	check(absf(scene.model.dash_cooldown_seconds-maxf(0.5,GameManager.player_dash_cooldown)) < 0.001,"Controller imports the saved character's dash cooldown")
	check(scene.controls_hint.text.contains("SHIFT") and scene.controls_hint.text.contains("Q / BOTÃO DIREITO") and not scene.controls_hint.text.contains("K ·"),"Control hints advertise Shift guard and both dash bindings")
	check(scene.dash_label.text.contains("DASH PRONTO"),"HUD presents dash ready before first use")
	key(KEY_Q,true)
	await get_tree().process_frame
	check(scene.dash_requested,"Real Q input reaches the controller's dash edge handler")
	step()
	key(KEY_Q,false)
	check(scene.model.dashes == 1 and scene.model.dash_time > 0,"Q starts dash through controller physics")
	check(scene.dash_label.text.contains("DASH ATIVO"),"HUD presents active dash during motion")
	step(0.25)
	check(scene.dash_label.text.contains("s") and not scene.dash_label.text.contains("DASH PRONTO"),"HUD presents cooldown after dash motion ends")
	scene.model.dash_cooldown_remaining = 0.0
	mouse(MOUSE_BUTTON_RIGHT,true)
	await get_tree().process_frame
	check(scene.dash_requested,"Right mouse input reaches the controller's dash edge handler")
	step()
	mouse(MOUSE_BUTTON_RIGHT,false)
	check(scene.model.dashes == 2,"Right mouse starts the same dash as Q")
	step(0.25)
	scene.model.position = Vector2(scene.model.final_origin+120.0,scene.model.boats[10].rect.position.y)
	scene.model.velocity = Vector2.ZERO
	scene.model.grounded = true
	scene.model._enter_boat(10)
	scene.model.next_attack_score = 100000.0
	for i in scene.model.platforms.size():
		if scene.model.platforms[i].boat == 10:
			scene.model.support = i
			break
	key(KEY_SHIFT,true)
	await get_tree().process_frame
	check(scene._pressed(KEY_SHIFT),"Real held Shift is visible to polling")
	step()
	check(scene.model.boarding.player_guarding,"Held Shift defends on the final deck")
	key(KEY_SHIFT,false)
	key(KEY_K,true)
	await get_tree().process_frame
	step()
	check(not scene.model.boarding.player_guarding,"The removed K binding no longer guards")
	key(KEY_K,false)
	scene.allow_input = false
	scene.model.dash_cooldown_remaining = 0.0
	key(KEY_SHIFT,true)
	key(KEY_Q,true)
	mouse(MOUSE_BUTTON_RIGHT,true)
	await get_tree().process_frame
	step()
	check(not scene.model.boarding.player_guarding and scene.model.dashes == 2,"Disabled input rejects held guard and both dash edges")
	key(KEY_SHIFT,false)
	key(KEY_Q,false)
	mouse(MOUSE_BUTTON_RIGHT,false)
	scene.allow_input = true
	scene._update_interface()
	check(scene.controls_hint.get_combined_minimum_size().x <= scene.controls_hint.size.x+0.01 and scene.controls_hint.get_combined_minimum_size().y <= scene.controls_hint.size.y+0.01,"Two-line controls fit their HUD rectangle")
	check(scene.dash_label.get_combined_minimum_size().x <= scene.dash_label.size.x+0.01 and scene.dash_label.get_combined_minimum_size().y <= scene.dash_label.size.y+0.01,"Two-line dash status fits its HUD rectangle")
	if "--capture" in OS.get_cmdline_user_args():
		scene.model.position = Vector2(scene.model.final_origin+640.0,scene.model.boats[10].rect.position.y)
		scene.model.velocity = Vector2.ZERO
		scene.model.boarding.enemies[0].position.x = scene.model.final_origin+780.0
		scene.model.boarding.enemies[0].hp = 2
		scene.model.boarding.enemies[1].position.x = scene.model.final_origin+1010.0
		scene.model.boarding.enemies[1].hp = 1
		for enemy in scene.model.boarding.enemies:
			enemy.state = "approach"
			enemy.age = 0.4
		scene.model.dash_cooldown_remaining = 2.1
		scene._update_interface()
		scene.visuals.update_visuals(0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture_path := OS.get_environment("TEMP").path_join("poseidon_controls_dash_hud.png")
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("CONTROLS_CAPTURE ",capture_path)
	scene.stop_audio()
	scene.queue_free()
	await get_tree().process_frame
	print("CADENCE_CONTROLS ",checks," CHECKS ",failures," FAILURES")
	get_tree().quit(0 if failures == 0 else 1)
