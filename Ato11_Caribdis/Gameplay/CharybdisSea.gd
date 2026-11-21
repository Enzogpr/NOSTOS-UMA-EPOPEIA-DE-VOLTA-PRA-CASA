extends Node2D

const RUN := preload("res://Ato11_Caribdis/Gameplay/CharybdisRun.gd")
const HAZARDS := preload("res://Assets/act11_charybdis/hazards.png")
const KIT := preload("res://Assets/act10_calypso/island_kit.png")
const REEF := preload("res://Assets/act4_storm/rock_reef.png")
const WATER := preload("res://Assets/act11_charybdis/whirlpool.gdshader")
const VIEW := Vector2(1152, 648)
const CENTER := Vector2(576, 328)
const ELLIPSE := Vector2(1.37, 0.72)
const TEETH := Rect2(15, 162, 855, 567)
const WRECK := Rect2(945, 295, 798, 365)
const RAFT := Rect2(172, 56, 465, 390)

var run: RUN
var clock := 0.0
var material_water: ShaderMaterial

func _ready() -> void:
	var water := ColorRect.new()
	water.size = VIEW
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.show_behind_parent = true
	material_water = ShaderMaterial.new()
	material_water.shader = WATER
	water.material = material_water
	add_child(water)

func advance(delta: float) -> void:
	clock += delta * lerpf(0.37, 1.0, run.power())
	material_water.set_shader_parameter("clock", clock)
	material_water.set_shader_parameter("power", run.power())
	var pulse := 0.0
	if run.phase == RUN.Phase.ORBIT:
		for sweep: Vector3i in RUN.SWEEPS:
			if sweep.z != 0:
				pulse = maxf(pulse, 1.0 - smoothstep(0.0, 1.05, absf(run.sweep_time(sweep) - run.time)))
	material_water.set_shader_parameter("jaw_pulse", pulse)
	queue_redraw()

func _orbit(angle: float, radius: float) -> Vector2:
	return CENTER + Vector2.from_angle(angle) * ELLIPSE * radius

func _draw() -> void:
	_draw_reef(Vector2(2, 222), 240)
	_draw_reef(Vector2(65, 456), 190)
	_draw_reef(Vector2(1144, 323), 242)
	_draw_reef(Vector2(1089, 469), 174)
	_draw_current()
	_draw_mouth()
	if run.phase in [RUN.Phase.ORBIT, RUN.Phase.LOST]:
		_draw_sweeps()
	_draw_raft()

func _draw_reef(at: Vector2, width: float) -> void:
	var dims := Vector2(width, width * 0.78)
	draw_texture_rect_region(REEF, Rect2(at - dims * 0.5, dims), Rect2(69, 210, 1126, 865), Color("557478"))

func _draw_current() -> void:
	for band in RUN.RADII.size():
		var radius: float = RUN.RADII[band]
		for n in 13:
			var points := PackedVector2Array()
			var start := n * TAU / 13.0 + clock * (0.47 - band * 0.08) + band * 0.18
			for step in 12:
				var rad := radius + sin(n * 2.7 + clock + step * 0.28) * 5.0
				points.append(_orbit(start + step * 0.025, rad))
			var opacity := (0.24 + 0.17 * sin(n * 3.1 + clock)) * run.power()
			draw_polyline(points, Color(0.67, 0.90, 0.88, opacity), 2.3, true)

func _draw_mouth() -> void:
	var power := run.power()
	if power < 0.10:
		return
	for index in 8:
		var angle := index * TAU / 8.0 + 0.15 * sin(clock * 0.6)
		var radius := (58.0 + 7.0 * sin(clock * 1.55 + index * 0.45)) * (0.68 + power * 0.32)
		var at := _orbit(angle, radius)
		var radial := Vector2.from_angle(angle) * ELLIPSE
		draw_set_transform(at, radial.angle() - PI / 2.0)
		draw_texture_rect_region(HAZARDS, Rect2(-22, -9, 44, 25), TEETH, Color(0.43, 0.34, 0.43, power * 0.92))
	draw_set_transform(Vector2.ZERO)

func _draw_sweeps() -> void:
	for sweep: Vector3i in RUN.SWEEPS:
		var age := run.time - run.sweep_time(sweep)
		if age < -RUN.BUILDUP or age > 0.78:
			continue
		var angle := run.angle_at(run.sweep_time(sweep)) + age * 0.16
		for index in RUN.RADII.size():
			if (sweep.y & (1 << index)) == 0:
				continue
			var tooth := (sweep.z & (1 << index)) != 0
			var surface := smoothstep(-RUN.BUILDUP, -0.92, age) * (1.0 - smoothstep(0.40, 0.78, age))
			var emergence := smoothstep(-1.1 if tooth else -1.45, -0.39, age) * (1.0 - smoothstep(0.36, 0.75, age))
			var radius: float = RUN.RADII[index]
			_draw_breaker(angle, radius, surface)
			if emergence <= 0.02:
				continue
			var at := _orbit(angle, radius - (1.0 - emergence) * (49.0 if tooth else 15.0))
			var tangent := Vector2.from_angle(angle + PI / 2.0) * ELLIPSE
			var turn := tangent.angle() + (0.14 * sin(clock * 4.0) if not tooth else 0.0)
			draw_set_transform(at, turn, Vector2(1.0, 0.53 + emergence * 0.47))
			var rect := Rect2(-45, -32, 90, 62) if tooth else Rect2(-39, -18, 78, 36)
			draw_texture_rect_region(HAZARDS, rect, TEETH if tooth else WRECK, Color(1.0, 1.0, 1.0, emergence))
			draw_set_transform(Vector2.ZERO)

func _draw_breaker(angle: float, radius: float, surface: float) -> void:
	for row in 3:
		var points := PackedVector2Array()
		for step in 22:
			var offset := step / 21.0 - 0.5
			var curl := sin(offset * 12.0 + clock * 7.0 + row * 0.7) * 3.0
			var r := radius + row * 7.0 - 7.0 + curl
			points.append(_orbit(angle + offset * 0.43, r))
		draw_polyline(points, Color(0.035, 0.24, 0.27, surface * 0.61), 5.0, true)
		draw_polyline(points, Color(0.76, 0.96, 0.91, surface * (0.78 - row * 0.13)), 2.6, true)

func _draw_raft() -> void:
	var angle := run.angle_at(run.time)
	var radius := run.radius_at(run.lane)
	var at := _orbit(angle, radius)
	var tangent := (Vector2.from_angle(angle + PI / 2.0) * ELLIPSE).normalized()
	var outward := (at - CENTER).normalized()
	if run.release > 0.0:
		at += tangent * run.release * 108.0 + outward * pow(run.release, 2.0) * 52.0
		tangent = (tangent * 108.0 + outward * run.release * 104.0).normalized()
	if run.phase == RUN.Phase.LOST:
		at = at.lerp(CENTER, minf(run.hit_cooldown * 0.22, 0.2))
	var heading := tangent.angle() + (run.target_lane - run.lane) * 0.21
	var hit := run.hit_cooldown / 0.88
	var floating := at + Vector2(0, sin(clock * 7.0) * 2.8)
	for i in 9:
		var behind := tangent * (29.0 + i * 6.0)
		var drift := tangent.orthogonal() * sin(i * 0.57 + clock * 5.1) * 5.0
		var wake := at - behind + drift
		draw_set_transform(wake, tangent.angle() + PI / 2.0, Vector2(1, 0.37))
		draw_arc(Vector2.ZERO, 10.0 + i * 2.4, 0.18, PI - 0.18, 21, Color(0.75, 0.97, 0.94, (1.0 - i / 9.0) * 0.55), 1.6, true)
	draw_set_transform(floating, heading + sin(clock * 9.0) * hit * 0.09)
	draw_texture_rect_region(KIT, Rect2(-37, -37, 78, 65), RAFT, Color(1.0, 1.0 - 0.38 * hit, 1.0 - 0.40 * hit))
	draw_set_transform(Vector2.ZERO)
