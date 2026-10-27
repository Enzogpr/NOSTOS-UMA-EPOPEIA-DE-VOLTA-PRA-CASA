extends Control
## Fixed logical coordinates keep aim, swept contacts and resizing consistent.

signal rope_attached
signal ascent_completed

enum State { READY, AIMING, CHARGING, FLYING, RETURNING, LATCHED, DIALOGUE, CLIMBING, COMPLETE }
const GRAVITY: float = 360.0
const LAUNCHER := Vector2(274, 480)
const ANCHOR_OFFSET := Vector2(-101, 17)
const MEETING := "res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn"
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
@export var transition_enabled: bool = true
@export var play_climb_dialogue: bool = true
@export var aim_speed: float = 42.0
@export var charge_seconds: float = 1.25
@onready var stage: Node2D = $Stage
@onready var island: Sprite2D = $Stage/Island
@onready var anchor: Area2D = $Stage/Anchor
@onready var anchor_shape: CollisionShape2D = $Stage/Anchor/CollisionShape2D
@onready var climber: Sprite2D = $Stage/Climber

var state: State = State.READY
var clock: float = 0.0
var angle_degrees: float = 50.0
var charge: float = 0.0
var wind: float = 0.0
var shot_wind: float = 0.0
var projectile := Vector2.ZERO
var projectile_velocity := Vector2.ZERO
var flight_age: float = 0.0
var phase_age: float = 0.0
var attempts: int = 0
var arrival_hull: float = 100.0
var miss_origin := Vector2.ZERO
var launch_point := Vector2.ZERO
var frozen_island := Vector2.ZERO
var status: String = "Acerte o aro de bronze para prender a corda."
var start_button: Button
var map_button: Button
var exiting: bool = false
var font: Font = ThemeDB.fallback_font
var conversation: Control
var dialogue_completed: bool = false
var ascent_reveal: float = 0.0
var charge_stat_factor: float = 1.0
var wind_stat_factor: float = 1.0

func _ready() -> void:
	set_meta("hide_main_hud", true)
	GameManager.combat_mode = false
	_sync_player_stats()
	GameManager.player_stats_changed.connect(_sync_player_stats)
	arrival_hull = float(GameManager.get_meta("aeolia_arrival_hull", 100.0))
	start_button = _button("PREPARAR O ARPÃO  ›", Vector2(416, 448), Vector2(320, 46), begin)
	map_button = _button("VOLTAR AO MAPA", Vector2(931, 21), Vector2(194, 38), return_to_map)
	get_viewport().size_changed.connect(_fit_stage)
	_fit_stage()
	_update_world()
	start_button.grab_focus()

func apply_player_stats(stats: Dictionary) -> void:
	# Keep designer exports as baselines; reapplying stats cannot compound them.
	charge_stat_factor=sqrt(maxf(0.3,float(stats.get("speed_mult",1.0))))
	wind_stat_factor=clampf(1.0-maxf(0.0,float(stats.get("intellect",5))-5.0)*0.025,0.75,1.0)

func _sync_player_stats() -> void:
	apply_player_stats(ATTRIBUTES.capture(GameManager))

func effective_charge_seconds() -> float:
	return maxf(0.05,charge_seconds/maxf(0.1,charge_stat_factor))

func _button(text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.z_index = 20
	button.add_theme_font_size_override("font_size", 17)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.12, 0.16, 0.95)
	style.border_color = Color(0.72, 0.66, 0.39)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.27, 0.3)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(action)
	stage.add_child(button)
	return button

func _fit_stage() -> void:
	var viewport_size := get_viewport_rect().size
	var factor: float = minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (viewport_size - Vector2(1152, 648) * factor) / 2.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.025, 0.08, 0.13))

func island_position_at(time: float) -> Vector2:
	return Vector2(890 + sin(time * 0.70) * 96, 218 + sin(time * 0.95) * 32)

func _update_world() -> void:
	island.position = frozen_island if state >= State.LATCHED else island_position_at(clock)
	anchor.position = island.position + ANCHOR_OFFSET
	$Stage/Ship.position.y = 453 + sin(clock * 1.1) * 2.5

func begin() -> void:
	if state != State.READY:
		return
	state = State.AIMING
	start_button.release_focus()
	start_button.hide()
	map_button.release_focus()

func start_charge() -> void:
	if state != State.AIMING:
		return
	state = State.CHARGING
	charge = 0.0
	status = "Segure para carregar. Solte Espaço para disparar."

func direction_for(angle: float) -> Vector2:
	return Vector2.RIGHT.rotated(-deg_to_rad(angle))

func muzzle_for(angle: float) -> Vector2:
	return LAUNCHER + direction_for(angle) * 32.0

func speed_for(strength: float) -> float:
	return lerpf(370.0, 780.0, strength)

func release_shot() -> void:
	if state != State.CHARGING:
		return
	state = State.FLYING
	attempts += 1
	flight_age = 0.0
	launch_point = muzzle_for(angle_degrees)
	projectile = launch_point
	projectile_velocity = direction_for(angle_degrees) * speed_for(charge)
	shot_wind = wind*wind_stat_factor
	$ShotSound.play()
	status = "O arpão está no ar…"

func _physics_process(delta: float) -> void:
	var previous_anchor: Vector2 = anchor.position
	clock += delta
	wind = sin(clock * 0.36) * 22.0
	_update_world()
	if state in [State.AIMING, State.CHARGING]:
		var turn: float = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		angle_degrees = clampf(angle_degrees + turn * aim_speed * delta, 25.0, 75.0)
		if state == State.CHARGING:
			charge = minf(1.0, charge + delta / effective_charge_seconds())
	elif state == State.FLYING:
		flight_age += delta
		var previous: Vector2 = projectile
		var acceleration := Vector2(shot_wind, GRAVITY)
		projectile += projectile_velocity * delta + acceleration * (0.5 * delta * delta)
		projectile_velocity += acceleration * delta
		# Sweep relative motion too: the smaller moving aro can cross a fast shot.
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, previous - previous_anchor, projectile - anchor.position)
		var radius: float = (anchor_shape.shape as CircleShape2D).radius
		if closest.length() <= radius:
			_attach_rope()
		elif projectile.y > 561 or projectile.y < -120 or projectile.x > 1190 or flight_age > 4.5:
			_recall()
	elif state == State.RETURNING:
		phase_age += delta
		projectile = miss_origin.lerp(LAUNCHER, 1.0 - pow(1.0 - minf(phase_age / 0.65, 1.0), 3))
		if phase_age >= 0.65:
			state = State.AIMING
			charge = 0
	elif state == State.LATCHED:
		phase_age += delta
		projectile = anchor.position
		if phase_age >= 0.75:
			if play_climb_dialogue and not dialogue_completed:
				_start_conversation()
			else:
				_begin_climb()
	elif state == State.CLIMBING:
		phase_age += delta
		var progress: float = smoothstep(0.0, 1.0, minf(phase_age / 4.2, 1.0))
		climber.position = LAUNCHER.lerp(anchor.position, progress) + Vector2(-8, 5)
		climber.rotation = sin(phase_age * 8) * 0.035
		if phase_age >= 4.8:
			state = State.COMPLETE
			ascent_completed.emit()
			if transition_enabled:
				call_deferred("_enter_meeting")
	stage.queue_redraw()

func _recall() -> void:
	state = State.RETURNING
	phase_age = 0
	miss_origin = projectile
	status = "Faltou alcance. Tente um pouco mais de força." if projectile.y > 561 and projectile.x < anchor.position.x - 28 else "Quase! Ajuste o ângulo ou a força e tente novamente."

func _start_conversation() -> void:
	if conversation != null:
		return
	state = State.DIALOGUE
	set_meta("cinematic_active", true)
	conversation = preload("res://Ato4_Tempestade/Cutscenes/LuckRunsOut.tscn").instantiate()
	conversation.standalone_ascent = false
	conversation.z_index = 30
	conversation.conversation_finished.connect(_resume_after_conversation)
	add_child(conversation)

func _resume_after_conversation() -> void:
	if dialogue_completed:
		return
	dialogue_completed = true
	set_meta("cinematic_active", false)
	conversation.queue_free()
	conversation = null
	_begin_climb()
	ascent_reveal = 1.0
	create_tween().tween_property(self,"ascent_reveal",0.0,0.65)

func _begin_climb() -> void:
	state = State.CLIMBING
	phase_age = 0.0
	climber.position = LAUNCHER + Vector2(-8,5)
	climber.show()
	status = "Odisseu sobe pela corda até Eólia."

func prepare_ascent_preview() -> void:
	# F6 on the dialogue previews its natural continuation without another shot.
	dialogue_completed = true
	frozen_island = island.position
	projectile = anchor.position
	start_button.hide()
	map_button.hide()
	_begin_climb()
	ascent_reveal = 1.0
	create_tween().tween_property(self,"ascent_reveal",0.0,0.65)

func _attach_rope() -> void:
	state = State.LATCHED
	phase_age = 0
	frozen_island = island.position
	projectile = anchor.position
	status = "CORDA PRESA · O caminho para Eólia está aberto."
	map_button.hide()
	rope_attached.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	if state == State.READY and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		begin()
	elif event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if event.pressed:
			start_charge()
		else:
			release_shot()

func _enter_meeting() -> void:
	if exiting:
		return
	exiting = true
	get_tree().change_scene_to_file(MEETING)

func return_to_map() -> void:
	if exiting:
		return
	exiting = true
	get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func _label(canvas: Node2D, text: String, at: Vector2, size_px: int = 18, color: Color = Color(0.88, 0.94, 0.93)) -> void:
	canvas.draw_string(font, at + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.025, 0.055, 0.085, 0.9))
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func draw_stage(canvas: Node2D) -> void:
	# The backdrop stays behind the scene sprites; UI/rope are drawn separately.
	for strip in 81:
		var ratio: float = strip / 80.0
		canvas.draw_rect(Rect2(0, strip * 8, 1152, 8), Color(0.10, 0.20, 0.29).lerp(Color(0.53, 0.69, 0.70), ratio))
	for index in 9:
		var cloud := Vector2(fposmod(index * 169 - clock * (3 + index % 3), 1350) - 100, 180 + index % 4 * 70)
		canvas.draw_set_transform(cloud, 0, Vector2(2.8, 0.45))
		canvas.draw_circle(Vector2.ZERO, 42 + index % 3 * 9, Color(0.84, 0.9, 0.88, 0.075))
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	canvas.draw_rect(Rect2(0, 510, 1152, 138), Color(0.06, 0.23, 0.29))
	for index in 20:
		var y: float = 519 + index % 5 * 20
		var x: float = fposmod(index * 87 + sin(clock * 0.7) * 8, 1152)
		canvas.draw_line(Vector2(x, y), Vector2(x + 54, y), Color(0.5, 0.77, 0.79, 0.18), 2)

# This child draws after the island and ship, keeping the rope/target readable.
func draw_foreground(canvas: Node2D) -> void:
	# A shallow wash places the bottom of the hull and oars in the water.
	canvas.draw_rect(Rect2(0, 510, 1152, 54), Color(0.06, 0.23, 0.29, 0.45))
	canvas.draw_line(Vector2(35, 516), Vector2(325, 516), Color(0.65, 0.84, 0.84, 0.25), 2)
	var attached: bool = state >= State.LATCHED
	var target: Vector2 = anchor.position
	canvas.draw_line(target + Vector2(0, -21), target + Vector2(0, -10), Color(0.5, 0.28, 0.10), 6)
	canvas.draw_line(target + Vector2(0, -21), target + Vector2(0, -10), Color(0.93, 0.72, 0.34), 2)
	canvas.draw_circle(target, 23 + sin(clock * 3) * 2, Color(0.98, 0.79, 0.36, 0.1))
	canvas.draw_arc(target, 13, 0, TAU, 48, Color(0.34, 0.20, 0.10), 5)
	canvas.draw_arc(target, 13, 0, TAU, 48, Color(0.98, 0.79, 0.39), 3)
	if not attached:
		_label(canvas, "ARO DE BRONZE", target + Vector2(-66, 40), 14, Color(1.0, 0.89, 0.61))
	if state in [State.AIMING, State.CHARGING]:
		var ray: Vector2 = direction_for(angle_degrees)
		canvas.draw_line(LAUNCHER + Vector2(0, 7), LAUNCHER, Color(0.38, 0.23, 0.10), 7)
		canvas.draw_line(LAUNCHER, LAUNCHER + ray * 36, Color(0.13, 0.10, 0.075), 9)
		canvas.draw_line(LAUNCHER, LAUNCHER + ray * 36, Color(0.84, 0.62, 0.28), 4)
		for dot in range(1, 10):
			var time: float = dot * 0.055
			var point: Vector2 = muzzle_for(angle_degrees) + ray * speed_for(charge) * time + Vector2(wind*wind_stat_factor, GRAVITY) * (0.5 * time * time)
			canvas.draw_circle(point, 2.5, Color(0.94, 0.87, 0.59, 0.65 - dot * 0.04))
	if state in [State.FLYING, State.RETURNING] or attached:
		var rope := PackedVector2Array()
		for step in 25:
			var fraction: float = step / 24.0
			rope.append(LAUNCHER.lerp(projectile, fraction) + Vector2(0, sin(fraction * PI) * (3 if attached else 12)))
		canvas.draw_polyline(rope, Color(0.14, 0.09, 0.055), 4)
		canvas.draw_polyline(rope, Color(0.85, 0.69, 0.40), 2)
		var facing: float = projectile_velocity.angle() if not attached else (target - LAUNCHER).angle()
		canvas.draw_set_transform(projectile, facing, Vector2.ONE)
		canvas.draw_line(Vector2(-18, 0), Vector2(5, 0), Color(0.75, 0.49, 0.23), 3)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(0, -5), Vector2(3, 0), Vector2(0, 5)]), Color(0.94, 0.9, 0.72))
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	canvas.draw_rect(Rect2(24, 21, 420, 75), Color(0.025, 0.085, 0.12, 0.88))
	_label(canvas, "EÓLIA · A ILHA DOS VENTOS", Vector2(40, 50), 23, Color(0.98, 0.85, 0.54))
	_label(canvas, "Prenda a corda e alcance o reino de Éolo.", Vector2(40, 79), 17)
	canvas.draw_rect(Rect2(24, 564, 1104, 66), Color(0.025, 0.085, 0.12, 0.94))
	_label(canvas, status, Vector2(40, 591), 19, Color(0.85, 0.95, 0.84))
	_label(canvas, "A/D ou ←/→: ângulo   SEGURE ESPAÇO: força   SOLTE: disparar   ESC: pausa", Vector2(40, 618), 16)
	if state in [State.AIMING, State.CHARGING, State.FLYING, State.RETURNING]:
		canvas.draw_rect(Rect2(24, 114, 250, 135), Color(0.025, 0.085, 0.12, 0.88))
		_label(canvas, "ÂNGULO  %d°" % int(angle_degrees), Vector2(40, 142), 19)
		_label(canvas, "FORÇA  %d%%" % int(charge * 100), Vector2(40, 170), 15)
		canvas.draw_rect(Rect2(40, 184, 214, 13), Color(0.18, 0.30, 0.33))
		canvas.draw_rect(Rect2(40, 184, 214 * charge, 13), Color(0.92, 0.75, 0.39))
		_label(canvas, "BRISA  %s" % ("→" if wind >= 0 else "←"), Vector2(40, 227), 16)
		_label(canvas, "Tentativas ilimitadas · sem dano", Vector2(778, 536), 16, Color(0.80, 0.93, 0.89))
	if state == State.READY:
		canvas.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.035, 0.06, 0.57))
		canvas.draw_rect(Rect2(296, 198, 560, 315), Color(0.035, 0.11, 0.15, 0.97))
		canvas.draw_rect(Rect2(296, 198, 560, 315), Color(0.72, 0.65, 0.4), false, 2)
		_label(canvas, "UM CAMINHO PARA O CÉU", Vector2(329, 244), 27, Color(1, 0.86, 0.55))
		_label(canvas, "A ilha se move ao longe. Antecipe o aro de bronze.", Vector2(329, 281), 19)
		_label(canvas, "A/D: ajustar o ângulo do arpão", Vector2(329, 329), 20)
		_label(canvas, "Segure Espaço para carregar; solte para lançar.", Vector2(329, 366), 19)
		_label(canvas, "Um acerto basta. Errar permite tentar de novo.", Vector2(329, 409), 18, Color(0.77, 0.92, 0.84))
	if state == State.CLIMBING and phase_age > 4.0:
		canvas.draw_rect(Rect2(0, 0, 1152, 648), Color(0.025, 0.08, 0.13, clampf((phase_age - 4) / 0.8, 0, 1)))
	if ascent_reveal > 0.0:
		canvas.draw_rect(Rect2(0,0,1152,648),Color(0.0,0.0,0.0,ascent_reveal))
