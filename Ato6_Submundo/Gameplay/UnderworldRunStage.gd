extends Node2D
## Projects the authored route onto the 2D stage from a camera behind Odisseu.
const MODEL := preload("res://Ato6_Submundo/Gameplay/UnderworldCrossingModel.gd")
const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const BACKDROP := preload("res://Assets/act6_underworld/oracle_lake.png")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const SOULS := preload("res://Assets/act6_underworld/souls_atlas.png")
const RUINS := preload("res://Assets/act6_underworld/river_ruins.png")
const SLIDE := preload("res://Assets/act6_underworld/odysseus_slide.png")
const ARCH := Rect2(112, 4, 527, 499)
const COLUMN := Rect2(842, 164, 621, 334)
const ROCK := Rect2(20, 576, 717, 409)
const LINTEL_STONE := Rect2(180, 151, 396, 51)
const LINTEL_POST := Rect2(188, 220, 83, 218)
const DEAD := Rect2(105, 15, 552, 490)
const MOTHER := Rect2(986, 8, 382, 500)
const FRAME := Vector2(1152, 648)
const NEAR := -6.0
const FAR := 235.0

var model: MODEL
var dash_bar := DASH_RECHARGE_BAR.new()
var pursuit_lane := 0.0

func _ready() -> void:
	add_child(dash_bar)

func update_visuals(delta: float) -> void:
	pursuit_lane = lerpf(pursuit_lane, model.lane, 1.0 - exp(-delta * 2.4))
	dash_bar.update_at(_hero_feet(), model.dash_recharge, model.dash_cooldown, model.phase == MODEL.Phase.ACTIVE)
	queue_redraw()

func snap_camera() -> void:
	pursuit_lane = model.lane
	update_visuals(0.0)

func _depth(gap: float) -> float:
	return 20.0 / (20.0 + maxf(NEAR, model.apparent_gap(gap)))

func _at(gap: float, lane: float) -> Vector2:
	var depth := _depth(gap)
	var bend := (sin((model.distance + gap) * 0.034) - sin(model.distance * 0.034)) * (35.0 + model.stretch * 100.0)
	var drift := sin(model.clock * 1.8 + gap * 0.028) * 24.0 * model.stretch * smoothstep(5.0, 74.0, gap)
	var road_width := lerpf(1.0, 0.26, smoothstep(MODEL.FINISH - 24.0, MODEL.FINISH, model.distance + gap))
	return Vector2(576.0 + lane * 222.0 * depth * road_width + bend * (1.0 - minf(depth, 1.0)) + drift, 221.0 + depth * 307.0)

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)

func _band(near: float, far: float, left: float, right: float, color: Color) -> void:
	_quad(_at(far, left), _at(far, right), _at(near, right), _at(near, left), color)

func _sprite(texture: Texture2D, region: Rect2, foot: Vector2, height: float, tint := Color.WHITE) -> void:
	var dimensions := region.size * (height / region.size.y)
	draw_texture_rect_region(texture, Rect2(foot - dimensions * Vector2(0.5, 0.97), dimensions), region, tint)

func _draw() -> void:
	if model == null:
		return
	var offset := sin(model.distance * 0.009) * 13.0
	draw_texture_rect(BACKDROP, Rect2(Vector2(-19 + offset, -8), FRAME + Vector2(38, 16)), false, Color(0.71, 0.79, 0.82))
	var mist := Color(0.05, 0.15, 0.18, 0.11 + model.stretch * 0.17)
	draw_rect(Rect2(Vector2.ZERO, FRAME), mist)
	_draw_road()
	var foreground_beams := _draw_route_props()
	_draw_chase()
	for beam in foreground_beams:
		_draw_lintel(beam)
	if model.stumble_time > 0.0:
		var hit := Color(0.35, 0.08, 0.05, model.stumble_time * 0.24)
		draw_rect(Rect2(Vector2.ZERO, FRAME), hit)

func _draw_road() -> void:
	var road_end := minf(FAR, MODEL.FINISH + 4.0 - model.distance)
	var edge := Color("657372")
	var stone := Color("394748")
	var first := floori((model.distance + NEAR) / 7.0)
	var last := floori((model.distance + road_end) / 7.0)
	for slab in range(last, first - 1, -1):
		var near := maxf(NEAR, slab * 7.0 - model.distance)
		var far := minf(road_end, (slab + 1) * 7.0 - model.distance)
		if far - near < 0.001:
			continue
		_band(near, far, -1.57, 1.57, edge.darkened(float(slab % 3) * 0.07))
		for lane in 3:
			var left := -1.5 + lane
			var shade := stone.lightened(float(posmod(slab * 23 + lane * 13, 7)) * 0.014)
			_band(near, far, left + 0.009, left + 0.991, shade)
			if slab % 2 == 0:
				var seam := left + (0.43 if lane % 2 == 0 else 0.58)
				draw_line(_at(near, seam), _at(far, seam + 0.035), Color(0.10, 0.17, 0.19, 0.28), maxf(1.0, _depth(near) * 1.3))
		var joint := Color(0.11, 0.19, 0.21, 0.60)
		draw_line(_at(far, -1.50), _at(far, 1.50), joint, maxf(1.0, 1.9 * _depth(far)))
		if slab % 2 == 0:
			for line in [-0.5, 0.5]:
				draw_line(_at(near, line), _at(far, line), Color(0.63, 0.82, 0.77, 0.40), maxf(1.0, 2.4 * _depth(near)))

func _draw_route_props() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var foreground_beams: Array[Dictionary] = []
	for index in range(maxi(0, model.next_obstacle - 1), MODEL.COURSE.size()):
		var row: Array = MODEL.COURSE[index]
		var gap := float(row[0]) - model.distance
		if gap > FAR:
			break
		if gap < NEAR:
			continue
		if row[2] == MODEL.Obstacle.LINTEL:
			var first := -1
			for slot in 4:
				if slot < 3 and (int(row[1]) & (1 << slot)) != 0:
					if first < 0: first = slot
				elif first >= 0:
					var beam := {"gap": gap, "lane": (first + slot) * 0.5 - 1.5,
						"left": first - 1.45, "right": slot - 1.55, "kind": MODEL.Obstacle.LINTEL}
					if gap <= 0.0: foreground_beams.append(beam)
					else: props.append(beam)
					first = -1
			continue
		for lane in 3:
			if (int(row[1]) & (1 << lane)) != 0:
				props.append({"gap": gap, "lane": lane - 1, "kind": row[2]})
	for index in range(floori(model.distance / 33.0), ceili((model.distance + FAR) / 33.0)):
		var gap := index * 33.0 + 11.0 - model.distance
		if gap < NEAR or gap > FAR or model.distance + gap >= MODEL.FINISH - 30.0:
			continue
		var lane := (1.85 + (index % 3) * 0.10) * (-1.0 if index % 2 == 0 else 1.0)
		props.append({"gap": gap, "lane": lane, "kind": "shore", "index": index})
	for arch in MODEL.FALSE_ARCHES:
		var gap: float = arch - model.distance
		if gap > 0.0 and gap < FAR:
			props.append({"gap": gap, "lane": 0.0, "kind": "echo"})
	for checkpoint in MODEL.CHECKPOINTS.slice(1):
		var gap: float = checkpoint - model.distance
		if gap >= 0.0 and gap < FAR:
			props.append({"gap": gap, "lane": -1.69, "kind": "lantern"})
	var finish := MODEL.FINISH - model.distance
	if finish <= FAR:
		props.append({"gap": finish, "lane": 0.0, "kind": "exit"})
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap > b.gap)
	for prop in props:
		var gap: float = prop.gap
		var at := _at(gap, float(prop.lane))
		var depth := _depth(gap)
		match prop.kind:
			MODEL.Obstacle.DEBRIS:
				_band(maxf(NEAR, gap - 1.35), gap + 1.4, prop.lane - 0.43, prop.lane + 0.43, Color(0.85, 0.62, 0.32, 0.31))
				_sprite(RUINS, ROCK, at, 77.0 * depth, Color("b1bebb"))
			MODEL.Obstacle.PILLAR:
				_band(maxf(NEAR, gap - 1.35), gap + 1.4, prop.lane - 0.43, prop.lane + 0.43, Color(0.72, 0.29, 0.17, 0.47))
				_sprite(RUINS, COLUMN, at, 144.0 * depth, Color("c4b5a1"))
			MODEL.Obstacle.LINTEL:
				_band(gap - 1.4, gap + 1.5, prop.left, prop.right, Color(0.30, 0.67, 0.64, 0.24))
				_draw_lintel(prop)
			"shore":
				var region := COLUMN if int(prop.index) % 3 == 0 else ROCK
				_sprite(RUINS, region, at, (128.0 + (int(prop.index) % 4) * 23.0) * depth, Color(0.51, 0.68, 0.69, 0.90))
			"lantern":
				_draw_lantern(at, depth)
			"echo":
				var opacity := smoothstep(3.0, 27.0, gap) * (0.79 + sin(model.clock * 4.5) * 0.13)
				_sprite(RUINS, ARCH, at, 224.0 * depth, Color(0.56, 0.84, 0.88, opacity))
			"exit":
				var glow := at - Vector2(0, 112.0 * depth)
				draw_circle(glow, 102.0 * depth, Color(1.0, 0.74, 0.37, 0.12))
				draw_circle(glow, 69.0 * depth, Color(1.0, 0.86, 0.57, 0.18))
				_sprite(RUINS, ARCH, at, 240.0 * depth, Color("ffe4b9"))
	return foreground_beams

func _draw_lintel(prop: Dictionary) -> void:
	var gap: float = prop.gap
	var depth := _depth(gap)
	var left := _at(gap, prop.left)
	var right := _at(gap, prop.right)
	var clearance := 91.0 * depth
	var height := 34.0 * depth
	var post_width := 21.0 * depth
	for foot in [left, right]:
		var post := Rect2(foot.x - post_width * 0.5, foot.y - clearance - 5.0 * depth,
			post_width, clearance + 5.0 * depth)
		draw_texture_rect_region(RUINS, post, LINTEL_POST, Color("a7b7b4"))
		var base := Rect2(foot.x - post_width * 0.66, foot.y - 5.0 * depth, post_width * 1.32, 5.0 * depth)
		draw_texture_rect_region(RUINS, base, LINTEL_STONE, Color("768f89"))
	var beam := Rect2(left.x - post_width * 0.65, left.y - clearance - height,
		right.x - left.x + post_width * 1.3, height)
	var blocks := maxi(1, roundi((float(prop.right) - float(prop.left)) * 2.0))
	for i in blocks:
		var width := beam.size.x / blocks
		var block := Rect2(beam.position + Vector2(i * width, 0), Vector2(width + 0.4, beam.size.y))
		draw_texture_rect_region(RUINS, block, LINTEL_STONE, Color("b8c8bf") if i % 2 == 0 else Color("9caea8"))

func _draw_lantern(at: Vector2, depth: float) -> void:
	var fire := at - Vector2(0, 66.0 * depth)
	draw_line(at, fire, Color("705c49"), 5.0 * depth)
	draw_circle(fire, 32.0 * depth, Color(1.0, 0.74, 0.37, 0.14))
	draw_circle(fire, 11.0 * depth, Color("e1aa55"))
	draw_circle(fire, 5.0 * depth, Color("fff1b8"))

func _hero_feet() -> Vector2:
	var ground := _at(0.0, model.lane)
	if model.phase != MODEL.Phase.ACTIVE or model.slide_time > 0.0:
		return ground
	var step := sin(model.distance * 0.73) * 3.0
	return ground - Vector2(0, model.jump_height() * 94.0 + step)

func _draw_chase() -> void:
	var hero_foot := _at(0.0, model.lane)
	var rest := model.phase in [MODEL.Phase.REST, MODEL.Phase.MEMORY]
	var moving := model.phase == MODEL.Phase.ACTIVE
	if rest:
		_sprite(SOULS, MOTHER, _at(2.0, -0.94), 173.0, Color("ffe8c3"))
	elif model.phase != MODEL.Phase.COMPLETE:
		var approach := model.pressure / 100.0
		var group_foot := Vector2(576.0 + pursuit_lane * 141.0, lerpf(692.0, 590.0, approach))
		var glow := group_foot - Vector2(0, 48.0)
		draw_circle(glow, 119.0 + approach * 41.0, Color(0.24, 0.73, 0.72, 0.08 + approach * 0.13))
		for side in [-1, 1]:
			var drift := sin(model.clock * 3.2 + side) * 9.0
			var at := group_foot + Vector2(side * lerpf(163.0, 94.0, approach) + drift, side * 9.0)
			_sprite(SOULS, DEAD, at, 181.0 + approach * 46.0, Color(0.69, 0.97, 1.0, 0.39 + approach * 0.39))
	var lift := model.jump_height() * 94.0
	var animation: int = [1, 0, 2, 0][posmod(int(model.distance * 0.5), 4)] if moving else 0
	if lift > 10.0:
		animation = 1
	var frame := HERO.get_size() / 4.0
	var height := 147.0 if model.stumble_time == 0.0 else 130.0
	draw_set_transform(hero_foot + Vector2(0, 1), 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, lerpf(39.0, 22.0, lift / 94.0), Color(0.01, 0.05, 0.06, 0.72))
	draw_set_transform(Vector2.ZERO)
	var tint := Color("ffd2b7") if model.stumble_time > 0.0 else Color.WHITE
	if moving and model.slide_time > 0.0:
		_draw_slide(hero_foot, tint)
		return
	_sprite(HERO, Rect2(Vector2(animation, 1) * frame, frame), _hero_feet(), height, tint)

func _draw_slide(foot: Vector2, tint: Color) -> void:
	var elapsed := MODEL.SLIDE_DURATION - model.slide_time
	var dust := smoothstep(0.0, 0.11, elapsed) * smoothstep(0.0, 0.16, model.slide_time)
	for i in 8:
		var trail := fposmod(elapsed * 3.7 + i * 0.41, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := foot + Vector2(side * (17.0 + trail * 29.0), 2.0 + trail * 30.0)
		var alpha := dust * (1.0 - trail) * 0.5
		draw_line(at, at + Vector2(side * (5.0 + 11.0 * trail), 5.0 + 8.0 * trail), Color(0.66, 0.77, 0.72, alpha), 1.4, true)
	var index := 0 if elapsed < 0.08 else 1 if elapsed < 0.31 else 2 if elapsed < 0.52 else 3
	var cell := SLIDE.get_size() * 0.5
	var region := Rect2(Vector2(index % 2, index >> 1) * cell, cell)
	_sprite(SLIDE, region, foot, 132.0, tint)
