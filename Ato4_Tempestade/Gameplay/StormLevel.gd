extends Node2D
## Hard storm crossing, followed by Aeolia passing overhead.

enum State { READY, SAILING, ARRIVAL, WON, LOST }
const GOAL := Vector2(22400, 800)
const WORLD_SIZE := Vector2(23000, 1600)
const WAVE := preload("res://Ato4_Tempestade/Gameplay/StormWave.tscn")
@export var persist_progress: bool = true
# Zero randomizes every attempt; nonzero seeds support repeatable replays.
@export var random_seed: int = 0
@onready var ship: CharacterBody2D = $StormShip
@onready var camera: Camera2D = $Camera2D
@onready var hud: Control = $UI/StormHUD
@onready var storm_audio: AudioStreamPlayer = $StormAudio
@onready var thunder: AudioStreamPlayer = $Thunder

var state: State = State.READY
var elapsed: float = 0.0
var sea_clock: float = 0.0
var wind := Vector2.ZERO
var wind_target := Vector2.ZERO
var next_gust: float = 0.0
var gust_changes: int = 0
var warning: String = ""
var flash: float = 0.0
var shake: float = 0.0
var next_wave: float = 5.0
var next_thunder: float = 8.0
var tsunami_index: int = 0
var surprise_waves: int = 0
var tsunami_thresholds := [2600.0, 6500.0, 10500.0, 14800.0, 19100.0]
var rng := RandomNumberGenerator.new()
var ambience_rng := RandomNumberGenerator.new()
var previous_music_volume: float = 0.0
var exiting: bool = false
var camera_factor: float = 1.0
var arrival_age: float = 0.0
var arrival_origin := Vector2.ZERO

func _ready() -> void:
	set_meta("hide_main_hud", true)
	GameManager.combat_mode = false
	if persist_progress:
		GameManager.unlock_level(4)
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	ambience_rng.seed = rng.seed ^ 9071
	hud.level = self
	ship.sunk.connect(func(): finish(false))
	ship.damaged.connect(func(_amount: float): shake = 9.0)
	$SkyPassage.body_entered.connect(_at_sky_passage)
	$SkyIsland.hide()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	camera.position = ship.position + Vector2(190, 0)
	previous_music_volume = AudioManager.music_player.volume_db
	AudioManager.music_player.volume_db = -80.0
	var loop := storm_audio.stream.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / (4 if loop.stereo else 2)
	storm_audio.stream = loop
	storm_audio.play()

func _fit_camera() -> void:
	var viewport_size := get_viewport_rect().size
	camera_factor = minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	camera.zoom = Vector2.ONE * camera_factor

func start_sailing() -> void:
	if state != State.READY:
		return
	state = State.SAILING
	ship.sailing = true
	hud.start_button.release_focus()
	hud.start_button.hide()

func _physics_process(delta: float) -> void:
	if state != State.SAILING:
		return
	elapsed += delta
	update_wind(delta)
	ship.wind = wind
	ship.calm = is_calm_at(ship.position)
	ship.whirlpool_pull = Vector2.ZERO
	ship.in_whirlpool = false
	for vortex in $Whirlpools.get_children():
		ship.whirlpool_pull += vortex.field_at(ship.position)
		if vortex.contains(ship.position):
			ship.in_whirlpool = true
	if ship.in_whirlpool:
		ship.calm = false
	if tsunami_index < tsunami_thresholds.size() and ship.position.x >= tsunami_thresholds[tsunami_index]:
		spawn_wave(true)
		tsunami_index += 1
	var incoming_waves: int = 0
	var incoming_tsunami: bool = false
	for wave in $Waves.get_children():
		if wave.position.x < ship.position.x - 180.0:
			continue
		if wave.tsunami:
			incoming_tsunami = true
		else:
			incoming_waves += 1
	if incoming_tsunami:
		# Keep a recovery window after the big front, without stacking new crests.
		next_wave = maxf(next_wave, elapsed + 4.0)
	elif elapsed >= next_wave and ship.position.x < GOAL.x - 450 and incoming_waves < 2:
		spawn_wave(false, rng.randf() < 0.20)
		next_wave = elapsed + rng.randf_range(5.0, 7.0)
	warning = ""
	for wave in $Waves.get_children():
		if wave.tsunami and wave.position.x >= ship.position.x - 150:
			var direction: String = "SUBA" if wave.gap_center < ship.position.y - 45 else "DESÇA" if wave.gap_center > ship.position.y + 45 else "MANTENHA O RUMO"
			warning = "TSUNAMI · %s · ABERTURA VERDE" % direction
			break
	if warning.is_empty() and wind.length() > 165:
		warning = "RAJADA FORTE · CORRIJA O LEME"

func update_wind(delta: float) -> void:
	if elapsed >= next_gust:
		var angle: float = rng.randf_range(-PI, PI)
		wind_target = Vector2.RIGHT.rotated(angle) * rng.randf_range(124.0, 192.0)
		next_gust = elapsed + rng.randf_range(5.0, 8.5)
		gust_changes += 1
	wind = wind.move_toward(wind_target, delta * 100.0)

func is_calm_at(point: Vector2) -> bool:
	for vortex in $Whirlpools.get_children():
		if vortex.contains(point):
			return false
	for zone in $CalmWaters.get_children():
		if point.distance_to(zone.position) <= zone.radius:
			return true
	return false

func spawn_wave(huge: bool, surprise: bool = false) -> Area2D:
	var wave: Area2D = WAVE.instantiate()
	wave.level = self
	wave.tsunami = huge
	wave.damage = 48.0 if huge else 28.0
	# Wind can add 192 to forward speed: warned fronts must stay ahead of the hull.
	wave.position = Vector2(ship.position.x + (1850.0 if huge else rng.randf_range(600, 820) if surprise else 950.0), 0 if huge else clampf(ship.position.y + rng.randf_range(-480, 480), 180, 1420))
	wave.warning_seconds = 3.0 if huge else 0.0 if surprise else 1.25
	wave.travel_speed = 220.0 if huge else rng.randf_range(160, 215)
	wave.height = rng.randf_range(230, 400)
	wave.gap_size = 275.0
	wave.gap_center = clampf(ship.position.y + (215.0 if tsunami_index % 2 == 0 else -215.0), 260, 1340)
	if not huge:
		wave.travel_direction = Vector2(-1, rng.randf_range(-0.22, 0.22)).normalized()
		wave.rotation = wave.travel_direction.angle() - PI
	$Waves.add_child(wave)
	if surprise:
		surprise_waves += 1
	if huge:
		flash = 0.8
		thunder.play()
	return wave

func _process(delta: float) -> void:
	sea_clock += delta
	flash = move_toward(flash, 0, delta * 2.0)
	shake = move_toward(shake, 0, delta * 20)
	var ocean_material := $Ocean.material as ShaderMaterial
	ocean_material.set_shader_parameter("storm_clock", sea_clock)
	ocean_material.set_shader_parameter("lightning", flash * 0.5)
	var arrival: bool = state in [State.ARRIVAL, State.WON]
	var camera_target: Vector2 = ship.position + (Vector2(80, -130) if arrival else Vector2(190, 0))
	camera.position = camera.position.lerp(camera_target, minf(delta * 4.0, 1.0))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * camera_factor * (0.86 if arrival else 1.0), minf(delta * 2.0, 1.0))
	camera.offset = Vector2(sin(sea_clock * 45), cos(sea_clock * 38)) * shake
	if state == State.SAILING and elapsed >= next_thunder:
		flash = 0.65
		thunder.volume_db = -12
		thunder.play()
		# Sound timing must not alter the next physical wave or wind gust.
		next_thunder = elapsed + ambience_rng.randf_range(9, 15)
	if arrival:
		arrival_age += delta
		var travel: float = 1.0 - pow(1.0 - minf(arrival_age / 6.5, 1.0), 3.0)
		$SkyIsland.position = arrival_origin + Vector2(lerpf(1450, 80, travel), -285 + sin(sea_clock * 0.6) * 8)
		$SkyIsland.rotation = sin(sea_clock * 0.3) * 0.008
		if state == State.ARRIVAL and arrival_age >= 6.5:
			finish(true)
	queue_redraw()

func _draw() -> void:
	if state in [State.ARRIVAL, State.WON]:
		draw_set_transform(arrival_origin + Vector2(60, 0), 0, Vector2(1, 0.3))
		for ring in 10:
			draw_circle(Vector2.ZERO, 390 - ring * 16, Color(0.0, 0.025, 0.04, minf(arrival_age / 3, 1.0) * 0.04))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for wave in $Waves.get_children():
		if wave.tsunami and wave.position.x >= ship.position.x - 80 and state == State.SAILING:
			var target := Vector2(minf(wave.position.x - 70, ship.position.x + 380), wave.gap_center)
			draw_arc(target, 30, 0, TAU, 24, Color(0.39, 0.97, 0.75, 0.55), 2)
			draw_string(ThemeDB.fallback_font, target + Vector2(-55, -44), "PASSAGEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.59, 1.0, 0.81))

func _at_sky_passage(body: Node2D) -> void:
	if body == ship and state == State.SAILING:
		begin_arrival()

func begin_arrival() -> void:
	if state != State.SAILING:
		return
	state = State.ARRIVAL
	stop_ship()
	arrival_origin = ship.position
	arrival_age = 0.0
	camera.limit_top = -1200
	camera.limit_bottom = 2800
	camera.limit_right = 24200
	warning = ""
	$SkyIsland.show()
	$SkyIsland.position = arrival_origin + Vector2(1450, -285)
	var soften := create_tween()
	soften.tween_property(storm_audio, "volume_db", -15.0, 3.0)

func stop_ship() -> void:
	ship.sailing = false
	ship.rowing_effort = 0
	ship.velocity = Vector2.ZERO
	ship.speed = 0.0
	ship.drift = Vector2.ZERO
	ship.impulse = Vector2.ZERO
	ship.whirlpool_pull = Vector2.ZERO

func finish(won: bool) -> void:
	if state not in [State.SAILING, State.ARRIVAL]:
		return
	state = State.WON if won else State.LOST
	stop_ship()
	warning = ""
	hud.retry_button.visible = true
	hud.map_button.visible = true
	if won:
		hud.continue_button.show()
		hud.continue_button.grab_focus()
	else:
		var sinking := create_tween().set_parallel(true)
		sinking.tween_property(ship.sprite, "modulate:a", 0.0, 1.4)
		sinking.tween_property(ship.sprite, "scale", Vector2.ONE * 0.065, 1.4)
		sinking.tween_property(ship.get_node("RowingRig"), "modulate:a", 0.0, 1.4)
		hud.retry_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and state in [State.WON, State.LOST]:
			get_viewport().set_input_as_handled()
			retry()

func retry() -> void:
	if exiting:
		return
	exiting = true
	get_tree().reload_current_scene()

func return_to_map() -> void:
	if exiting:
		return
	exiting = true
	get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")

func continue_to_aeolia() -> void:
	if exiting or state != State.WON:
		return
	exiting = true
	GameManager.set_meta("aeolia_arrival_hull", ship.hull)
	get_tree().change_scene_to_file("res://Ato4_Tempestade/Cutscenes/AeoliaApproach.tscn")

func _exit_tree() -> void:
	AudioManager.music_player.volume_db = previous_music_volume
