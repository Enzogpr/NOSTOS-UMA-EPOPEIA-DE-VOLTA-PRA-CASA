extends Node2D

const RUN := preload("res://Ato8_Cila/Gameplay/ScyllaRun.gd")
const BOAT := preload("res://Assets/act4_storm/ship_sails_furled.png")
const HEADS := preload("res://Assets/act8_scylla/scylla_heads.png")
const WALLS := preload("res://Assets/act8_scylla/cave_walls.png")
const WATER := preload("res://Assets/act8_scylla/cave_water.gdshader")
const LIGHT := preload("res://Assets/act8_scylla/torchlight.gdshader")
const VIEW := Vector2(1152, 648)
const EXIT := Vector2(576, 234)
const FLAME := Color("ffdb9b")

var run: RUN
var surface: ShaderMaterial
var lighting: ShaderMaterial
var bursts: Array[Dictionary] = []
var time := 0.0
var shake := 0.0
var torch_points := PackedVector3Array()
var daylight := 0.0

func _ready() -> void:
	surface = _material(WATER)
	var sea := _plane(surface)
	sea.show_behind_parent = true
	add_child(sea)
	var capture := BackBufferCopy.new()
	capture.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(capture)
	lighting = _material(LIGHT)
	add_child(_plane(lighting))
	update_view(0.0)

func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _plane(material: ShaderMaterial) -> ColorRect:
	var plane := ColorRect.new()
	plane.size = VIEW
	plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plane.material = material
	return plane

func reset_effects() -> void:
	bursts.clear()
	time = 0.0
	shake = 0.0

func add_impact(kind: String, at: Vector2) -> void:
	bursts.append({"kind": kind, "at": at, "time": time})
	if kind == "torch": shake = 0.29

func update_view(delta: float) -> void:
	time += delta
	shake = maxf(0.0, shake - delta)
	while not bursts.is_empty() and time - float(bursts[0].time) > 1.6:
		bursts.pop_front()
	var entrance := 1.0 - smoothstep(0.0, 290.0, run.distance)
	var exit := smoothstep(4150.0, RUN.EXIT_DISTANCE, run.distance)
	daylight = maxf(entrance * 0.46, exit)
	surface.set_shader_parameter("travel", run.distance)
	surface.set_shader_parameter("tide_clock", time)
	surface.set_shader_parameter("exit_light", exit)
	lighting.set_shader_parameter("daylight", Vector3(EXIT.x / VIEW.x, EXIT.y / VIEW.y, daylight))
	torch_points.resize(RUN.TORCHES.size())
	for i in RUN.TORCHES.size():
		var at := _flame_origin(i)
		var flicker := 0.88 + sin(time * 17.0 + i * 3.41) * 0.09 + sin(time * 33.0 + i) * 0.04
		torch_points[i] = Vector3(at.x, at.y, run.torch_strength(i) * flicker)
	lighting.set_shader_parameter("torches", torch_points)
	queue_redraw()

func _depth(at: float) -> float:
	return 600.0 / (600.0 + maxf(-310.0, at - run.distance))

func project(at: Vector2) -> Vector2:
	var depth := _depth(at.y)
	var tremor := Vector2(sin(time * 44.0), cos(time * 37.0)) * shake * 11.0
	return Vector2(576.0 + (at.x - run.lateral) * depth * 1.12, 154.0 + 299.0 * depth) + tremor

func _boat_at() -> Vector2:
	return project(Vector2(run.lateral, run.distance)) + Vector2(0, sin(time * 3.8) * 3.0)

func _flame_origin(index: int) -> Vector2:
	var slot: Vector2 = RUN.TORCHES[index]
	return _boat_at() + Vector2(slot.x * 1.10, -slot.y).rotated(run.heading) - Vector2(0, 9)

func _draw() -> void:
	if run == null:
		return
	_draw_wall(-1.0)
	_draw_wall(1.0)
	_draw_wake()
	for i in run.lunges.size(): _draw_lunge(i)
	_draw_ship()
	for i in torch_points.size():
		var source := torch_points[i]
		if source.z > 0.012: _draw_flame(Vector2(source.x, source.y), source.z, i)
	for burst in bursts: _draw_burst(burst)

func _draw_wall(side: float) -> void:
	var edge := PackedVector2Array()
	var polygon := PackedVector2Array()
	var sprite_cell := WALLS.get_size() * 0.5
	var nearest := run.distance - 307.0
	var mouth := 4390.0 + side * 45.0
	if nearest >= mouth: return
	var visible_length := minf(2340.0, mouth - nearest)
	var divisions := maxi(2, ceili(visible_length / 22.0))
	for i in range(divisions + 1):
		var along := nearest + visible_length * i / divisions
		var channel := RUN.channel_at(along)
		var rough := sin(along * 0.043) * 5.0 + sin(along * 0.019) * 8.0
		var point := project(Vector2(channel.x + side * (channel.y + rough), along))
		edge.append(point)
		polygon.append(point)
	var outside := -300.0 if side < 0.0 else VIEW.x + 300.0
	var cap := edge[-1] + Vector2(side * 87.0, -112.0) * _depth(nearest + visible_length)
	polygon.append(cap)
	polygon.append(Vector2(outside, cap.y - 22.0))
	polygon.append(Vector2(outside, VIEW.y + 155))
	draw_colored_polygon(polygon, Color("171f25"))
	var start := floori(nearest / 175.0)
	for i in range(start + 13, start - 1, -1):
		var along := i * 175.0 + sin(float(i) * 5.08) * 38.0
		if along < nearest or along > mouth: continue
		var depth := _depth(along)
		var bend := RUN.channel_at(along)
		var rim := project(Vector2(bend.x + (bend.y + 8.0) * side, along))
		var variant := posmod(i + (0 if side < 0.0 else 2), 4)
		var source := Rect2(Vector2(variant % 2, variant >> 1) * sprite_cell, sprite_cell)
		var dimensions := Vector2(528, 385) * depth * (0.94 + sin(float(i) * 2.6) * 0.20)
		draw_set_transform(rim, 0, Vector2(-side, 1.0))
		var tint := Color("a0a9a7") if i % 3 == 0 else Color("849491")
		draw_texture_rect_region(WALLS, Rect2(Vector2(-dimensions.x * 0.83, -dimensions.y * 0.88), dimensions), source, tint)
		draw_set_transform(Vector2.ZERO)
	var first_foam := ceili(nearest / 46.0)
	var last_foam := floori((nearest + visible_length) / 46.0)
	for i in range(first_foam, last_foam + 1):
		var along := i * 46.0
		var bend := RUN.channel_at(along)
		var at := project(Vector2(bend.x + side * (bend.y - 8.0 - sin(time * 2.2 + i) * 5.0), along))
		var float_width := _depth(along) * (8.0 + 9.0 * absf(sin(i * 2.1)))
		var pulse := 0.11 + 0.11 * sin(time * 2.0 + i * 2.1)
		draw_arc(at, float_width, 0.51, 2.62, 8, Color(0.52, 0.71, 0.69, pulse), 1.1, true)

func _draw_wake() -> void:
	var start := _boat_at()
	var motion := clampf(run.speed / 143.0, 0.0, 1.0)
	for j in 11:
		var trail := fposmod(time * (0.21 + motion * 0.46) + j * 0.091, 1.0)
		var at := start + Vector2(-run.heading * trail * 32.0, 44.0 + trail * 128.0)
		draw_set_transform(at, run.heading * 0.46, Vector2(1.0, 0.30))
		var opacity := (1.0 - trail) * (0.12 + motion * 0.38)
		draw_arc(Vector2.ZERO, 25.0 + trail * 51.0, 0.25, PI - 0.25, 25, Color(0.65, 0.72, 0.71, opacity), 2.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_lunge(index: int) -> void:
	var reach := run.reach(index)
	if reach <= 0.0: return
	var beat := run.lunges[index]
	var side: float = RUN.ATTACKS[index].y
	var along := (beat.strike_distance if beat.taken else run.distance) + 49.0
	var channel := RUN.channel_at(along)
	var edge := project(Vector2(channel.x + side * (channel.y + 78.0), along + 95.0))
	var at := _flame_origin(index) + Vector2(side * 28.0, -12.0)
	if beat.taken:
		at = project(run.torch_at(index, beat.strike_distance)) + Vector2(side * 28.0, -21.0)
	var tip := edge.lerp(at, reach)
	tip.y -= sin(reach * PI) * 34.0
	var depth := _depth(along)
	var size := Vector2(191.0, 130.0) * depth
	var neck_end := tip + Vector2(side * size.x * 0.48, 8.0)
	if neck_end.distance_to(edge) > 12.0 and (edge.x - neck_end.x) * side > 0.0:
		_draw_neck(edge, neck_end, depth, index)
	var face := 1 if beat.age >= RUN.OPENING and not beat.taken else 2 if beat.taken else 0
	var cell := HEADS.get_size() * 0.5
	var region := Rect2(Vector2(face % 2, face >> 1) * cell, cell)
	draw_set_transform(tip, side * sin(reach * PI) * 0.19, Vector2(-side, 1.0))
	draw_texture_rect_region(HEADS, Rect2(Vector2(-size.x * 0.79, -size.y * 0.66), size), region, Color("849c9f"))
	draw_set_transform(Vector2.ZERO)

func _draw_neck(edge: Vector2, end: Vector2, depth: float, index: int) -> void:
	var axis := edge.direction_to(end).orthogonal()
	var previous := edge
	var radius := 31.0 * depth
	for step in range(1, 9):
		var t := step / 8.0
		var bend := sin(t * PI) * (22.0 + sin(time * 4.0 + index) * 8.0)
		var at := edge.lerp(end, t) + Vector2(0.0, bend)
		var next_radius := lerpf(31.0, 24.0, t) * depth
		var points := PackedVector2Array([previous - axis * radius, at - axis * next_radius,
			at + axis * next_radius, previous + axis * radius])
		var uv := PackedVector2Array([Vector2(0.06, 0.18), Vector2(0.16, 0.18), Vector2(0.16, 0.37), Vector2(0.06, 0.37)])
		draw_polygon(points, PackedColorArray([Color("576d75")]), uv, HEADS)
		previous = at
		radius = next_radius

func _draw_ship() -> void:
	var at := _boat_at()
	var angle := run.heading - PI * 0.5
	draw_set_transform(at + Vector2(2, 9), angle, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, 92.0, Color(0.018, 0.034, 0.042, 0.68))
	draw_set_transform(at, angle)
	draw_texture_rect_region(BOAT, Rect2(-98, -37, 196, 74), Rect2(15, 191, 1650, 555), Color("cbbbaa"))
	draw_set_transform(Vector2.ZERO)

func _draw_flame(at: Vector2, strength: float, index: int) -> void:
	var lean := sin(time * 17.0 + index * 3.1) * 4.0 + run.heading * 5.0
	var tip := at + Vector2(lean, -14.0) * strength
	var shape := PackedVector2Array([at + Vector2(-4.4, 2.0) * strength,
		at + Vector2(-3.7, -6.2) * strength, tip, at + Vector2(4.5, -4.0) * strength,
		at + Vector2(4.3, 2.0) * strength])
	draw_colored_polygon(shape, Color(1.0, 0.41, 0.13, strength))
	draw_circle(at - Vector2(0, 2), 2.7 * strength, Color(FLAME, strength))
	for i in 3:
		var lift := fposmod(time * (0.63 + 0.13 * i) + i * 0.31 + index, 1.0)
		var spark := at + Vector2(sin(lift * 5.0 + i) * 11.0, -8.0 - lift * 34.0)
		draw_circle(spark, 1.35, Color(FLAME, strength * (1.0 - lift) * 0.88))

func _draw_burst(burst: Dictionary) -> void:
	var age := time - float(burst.time)
	var at := project(burst.at)
	var hot: bool = burst.kind == "torch"
	var strength := 1.0 - clampf(age / 1.6, 0.0, 1.0)
	var tint := FLAME if hot else Color("a4bbbc")
	for i in (8 if hot else 17):
		var direction := Vector2.from_angle(i * 2.399)
		var particle := at + direction * (age * (24.0 + i % 5 * 6.0)) - Vector2(0, age * (39.0 if hot else 10.0))
		draw_line(particle, particle + direction * (5.0 * strength), Color(tint, strength * 0.62), 1.7, true)
	if not hot:
		draw_arc(at, 11.0 + age * 61.0, 0.0, TAU, 30, Color(tint, strength * 0.34), 1.6, true)
