extends Node2D

const ENCOUNTER := preload("res://Ato7_Sereias/Gameplay/SirenEncounter.gd")
const BOAT := preload("res://Assets/act4_storm/ship_hull_rowing.png")
const REEF := preload("res://Assets/act4_storm/rock_reef.png")
const WATER_SHADER := preload("res://Assets/act7_sirens/cove.gdshader")
const PENELOPE := preload("res://Assets/act4_vigil/penelope_vision.png")
const OPEN_DECK := preload("res://Assets/act8_scylla/open_deck.png")
const CAVE_ENTRANCE := preload("res://Assets/act7_sirens/scylla_entrance.png")
const PALE_FOAM := Color(0.66, 0.94, 0.85)
const AMBER := Color("f3d78b")
const SIREN_TINT := Color("e7f3e9")
const SIZE := Vector2(1152, 648)

var encounter: ENCOUNTER
var aim := Vector2.ZERO
var show_aim := false
var water: ShaderMaterial
var siren_art: Texture2D
var wakes: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var wake_clock := 0.0
var deck_visible := false
var cave_visible := false
var deck_blend := 0.0
var cave_age := 0.0

func _ready() -> void:
	siren_art = load("res://Assets/act7_sirens/siren_atlas.png")
	var surface := ColorRect.new()
	surface.size = SIZE
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = true
	water = ShaderMaterial.new()
	water.shader = WATER_SHADER
	surface.material = water
	add_child(surface)

func update_view(delta: float, pointer: Vector2, visible_aim: bool) -> void:
	aim = pointer
	show_aim = visible_aim
	water.set_shader_parameter("tide_clock", encounter.clock)
	var warp := encounter.song_strength * 0.35
	if encounter.helm_inverted(): warp = maxf(warp, 0.34)
	if encounter.charm_age > 0.0: warp = maxf(warp, smoothstep(0.0, 1.4, encounter.charm_age) * 0.88)
	water.set_shader_parameter("enchantment", warp)
	if deck_visible: deck_blend = minf(1.0, deck_blend + delta * 1.45)
	if cave_visible: cave_age += delta
	wake_clock -= delta
	if wake_clock <= 0.0 and encounter.velocity.length() > 25.0 and encounter.phase in [ENCOUNTER.Phase.ACTIVE, ENCOUNTER.Phase.ENTHRALLED]:
		wake_clock = 0.052
		var direction := encounter.velocity.normalized()
		wakes.append({"at": encounter.position - direction * 48.0, "heading": direction.angle(), "clock": encounter.clock})
	while not wakes.is_empty() and encounter.clock - float(wakes[0].clock) > 1.3:
		wakes.pop_front()
	while not splashes.is_empty() and encounter.clock - float(splashes[0].clock) > 0.9:
		splashes.pop_front()
	queue_redraw()

func add_splash(kind: String, at: Vector2) -> void:
	if kind in ["capture", "hook", "escape", "splash", "hurt", "false_target", "break_free"]:
		splashes.append({"at": at, "clock": encounter.clock, "gold": kind in ["capture", "hook"], "phantom": kind == "false_target"})

func clear_effects() -> void:
	wakes.clear()
	splashes.clear()
	wake_clock = 0.0

func reveal_cave() -> void:
	cave_visible = true

func _draw() -> void:
	if encounter == null:
		return
	_draw_shore()
	for wake in wakes:
		var age := encounter.clock - float(wake.clock)
		var spread := 13.0 + age * 30.0
		draw_set_transform(wake.at, wake.heading)
		draw_arc(Vector2.ZERO, spread, PI - 0.75, PI + 0.75, 18, Color(PALE_FOAM, (1.0 - age / 1.3) * 0.29), 1.5, true)
	draw_set_transform(Vector2.ZERO)
	for reflection in encounter.illusions: _draw_siren(reflection, true)
	_draw_siren(encounter.siren.position)
	_draw_ship()
	_draw_net()
	_draw_reel_line()
	for splash in splashes:
		_draw_splash(splash)
	if show_aim and encounter.phase == ENCOUNTER.Phase.ACTIVE and not encounter.hooked:
		_draw_aim()
	if deck_blend > 0.0: _draw_finale()

func _draw_shore() -> void:
	var cliffs := [Vector3(-78, 132, 105), Vector3(95, 26, 130), Vector3(275, 15, 103), Vector3(1033, 9, 143), Vector3(1195, 139, 94), Vector3(-38, 658, 115), Vector3(158, 676, 113), Vector3(1112, 667, 124)]
	for cliff in cliffs:
		_draw_reef(Vector2(cliff.x, cliff.y), cliff.z, Color(0.48, 0.67, 0.66, 0.91))
	for reef in ENCOUNTER.REEFS:
		var at := Vector2(reef.x, reef.y)
		var pulse := 0.5 + sin(encounter.clock * 1.8 + reef.x) * 0.5
		for ring in 3:
			draw_set_transform(at, 0.0, Vector2(1.0, 0.68))
			draw_arc(Vector2.ZERO, reef.z + 15.0 + ring * 11.0 + pulse * 3.0, 0.12, TAU - 0.34, 46, Color(PALE_FOAM, 0.15 - ring * 0.035), 1.5, true)
		draw_set_transform(Vector2.ZERO)
		_draw_reef(at, reef.z, Color("a6b4a8"))

func _draw_reef(at: Vector2, radius: float, tint: Color) -> void:
	var dims := Vector2(radius * 2.48, radius * 1.82)
	draw_texture_rect_region(REEF, Rect2(at - Vector2(dims.x * 0.5, dims.y * 0.63), dims), Rect2(69, 210, 1126, 865), tint)

func _draw_ship() -> void:
	var bob := sin(encounter.clock * 3.1) * 1.8
	var at := encounter.position + Vector2(0, bob)
	draw_set_transform(at + Vector2(3, 4), encounter.heading, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 64.0, Color(0.02, 0.08, 0.11, 0.58))
	draw_set_transform(at, encounter.heading)
	var tint := Color("ffbdaa") if encounter.hit_cooldown > 0.63 else Color.WHITE
	draw_texture_rect_region(BOAT, Rect2(-62, -25, 124, 50), Rect2(15, 191, 1650, 555), tint)
	draw_set_transform(Vector2.ZERO)

func _draw_siren(at: Vector2, phantom := false) -> void:
	var siren := encounter.siren
	var time := encounter.clock
	var active := siren.captured_age < 0.0
	if not active:
		var travel := smoothstep(0.22, 0.85, siren.captured_age)
		at = at.lerp(encounter.position - Vector2.from_angle(encounter.heading) * 19.0, travel)
		if travel >= 1.0: return
	if active and (encounter.dive_time > 0.0 or encounter.interlude > 0.0):
		var ripple := 9.0 + fposmod(time * 37.0, 30.0)
		draw_arc(at, ripple, 0.0, TAU, 30, Color(PALE_FOAM, 0.34), 1.5, true)
		if encounter.interlude > 0.0:
			var motion := siren.velocity.normalized()
			for i in 7:
				var gap := fposmod(time * 125.0 + i * 13.0, 91.0)
				var trail := at - motion * gap + motion.orthogonal() * sin(i * 3.8) * gap * 0.14
				draw_circle(trail, 2.2 - gap * 0.013, Color(PALE_FOAM, (1.0 - gap / 91.0) * 0.55))
		return
	var illusion := smoothstep(0.32, 1.42, encounter.charm_age)
	if illusion > 0.0: _draw_penelope(at, illusion)
	var direction := Vector2.from_angle(siren.facing)
	if active and not phantom:
		for ring in 3:
			var spread := fposmod(time * 1.45 + ring / 3.0, 1.0)
			draw_set_transform(at - direction * (15.0 + spread * 27.0), siren.facing, Vector2(1.0, 0.58))
			draw_arc(Vector2.ZERO, 8 + spread * 22, PI - 1.05, PI + 1.05, 16, Color(PALE_FOAM, (1.0 - spread) * 0.55), 1.7, true)
		draw_set_transform(Vector2.ZERO)
		if encounter.leg != ENCOUNTER.Leg.MIRAGE and siren.singing > 0.01:
			for ring in 3:
				var pulse := fposmod(time * 0.72 + ring / 3.0, 1.0)
				draw_arc(at, 24.0 + ENCOUNTER.SONG_RADIUS * pulse, 0.0, TAU, 66, Color(SIREN_TINT, (1.0 - pulse) * siren.singing * 0.37), 1.35, true)
	var scale_y := -1.0 if direction.x < 0.0 else 1.0
	draw_set_transform(at, siren.facing, Vector2(1.0, scale_y))
	var fin_wave := sin(time * 10.0)
	var pose := 0 if fin_wave < 0.0 else 1
	if siren.velocity.length() > 130.0 and fin_wave > 0.38: pose = 2
	if not active: pose = 3
	var cell := siren_art.get_size() / 2.0
	var atlas := Rect2(Vector2(pose % 2, 0 if pose < 2 else 1) * cell, cell)
	var tint := Color(SIREN_TINT, 1.0 - illusion)
	if active and encounter.leg == ENCOUNTER.Leg.CHARM and encounter.hooked:
		tint.a *= 1.0 - encounter.tug * 0.54
	draw_texture_rect_region(siren_art, Rect2(-52, -34, 104, 68), atlas, tint)
	draw_set_transform(Vector2.ZERO)
	if not active: _draw_mesh(at, 26.0, 0.71)

func _draw_penelope(at: Vector2, opacity: float) -> void:
	var time := encounter.clock
	var position := at + Vector2(0, sin(time * 2.1) * 3.2)
	for i in range(4, 0, -1):
		draw_circle(position - Vector2(0, 22), 25.0 + i * 10.0, Color(0.53, 0.80, 0.85, 0.027 * opacity))
	var size := PENELOPE.get_size()
	var bounds := Rect2(position - Vector2(46, 83), Vector2(92, 92))
	for i in 9:
		var ratio := i / 9.0
		var section := Rect2(0, size.y * ratio, size.x, size.y / 9.0)
		var offset := Vector2(sin(time * 2.5 + i * 0.63) * (0.7 + ratio * 3.5), i * bounds.size.y / 9.0)
		var strip := Rect2(bounds.position + offset, Vector2(bounds.size.x, bounds.size.y / 9.0 + 0.23))
		var alpha := (0.89 - smoothstep(0.65, 1.0, ratio) * 0.72) * opacity
		draw_texture_rect_region(PENELOPE, strip, section, Color(0.75, 0.93, 1.0, alpha))

func _draw_net() -> void:
	var age := encounter.net_age
	if age < 0.0:
		return
	var flight := clampf(age / ENCOUNTER.NET_FLIGHT, 0.0, 1.0)
	var air := sin(flight * PI) * 48.0
	var at := encounter.net_from.lerp(encounter.net_to, flight) - Vector2(0, air)
	var fade := 1.0 - smoothstep(ENCOUNTER.NET_FLIGHT + 0.06, ENCOUNTER.NET_FLIGHT + 0.49, age)
	var radius := lerpf(8.0, ENCOUNTER.NET_RADIUS, smoothstep(0.0, 1.0, flight))
	var rope := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		rope.append(encounter.position.lerp(at, t) + Vector2(0, sin(t * PI) * 12.0 * flight))
	draw_polyline(rope, Color(AMBER, fade * 0.66), 1.8, true)
	_draw_mesh(at, radius, fade)

func _draw_reel_line() -> void:
	if not encounter.hooked:
		return
	var at := encounter.siren.position
	var within_reach := at.distance_to(encounter.position) <= ENCOUNTER.REEL_RANGE
	var hard_pull := maxf(encounter.line_tension, encounter.tug * 0.72)
	var tint := AMBER.lerp(Color("fc7c65"), smoothstep(0.35, 0.86, hard_pull)) if within_reach else Color("f3987f")
	var origin := encounter.position
	var midpoint := origin.lerp(at, 0.50)
	var snag := encounter.line_blocker
	if snag >= 0:
		var reef: Vector3 = ENCOUNTER.REEFS[snag]
		var center := Vector2(reef.x, reef.y)
		var normal := origin.direction_to(at).orthogonal()
		if (midpoint - center).dot(normal) < 0.0: normal = -normal
		midpoint = center + normal * (reef.z + 2.0)
		draw_arc(midpoint, 4.0 + fposmod(encounter.clock * 28.0, 8.0), 0.0, TAU, 16, Color(0.99, 0.60, 0.42, 0.60), 1.5, true)
		tint = Color("fa896d")
	var slack := lerpf(11.0, 0.9, hard_pull)
	var rope := PackedVector2Array()
	for index in 15:
		var t := index / 14.0
		var point := origin.lerp(midpoint, t * 2.0) if t <= 0.50 else midpoint.lerp(at, (t - 0.5) * 2.0)
		var sag := sin(t * PI) * slack if snag < 0 else 0.0
		var tremor := sin(t * 21.0 - encounter.clock * 21.0) * hard_pull * 2.6 * sin(t * PI)
		rope.append(point + Vector2(0, sag + tremor))
	if hard_pull > 0.60: draw_polyline(rope, Color(tint, 0.20), 5.0, true)
	draw_polyline(rope, Color(tint, 0.96), 2.1, true)
	_draw_mesh(at, 31.0, 0.85)
	var progress := encounter.reel_progress / encounter.reel_time()
	if progress > 0.0:
		draw_arc(at, 38.0, -PI / 2.0, -PI / 2.0 + progress * TAU, 35, tint, 3.0, true)

func _draw_mesh(at: Vector2, radius: float, fade: float) -> void:
	var color := Color(AMBER, fade * 0.74)
	draw_circle(at, radius, Color(AMBER, fade * 0.095), true, -1.0, true)
	draw_arc(at, radius, 0.0, TAU, 40, color, 1.6, true)
	for index in range(-2, 3):
		var fraction := index * 0.32
		var width := sqrt(1.0 - fraction * fraction) * radius
		var across := fraction * radius
		draw_line(at + Vector2(across, -width), at + Vector2(across, width), color, 1.0, true)
		draw_line(at + Vector2(-width, across), at + Vector2(width, across), color, 1.0, true)

func _draw_aim() -> void:
	var at := encounter.aim_point(aim)
	var ready := encounter.net_cooldown <= 0.0
	var color := Color(AMBER, 0.78) if ready else Color(PALE_FOAM, 0.32)
	for index in 4:
		var angle := PI * index / 2.0 + 0.18
		draw_arc(at, 19.0, angle, angle + 0.66, 10, color, 2.0, true)
	if aim.distance_to(at) > 2.0:
		draw_dashed_line(encounter.position.lerp(at, 0.30), at, Color(color, 0.38), 1.0, 9.0, true, true)
	draw_circle(at, 2.4, color, true, -1.0, true)

func _draw_finale() -> void:
	var reveal := smoothstep(0.0, 1.65, cave_age)
	_draw_deck_art(OPEN_DECK, smoothstep(0.0, 1.0, deck_blend), 0.0)
	if reveal > 0.0:
		_draw_deck_art(CAVE_ENTRANCE, reveal, smoothstep(0.0, 3.3, cave_age))

func _draw_deck_art(texture: Texture2D, opacity: float, focus: float) -> void:
	var size := texture.get_size()
	var ratio := SIZE.aspect()
	var source_size := Vector2(minf(size.x, size.y * ratio), minf(size.y, size.x / ratio))
	source_size *= lerpf(1.0, 0.92, focus)
	var left := (size.x - source_size.x) * lerpf(0.5, 0.30, focus)
	var top := (size.y - source_size.y) * lerpf(0.34, 0.15, focus)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, SIZE), Rect2(Vector2(left, top), source_size), Color(0.91, 0.96, 1.0, opacity))

func _draw_splash(splash: Dictionary) -> void:
	var age := encounter.clock - float(splash.clock)
	var at: Vector2 = splash.at
	if splash.phantom:
		for i in 8:
			var y := sin(float(i) * 8.47) * (17.0 + age * 28.0)
			var width := (10.0 + sin(float(i) * 4.4) * 8.0) * (1.0 + age)
			var offset := Vector2(sin(i * 6.0 + age * 3.0) * (22.0 + age * 38.0), y)
			draw_line(at + offset - Vector2(width, 0), at + offset + Vector2(width, 0), Color(0.62, 0.86, 0.94, maxf(0.0, 0.65 - age)), 1.5, true)
		return
	var color := AMBER if splash.gold else PALE_FOAM
	var alpha := 1.0 - age / 0.9
	draw_arc(at, 11.0 + age * 93.0, 0, TAU, 32, Color(color, alpha * 0.67), 1.5, true)
	for index in 13:
		var direction := Vector2.from_angle(index * TAU / 13.0 + 0.3)
		var point := at + direction * (12.0 + age * (56.0 + (index % 3) * 13.0))
		draw_line(point, point + direction * alpha * 6.0, Color(color, alpha), 1.5, true)
