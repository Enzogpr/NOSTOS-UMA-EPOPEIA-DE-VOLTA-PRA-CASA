extends Node2D

const PATHS := preload("res://Ato10_Calipso/Gameplay/OgygiaPaths.gd")
const ISLAND := preload("res://Ato10_Calipso/Gameplay/OgygiaIsland.gd")
const RAFT := preload("res://Ato10_Calipso/Gameplay/RaftLaunch.gd")
const HERO_STORY := preload("res://Assets/act4_luck/odysseus_luck_poses.png")
const ATHENA := preload("res://Assets/act3_athena_farewell/athena_animatic.png")
const EURYLOCHUS := preload("res://Assets/act4_storm/eurylochus_fullbody.png")
const SOULS := preload("res://Assets/act6_underworld/souls_atlas.png")
const REEF := preload("res://Assets/act4_storm/rock_reef.png")
const OPEN_SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const SEA := preload("res://Assets/act10_calypso/ogygia_water.gdshader")
const WATER_ART := preload("res://Assets/act10_calypso/tidal_coast.png")
const VIEW := Vector2(1152, 648)
const GOLD := Color("ffe1a0")
const FOAM := Color("cceef2")

var paths: PATHS
var raft: RAFT
var mode := "story"
var shot := "wake"
var shot_age := 0.0
var return_age := 0.0
var time := 0.0
var island := ISLAND.new()
var beach_art: Texture2D
var calypso: Texture2D
var olympus: Texture2D
var kit: Texture2D
var glades: Texture2D
var sea_fill: ColorRect
var sea_material: ShaderMaterial

func _ready() -> void:
	beach_art = load("res://Assets/act10_calypso/beach.png")
	calypso = load("res://Assets/act10_calypso/calypso.png")
	olympus = load("res://Assets/act10_calypso/olympus.png")
	kit = load("res://Assets/act10_calypso/island_kit.png")
	glades = load("res://Assets/act10_calypso/wood_and_cliff.png")
	sea_fill = ColorRect.new()
	sea_fill.size = VIEW
	sea_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea_fill.show_behind_parent = true
	sea_material = ShaderMaterial.new()
	sea_material.shader = SEA
	sea_material.set_shader_parameter("sea_art", WATER_ART)
	sea_fill.material = sea_material
	add_child(sea_fill)
	island.paths = paths
	island.hide()
	add_child(island)

func update_view(delta: float, working: bool = false) -> void:
	time += delta
	shot_age += delta
	island.visible = mode == "walk"
	if island.visible:
		island.update_view(delta, working)
	sea_fill.visible = mode in ["raft", "return_current"]
	if sea_fill.visible:
		sea_material.set_shader_parameter("tide_clock", time)
		sea_material.set_shader_parameter("passage", raft.distance)
	queue_redraw()

func _draw() -> void:
	match mode:
		"story": _draw_story()
		"raft":
			if raft.phase == RAFT.Phase.SHORE: _draw_shore()
			else: _draw_channel()
		"return_current": _draw_return_current()

func _draw_shore() -> void:
	var tide_line := 308.0 + raft.tide() * (42.0 if raft.beach == RAFT.OPEN else 20.0)
	var points := PackedVector2Array()
	var foam_line := PackedVector2Array()
	var uv := PackedVector2Array()
	for index in 38:
		var x := index * VIEW.x / 37.0
		var y := tide_line + sin(index * 0.16) * 18 + sin(time * 2.0 + index * 0.3) * 4
		points.append(Vector2(x, y))
		foam_line.append(Vector2(x, y - 1))
		uv.append(Vector2(float(index) / 37.0, 0.77))
	points.append_array(PackedVector2Array([Vector2(1152, 648), Vector2(0, 648)]))
	uv.append_array(PackedVector2Array([Vector2(1, 0.99), Vector2(0, 0.99)]))
	draw_polygon(points, PackedColorArray([Color("d3b383")]), uv, beach_art)
	for ring in range(4, 0, -1):
		draw_polyline(foam_line, Color(FOAM, 0.10 + (4 - ring) * 0.12), ring * 4.0, true)
	if raft.beach == RAFT.COVE:
		for reef in [Vector3(278, 235, 115), Vector3(849, 225, 132), Vector3(933, 278, 88)]:
			_draw_reef(Vector2(reef.x, reef.y), reef.z)
	else:
		for row in 3:
			var points_at := PackedVector2Array()
			var y := 139.0 + fposmod(raft.clock * 61.0 + row * 56.0, 170)
			for index in 33:
				points_at.append(Vector2(72 + index * 31.0, y + sin(index * 0.29 + row) * 11.0))
			draw_polyline(points_at, Color(FOAM, 0.46 - row * 0.07), 2.1, true)
	var at := Vector2(576, 417)
	_draw_shore_current(at)
	_draw_raft(at, raft.angle)
	if raft.lash < 1.0:
		draw_arc(at, 72, 0.0, TAU, 55, Color(GOLD, 0.22), 2.0, true)
		if raft.lash > 0.0:
			draw_arc(at, 72, -PI / 2.0, -PI / 2.0 + raft.lash * TAU, 55, GOLD, 3.0, true)

func _draw_shore_current(launch: Vector2) -> void:
	var flow := Vector2.from_angle(float(RAFT.TARGET[raft.beach]) - PI / 2.0)
	var outward := raft.retreating()
	for side: float in [-1.0, 1.0]:
		for index in 8:
			var age := fposmod(raft.clock * (0.49 if outward else -0.37) + index * 0.137, 1.0)
			var start := launch + flow * lerpf(112.0, 324.0, age) + flow.orthogonal() * side * lerpf(22.0, 57.0, age)
			var streak := flow * (9.0 + index % 3 * 6.0)
			draw_line(start, start + streak, Color(FOAM, sin(age * PI) * (0.60 if outward else 0.32)), 2.2, true)

func _channel_project(x: float, z: float) -> Vector2:
	return Vector2(576 + x - raft.lateral * 0.20, 445 + (raft.distance - z) * 0.78)

func _draw_channel() -> void:
	_draw_receding_shore()
	for side: int in [-1, 1]:
		var edge := PackedVector2Array()
		for row in 41:
			var z := raft.distance + (445 - row * 17.0) / 0.78
			var x := raft.channel_center(z) + side * raft.channel_width(z)
			var swell := sin(z * 0.052 + time * 2.7) * 6.0 + cos(z * 0.036 - time) * 3.0
			edge.append(_channel_project(x + swell, z))
		var polygon := edge.duplicate()
		var outer := -20.0 if side < 0 else 1172.0
		polygon.append_array(PackedVector2Array([Vector2(outer, 680), Vector2(outer, 0)]))
		draw_colored_polygon(polygon, Color(0.45, 0.66, 0.50, 0.14))
		for point in range(1, edge.size()):
			var crest := pow(0.5 + 0.5 * sin(point * 0.91 + time * 2.55 + side * 2.72), 3.0)
			draw_line(edge[point - 1], edge[point], Color(FOAM, crest * 0.64), 1.1 + crest * 1.8, true)
	for reef in raft.reefs():
		var at := _channel_project(reef.x, reef.y)
		if at.y > -100 and at.y < 730:
			_draw_reef(at, reef.z * 2.15)
	for wave in raft.waves():
		var points := PackedVector2Array()
		var center := raft.channel_center(wave)
		var width := raft.channel_width(wave)
		for n in 33:
			var t := n / 32.0
			var x := center + (t * 2.0 - 1.0) * width
			var drift := sin(t * PI) * raft.wave_side(wave) * 26.0
			points.append(_channel_project(x + drift, wave + sin(n * 0.40 + time * 4.0) * 8.0))
		draw_polyline(points, Color(FOAM, 0.22), 13.0, true)
		draw_polyline(points, Color(FOAM, 0.75), 2.7, true)
	var at := _channel_project(raft.lateral, raft.distance)
	for row in 5:
		var wake := at + Vector2(-raft.side_speed * row / 59.0, 35.0 + row * 9.0)
		draw_arc(wake, 10 + row * 4, 0.18, PI - 0.18, 20, Color(FOAM, 0.55 - row * 0.091), 1.7, true)
	_draw_rower(at, raft.angle)

func _draw_receding_shore() -> void:
	var distance_ratio := clampf(raft.distance / raft.finish_distance(), 0.0, 1.0)
	var visible_shore := 1.0 - smoothstep(0.36, 0.86, distance_ratio)
	if visible_shore <= 0.0:
		return
	var scale_factor := lerpf(1.0, 0.15, smoothstep(0.0, 0.84, distance_ratio))
	var size := Vector2(548, 320) * scale_factor
	var at := Vector2(lerpf(114.0, 25.0, distance_ratio), 14 + sin(time * 1.7) * 2.4) - size * Vector2(0.48, 0.20)
	for row in 4:
		for column in 8:
			var uv := PackedVector2Array([
				Vector2(column / 8.0, row / 4.0), Vector2((column + 1) / 8.0, row / 4.0),
				Vector2((column + 1) / 8.0, (row + 1) / 4.0), Vector2(column / 8.0, (row + 1) / 4.0),
			])
			var quad := PackedVector2Array()
			var colors := PackedColorArray()
			var source := PackedVector2Array()
			for point in uv:
				quad.append(at + size * point)
				source.append(Vector2(point.x * 0.73, 0.03 + point.y * 0.64))
				var edge := (1.0 - smoothstep(0.37, 1.0, point.x)) * (1.0 - smoothstep(0.48, 1.0, point.y))
				colors.append(Color(0.85, 0.94, 0.90, visible_shore * edge))
			draw_polygon(quad, colors, source, ISLAND.HARBOR)

func _draw_return_current() -> void:
	_draw_channel()
	var veil := smoothstep(0.1, 1.82, return_age)
	var reunion := smoothstep(1.84, 4.32, return_age)
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.48, 0.66, 0.69, veil * 0.89))
	for index in 8:
		var y := 89.0 + index * 47.0 + sin(time * 1.3 + index) * 14.0
		draw_rect(Rect2(0, y, 1152, 49), Color(0.78, 0.86, 0.83, veil * (1.0 - reunion) * 0.037))
	if reunion > 0.0:
		var size := VIEW * lerpf(1.14, 1.0, reunion)
		draw_texture_rect(ISLAND.HARBOR, Rect2((VIEW - size) * 0.5, size), false, Color(0.78, 0.88, 0.90, reunion))
		var land := smoothstep(3.08, 5.98, return_age)
		if return_age > 3.08:
			var at := Vector2(729, 259).lerp(Vector2(577, 349), land)
			_draw_rower(at, lerpf(-0.18, 1.55, land), lerpf(0.47, 0.67, land), 1.0 - smoothstep(5.2, 6.1, return_age))

func _draw_rower(at: Vector2, angle: float, scale_factor: float = 1.0, opacity: float = 1.0) -> void:
	var rocking := sin(time * 4.0) * 2.0
	draw_set_transform(at + Vector2(0, rocking), angle - PI / 2.0, Vector2.ONE * scale_factor)
	_draw_kit(0, Rect2(-74, -50, 148, 100), Color(1, 1, 1, opacity))
	draw_set_transform(at + Vector2(0, rocking), 0.0, Vector2.ONE * scale_factor)
	_portrait(HERO_STORY, Rect2(559, 37, 442, 463), Vector2(0, 10), 48, Color(0.91, 0.91, 0.84, opacity))
	var stroke := sin(time * (3.4 + raft.speed / 108.0))
	draw_set_transform(at + Vector2(15, -11 + rocking) * scale_factor, 0.83 + stroke * 0.49 + angle * 0.56, Vector2.ONE * scale_factor)
	ISLAND.draw_oar(self, Rect2(-80, -9, 96, 20), 0, Color(1, 1, 1, opacity))
	draw_set_transform(Vector2.ZERO)

func _draw_reef(at: Vector2, width: float) -> void:
	var dims := Vector2(width, width * 0.76)
	draw_texture_rect_region(REEF, Rect2(at - dims * 0.5, dims), Rect2(69, 210, 1126, 865), Color("b6c8be"))

func _draw_raft(at: Vector2, angle: float) -> void:
	draw_set_transform(at + Vector2(3, 5), angle - PI / 2.0, Vector2(1, 0.46))
	draw_circle(Vector2.ZERO, 57, Color(0.08, 0.13, 0.13, 0.38))
	draw_set_transform(at + Vector2(0, sin(time * 4.0) * 2), angle - PI / 2.0)
	_draw_kit(0, Rect2(-74, -50, 148, 100))
	draw_set_transform(Vector2.ZERO)

func _draw_story() -> void:
	var at_olympus := shot.begins_with("olympus")
	var at_cliff := shot.begins_with("cliff") or shot == "ridge"
	var image: Texture2D = olympus if at_olympus else OPEN_SEA if shot == "hermes" else ISLAND.WORKBENCH if shot == "bench_return" else ISLAND.HARBOR
	var dims := Vector2(1198, 798) * (1.0 + minf(shot_age, 5.0) * 0.012)
	var tint := Color("829997") if shot in ["wake", "return"] else Color("66788f") if at_cliff else Color.WHITE
	var pan := Vector2(sin(time * 0.36) * 12, -19 if at_cliff else 13)
	if at_cliff:
		var region := Rect2(0, glades.get_height() * 0.5, glades.get_width(), glades.get_height() * 0.5)
		draw_texture_rect_region(glades, Rect2(-30 + pan.x, -12, 1212, 672), region, tint)
	else:
		draw_texture_rect(image, Rect2((VIEW - dims) * 0.5 + pan, dims), false, tint)
	var drift := Vector2(sin(time * 1.2) * 2.2, cos(time * 1.35) * 2)
	match shot:
		"bench_return":
			_draw_bench_reunion(drift)
		"olympus", "olympus_judgment", "olympus_release":
			var trial := shot == "olympus_judgment"
			if trial:
				var flash := 0.24 * exp(-shot_age * 5.2)
				draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.38, 0.21, 0.57, 0.27))
				draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.77, 0.80, 1.0, flash))
			var at := Vector2(371, 611) if shot == "olympus" else Vector2(462, 643)
			_portrait(ATHENA, Rect2(97, 4, 418, 622), at + drift, 454 if shot == "olympus" else 515, Color("bec6e8") if trial else Color("e4e9ff"))
		"cliff", "cliff_memory", "cliff_call", "ridge":
			_draw_cliff_acting(drift)
		"hermes":
			var bob := sin(time * 2.0) * 6.0
			_draw_kit(0, Rect2(-410 + drift.x, 64 + bob, 1060, 640), Color("b2bdbe"))
			_portrait(HERO_STORY, Rect2(559, 37, 442, 463), Vector2(309 + drift.x, 532 + bob), 374, Color("e8dbc8"))
			var hover := sin(time * 1.7) * 8.0
			_draw_kit(1, Rect2(604 + drift.x, 57 + hover, 465, 457), Color("ebe4cc"))
			for ring in 3:
				draw_set_transform(Vector2(829, 515 + hover + ring * 9), 0, Vector2(1, 0.21))
				draw_arc(Vector2.ZERO, 58 + ring * 13, 0.24, PI - 0.16, 32, Color(FOAM, 0.55 - ring * 0.15), 2.0, true)
			draw_set_transform(Vector2.ZERO)
		_:
			var refusing := shot == "refusal"
			var hero_pose := Rect2(559, 37, 442, 463) if refusing else Rect2(86, 524, 350, 462)
			_portrait(HERO_STORY, hero_pose, Vector2(269, 616) + drift if refusing else Vector2(315, 596) + drift, 453 if refusing else 397, Color("c9cebd") if shot in ["wake", "return"] else Color.WHITE)
			_portrait(calypso, Rect2(Vector2.ZERO, calypso.get_size()), Vector2(753, 604) - drift if refusing else Vector2(785, 591) - drift, 485 if refusing else 435, Color("d8ebd3"))
	for row in 38:
		draw_rect(Rect2(0, 648 - row * 5, 1152, 6), Color(0.035, 0.057, 0.07, 0.13 * (1.0 - row / 38.0)))

func _draw_cliff_acting(drift: Vector2) -> void:
	var memory := shot == "cliff_memory"
	if memory:
		var fade := smoothstep(0.0, 1.05, shot_age)
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.08, 0.19, 0.34 * fade))
		_portrait(EURYLOCHUS, Rect2(Vector2.ZERO, EURYLOCHUS.get_size() * 0.5), Vector2(649, 517) + drift, 410, Color(0.61, 0.70, 0.76, fade * 0.50))
		_portrait(SOULS, Rect2(986, 8, 382, 500), Vector2(896, 475) - drift, 366, Color(0.73, 0.86, 0.96, fade * 0.45))
	if shot == "cliff":
		_portrait(calypso, Rect2(Vector2.ZERO, calypso.get_size()), Vector2(798, 562) - drift, 370, Color("9db5bc"))
	var close := shot == "cliff_call"
	var size := 504.0 + smoothstep(0.0, 2.0, shot_age) * 23.0 if close else 373.0
	_portrait(HERO_STORY, Rect2(1086, 526, 384, 463), Vector2(423, 678) + drift if close else Vector2(312, 592) + drift, size, Color("bac4d5"))

func _draw_bench_reunion(drift: Vector2) -> void:
	var tint := Color("d8d9b7")
	var bounds := Rect2(Vector2.ZERO, VIEW)
	draw_texture_rect(ISLAND.WORKBENCH, bounds, false, tint)
	_portrait(calypso, Rect2(Vector2.ZERO, calypso.get_size()), Vector2(707, 548) - drift, 459, Color("d9dfc8"))
	var tabletop := Rect2(0, 251, VIEW.x, VIEW.y - 251)
	var source_scale := ISLAND.WORKBENCH.get_size() / VIEW
	draw_texture_rect_region(ISLAND.WORKBENCH, tabletop, Rect2(tabletop.position * source_scale, tabletop.size * source_scale), tint)
	ISLAND.draw_oar(self, Rect2(205, 312, 739, 157), 1)

func _portrait(texture: Texture2D, region: Rect2, feet: Vector2, height: float, tint: Color) -> void:
	var width := height * region.size.x / region.size.y
	draw_texture_rect_region(texture, Rect2(feet - Vector2(width * 0.5, height), Vector2(width, height)), region, tint)

func _draw_kit(index: int, rect: Rect2, tint := Color.WHITE) -> void:
	var cell := kit.get_size() / 2.0
	var region := Rect2(Vector2(index % 2, 0 if index < 2 else 1) * cell, cell)
	draw_texture_rect_region(kit, rect, region, tint)

