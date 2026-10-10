extends Node
## Real helm motion and physical wave contacts, without modifying saved progress.

const SHIP := preload("res://Ato4_Tempestade/Gameplay/StormShip.tscn")
const WAVE := preload("res://Ato4_Tempestade/Gameplay/StormWave.tscn")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame

func sail_controls() -> void:
	var ship := SHIP.instantiate()
	add_child(ship)
	ship.sailing = true
	ship.calm = true
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	var capture: bool = "--capture" in OS.get_cmdline_user_args()
	if capture:
		ship.scripted_helm = true
		ship.brace_command = true
	await frames(7)
	check(ship.braced and ship.sail_reef_amount > 0 and ship.sail_reef_amount < 1, "Holding Space must begin a visible, gradual sail transition.")
	var before_pause: float = ship.sail_reef_amount
	get_tree().paused = true
	await get_tree().create_timer(0.15, true).timeout
	check(ship.sail_reef_amount == before_pause, "Pause must freeze the sail transition.")
	get_tree().paused = false
	await frames(24)
	check(is_equal_approx(ship.sail_reef_amount, 1) and is_equal_approx(ship.sprite.material.get_shader_parameter("reef_amount"), 1), "Holding Space must display the fully furled sail artwork.")
	event.pressed = false
	Input.parse_input_event(event)
	ship.brace_command = false
	await frames(24)
	check(not ship.braced and is_zero_approx(ship.sail_reef_amount), "Releasing Space must visibly restore the deployed sails.")
	if capture:
		get_viewport().size = Vector2i(1152, 648)
		var backdrop := ColorRect.new()
		backdrop.position = Vector2.ZERO
		backdrop.size = Vector2(1152, 648)
		backdrop.color = Color(0.025, 0.08, 0.13)
		backdrop.z_index = -10
		add_child(backdrop)
		move_child(backdrop, 0)
		ship.position = Vector2(300, 340)
		ship.scale = Vector2.ONE * 2.6
		var furled := SHIP.instantiate()
		add_child(furled)
		furled.position = Vector2(850, 340)
		furled.scale = ship.scale
		furled.sailing = true
		furled.calm = true
		furled.scripted_helm = true
		furled.brace_command = true
		await frames(30)
		check(is_zero_approx(ship.sail_reef_amount) and is_equal_approx(furled.sail_reef_amount, 1), "Sail materials must be independent for each ship instance.")
		ship.sailing = false
		furled.sailing = false
		ship.queue_redraw()
		furled.queue_redraw()
		for item in [["VELAS ABERTAS", 150], ["ESPAÇO: VELAS RECOLHIDAS", 650]]:
			var label := Label.new()
			label.text = item[0]
			label.position = Vector2(item[1], 140)
			label.add_theme_font_size_override("font_size", 23)
			add_child(label)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/previews/storm_sail_states.png")
		furled.free()
	ship.free()

func _ready() -> void:
	set_meta("hide_main_hud", true)
	await get_tree().process_frame
	MainHUD.hide()
	for braced in [false, true]:
		for huge in [false, true]:
			var ship := SHIP.instantiate()
			add_child(ship)
			ship.position = Vector2(500, 400)
			ship.sailing = true
			ship.scripted_helm = true
			ship.helm = Vector2(0, 1)
			ship.brace_command = braced
			ship.weather_damage = 0
			ship.speed = ship.max_speed * (0.55 if braced else 1.0)
			ship.wind = Vector2(192, 0)
			ship.drift = ship.wind * (0.55 if braced else 1.0)
			await frames(2)
			ship.set_physics_process(false)
			var wave := WAVE.instantiate()
			wave.warning_seconds = 0
			wave.travel_speed = 0
			wave.tsunami = huge
			wave.damage = 48 if huge else 28
			wave.gap_center = 800
			wave.position = Vector2(ship.position.x, 0 if huge else ship.position.y)
			add_child(wave)
			await frames(3)
			check(ship.hull < 100 and ship.speed < 70, "A real crest must damage and slow the forward-moving ship.")
			var start_x: float = ship.position.x
			ship.set_physics_process(true)
			await frames(18)
			var retreat: float = start_x - ship.position.x
			print("Wave retreat: ", retreat, " braced=", braced, " tsunami=", huge)
			check(retreat > 12, "Even at full throttle and maximum following wind, a crest must move the ship backwards.")
			wave.free()
			ship.free()
	var calm_ship := SHIP.instantiate()
	add_child(calm_ship)
	calm_ship.sailing = true
	calm_ship.calm = true
	calm_ship.set_physics_process(false)
	calm_ship.hull = 60
	for _frame in 120:
		calm_ship.apply_weather(1.0 / 60)
	check(is_equal_approx(calm_ship.hull, 60), "Calm water must preserve the hull without requiring repair input.")
	calm_ship.take_wave_damage(48, Vector2(-560, 0))
	check(is_equal_approx(calm_ship.hull, 60) and calm_ship.impulse.is_zero_approx(), "A wave must dissipate inside calm water without hull damage or drag out of shelter.")
	calm_ship.apply_weather(1, true)
	check(is_equal_approx(calm_ship.hull, 67.5), "Calm water must still allow crew repairs.")
	calm_ship.calm = false
	calm_ship.take_wave_damage(28, Vector2(-360, 0))
	var after_first: float = calm_ship.hull
	calm_ship.take_wave_damage(28, Vector2(-360, 0))
	check(is_equal_approx(calm_ship.hull, after_first) and calm_ship.impulse.x < -700, "A second crest during damage protection must still push, without stacking damage.")
	calm_ship.free()
	await sail_controls()
	print("STORM SAILS/PUSH: ", checks, " checks; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
