extends CharacterBody2D
const ATTRIBUTES := preload("res://Code/PlayerAttributes.gd")
## Wind is part of the physical velocity, so cliffs and map limits still collide.

signal hull_changed(value: float)
signal damaged(amount: float)
signal sunk

@export var max_hull: float = 100.0
@export var max_speed: float = 265.0
@export var turn_speed: float = 1.8
@export var weather_damage: float = 1.15
@export var rock_damage: float = 28.0
@export var sail_transition_speed: float = 3.5
var sail_reef_amount: float = 0.0
var hull: float = 100.0
var sailing: bool = false
var speed: float = 0.0
var wind := Vector2.ZERO
var drift := Vector2.ZERO
var impulse := Vector2.ZERO
var calm: bool = false
var braced: bool = false
var repairing: bool = false
var whirlpool_pull := Vector2.ZERO
var in_whirlpool: bool = false
var whirlpool_timer: float = 0.0
var rowing_effort: float = 0.0
var helm_turn: float = 0.0
var hit_cooldown: float = 0.0
var age: float = 0.0
# The simulation also accepts deterministic helm commands for replay/verification.
var scripted_helm: bool = false
var helm := Vector2.ZERO
var brace_command: bool = false
var repair_command: bool = false
var handling_speed_factor := 1.0
var handling_turn_factor := 1.0
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	GameManager.player_stats_changed.connect(_sync_player_stats)
	_sync_player_stats()

func _sync_player_stats() -> void:
	apply_player_stats(ATTRIBUTES.capture(GameManager))

func apply_player_stats(stats: Dictionary) -> void:
	# Captain handling changes, while sea forces and the ship's hull retain
	# their authored values. Keep exports intact for idempotent live updates.
	handling_speed_factor=clampf(sqrt(maxf(0.3,float(stats.get("speed_mult",1.0)))),0.7,1.3)
	handling_turn_factor=clampf(1.0+(float(stats.get("intellect",5))-5.0)*0.02,1.0,1.2)

func _process(delta: float) -> void:
	if not sailing:
		return
	sail_reef_amount = move_toward(sail_reef_amount, 1.0 if braced else 0.0, delta * sail_transition_speed)
	(sprite.material as ShaderMaterial).set_shader_parameter("reef_amount", sail_reef_amount)

func _refresh_calm() -> void:
	var level := get_parent()
	if level != null and level.has_method("is_calm_at"):
		calm = level.is_calm_at(position)

func _physics_process(delta: float) -> void:
	if not sailing or hull <= 0.0:
		return
	_refresh_calm()
	age += delta
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	var turn: float = helm.x if scripted_helm else float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var throttle: float = helm.y if scripted_helm else float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	braced = brace_command if scripted_helm else Input.is_key_pressed(KEY_SPACE)
	var wants_repair: bool = repair_command if scripted_helm else Input.is_key_pressed(KEY_E)
	rowing_effort = throttle
	helm_turn = turn
	rotation += turn * turn_speed * handling_turn_factor * delta * (-0.7 if speed < -10.0 else 1.0)
	var target: float = throttle * max_speed * handling_speed_factor * (0.55 if braced else 1.0)
	if throttle < 0.0:
		target *= 0.35
	speed = move_toward(speed, target, (140.0*handling_speed_factor if throttle != 0.0 else 190.0) * delta)
	repairing = calm and not in_whirlpool and wants_repair and absf(speed) < 45.0
	var wind_factor: float = 0.0 if repairing else 0.15 if calm else 0.55 if braced else 1.0
	drift = drift.move_toward(wind * wind_factor, delta * 130.0)
	# Anchor during repairs and let crests dissipate within the calm shelter.
	impulse = impulse.move_toward(Vector2.ZERO, delta * (750.0 if repairing else 150.0))
	velocity = Vector2.RIGHT.rotated(rotation) * speed + drift + impulse + whirlpool_pull
	move_and_slide()
	_refresh_calm()
	for index in get_slide_collision_count():
		var obstacle: Object = get_slide_collision(index).get_collider()
		if obstacle is Node and obstacle.is_in_group("storm_rocks"):
			take_collision_damage(rock_damage, get_slide_collision(index).get_normal() * 120.0)
	apply_whirlpool(delta, in_whirlpool)
	apply_weather(delta, repairing)
	sprite.modulate = Color(1.0, 0.65, 0.55) if hit_cooldown > 0.0 and fmod(age * 8.0, 1.0) > 0.5 else Color.WHITE
	$RowingRig.modulate = sprite.modulate
	$RowingRig.scale = Vector2.ONE * (1.0 + sin(age * 3.0) * 0.012)
	sprite.scale = Vector2.ONE * 0.105 * (1.0 + sin(age * 3.0) * 0.012)
	queue_redraw()

func apply_weather(delta: float, crew_repair: bool = false) -> void:
	if hull <= 0.0:
		return
	if calm:
		if crew_repair:
			_set_hull(hull + 7.5 * delta)
	else:
		_set_hull(hull - weather_damage * delta)

func take_wave_damage(amount: float, shove: Vector2 = Vector2.ZERO) -> bool:
	_refresh_calm()
	if not sailing or hull <= 0.0 or calm:
		return false
	# Each crest pushes once, even during damage immunity from another front.
	# Lose forward momentum so the wave visibly carries the hull backwards.
	if not shove.is_zero_approx():
		speed *= 0.25
		impulse += shove * (0.65 if braced else 1.0)
	return _take_impact_damage(amount)

func take_collision_damage(amount: float, shove: Vector2) -> bool:
	if not sailing or hull <= 0.0 or hit_cooldown > 0.0:
		return false
	impulse += shove * (0.45 if braced else 1.0)
	return _take_impact_damage(amount)

func _take_impact_damage(amount: float) -> bool:
	if hit_cooldown > 0.0:
		return false
	var damage: float = amount * (0.55 if braced else 1.0)
	hit_cooldown = 0.85
	_set_hull(hull - damage)
	damaged.emit(damage)
	return true

func apply_whirlpool(delta: float, exposed: bool) -> void:
	if hull <= 0.0:
		return
	if not exposed:
		whirlpool_timer = 0.0
		return
	whirlpool_timer += delta
	while whirlpool_timer + 0.00001 >= 1.0:
		whirlpool_timer = maxf(0.0, whirlpool_timer - 1.0)
		_set_hull(hull - 3.0)
		damaged.emit(3.0)
		if hull <= 0.0:
			break

func _set_hull(value: float) -> void:
	var was_alive: bool = hull > 0.0
	hull = clampf(value, 0.0, max_hull)
	hull_changed.emit(hull)
	if hull <= 0.0 and was_alive:
		sailing = false
		sunk.emit()

func _draw() -> void:
	if not sailing:
		return
	for index in range(6):
		var distance: float = 70.0 + index * 17.0 + fmod(age * 35.0, 17.0)
		var width: float = 9.0 + index * 4.0
		draw_line(Vector2(-distance, -width), Vector2(-distance - 10, 0), Color(0.63, 0.85, 0.9, 0.32 - index * 0.04), 3.0)
		draw_line(Vector2(-distance - 10, 0), Vector2(-distance, width), Color(0.63, 0.85, 0.9, 0.32 - index * 0.04), 3.0)
