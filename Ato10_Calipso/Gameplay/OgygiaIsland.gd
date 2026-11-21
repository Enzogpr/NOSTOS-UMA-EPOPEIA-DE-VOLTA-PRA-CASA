extends Node2D

const PATHS := preload("res://Ato10_Calipso/Gameplay/OgygiaPaths.gd")
const HARBOR := preload("res://Assets/act10_calypso/ogygia_harbor.png")
const WORKBENCH := preload("res://Assets/act10_calypso/ogygia_workbench.png")
const OAR := preload("res://Assets/act10_calypso/odysseus_oar.png")
const HANDS := preload("res://Assets/act10_calypso/oar_hands.png")
const RIDGE := preload("res://Assets/act10_calypso/wood_and_cliff.png")
const CALYPSO := preload("res://Assets/act10_calypso/calypso.png")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const WRECK := preload("res://Assets/act4_poseidon_escape/platform_wrecks.png")
const KIT := preload("res://Assets/act10_calypso/island_kit.png")
const VIEW := Vector2(1152, 648)
const WORKING_OAR := Rect2(205, 329, 739, 163)
const FOAM := Color("ddf0e4")

var paths: PATHS
var clock := 0.0
var footstep := 0.0
var work_motion := 0.0

func update_view(delta: float, working: bool) -> void:
	clock += delta
	footstep += paths.velocity.length() * delta / 20.0
	var motion := paths.can_work() and (working or paths.time_cut > 0.0)
	work_motion = move_toward(work_motion, 1.0 if motion else 0.0, delta * 5.0)
	queue_redraw()

func _draw() -> void:
	match paths.place:
		PATHS.Place.SHORE: _draw_shore()
		PATHS.Place.BENCH: _draw_bench()
		PATHS.Place.HEADLAND: _draw_headland()

func _light() -> Color:
	var seasons := paths.seasons
	var tint := Color("fff2dd").lerp(Color("d6dfa9"), smoothstep(0.0, 2.6, seasons))
	return tint.lerp(Color("9da9ca"), smoothstep(3.1, 7.0, seasons))

func _draw_shore() -> void:
	var light := _light()
	draw_texture_rect(HARBOR, Rect2(Vector2.ZERO, VIEW), false, light)
	_draw_surf()
	var wreck := PATHS.WRECK
	_ground_shadow(wreck + Vector2(1, -3), 57.0, 0.30)
	draw_texture_rect_region(WRECK, Rect2(wreck - Vector2(65, 44), Vector2(130, 58)), Rect2(8, 664, 742, 263), light)
	if paths.beat == PATHS.Beat.SALVAGE:
		draw_texture_rect_region(OAR, Rect2(wreck - Vector2(13, 8), Vector2(45, 21)), Rect2(36, 98, 311, 188), Color("dab287"))
	elif paths.beat in [PATHS.Beat.CAST, PATHS.Beat.DRIFT, PATHS.Beat.RECOVER]:
		if paths.beat != PATHS.Beat.CAST:
			_draw_floater()
	elif paths.beat == PATHS.Beat.LAUNCH:
		var box := Rect2(739, 399, 123, 83)
		draw_texture_rect_region(KIT, box, Rect2(Vector2.ZERO, KIT.get_size() * 0.5), light)
	var calypso_at := PATHS.CALYPSO
	if paths.beat == PATHS.Beat.REUNION and paths.told_calypso:
		calypso_at = paths.reunion_position()
	if paths.beat not in [PATHS.Beat.REPAIR, PATHS.Beat.HEADLAND]:
		_draw_calypso(calypso_at, light)
	if paths.beat == PATHS.Beat.REUNION and paths.told_calypso:
		draw_oar(self, Rect2(calypso_at + Vector2(-53, 13), Vector2(106, 23)), 1, light)
	_draw_hero(light)

func _draw_surf() -> void:
	for side in 2:
		var at: Vector2 = PATHS.CURRENTS[side]
		for trail in 7:
			var u := fposmod(clock * (0.36 + 0.08 * side) + trail * 0.159, 1.0)
			var shift := lerpf(-37.0, 26.0, trail / 6.0)
			var p := at + Vector2(shift + sin(u * 2.4) * (side * 2 - 1) * 23.0, -117 + u * 78.0)
			draw_line(p, p + Vector2(19.0 + u * 19.0, -3.0), Color(FOAM, sin(u * PI) * 0.31), 1.55, true)
	for index in 16:
		var u := fposmod(clock * 0.26 + index * 0.16, 1)
		var x := 448.0 + index * 33.0
		var y := 377.0 - smoothstep(448.0, 979.0, x) * 61.0 - u * 13.0
		draw_line(Vector2(x, y), Vector2(x + 19 + u * 7, y - u * 2), Color(FOAM, sin(u * PI) * 0.22), 1.55, true)

func _draw_floater() -> void:
	var at := paths.marker_position()
	var fade := 1.0 - smoothstep(2.82, 3.50, paths.drift_age) + smoothstep(3.50, 4.14, paths.drift_age)
	if fade <= 0.0:
		return
	var away := maxf(0.0, 1.0 - absf(paths.drift_age - 3.5) / 3.5)
	var dims := Vector2(39, 20) * lerpf(1.0, 0.39, away)
	draw_texture_rect_region(OAR, Rect2(at - dims * 0.5, dims), Rect2(40, 103, 285, 166), Color(1.0, 0.82, 0.63, fade))
	if paths.beat == PATHS.Beat.DRIFT:
		draw_arc(at + Vector2(0, 7), dims.x * 0.43, 0.23, PI - 0.2, 17, Color(FOAM, fade * 0.61), 1.4, true)

func _draw_headland() -> void:
	var slice := Rect2(0, RIDGE.get_height() * 0.5, RIDGE.get_width(), RIDGE.get_height() * 0.5)
	draw_texture_rect_region(RIDGE, Rect2(Vector2.ZERO, VIEW), slice, Color("929fbb"))
	for index in 9:
		var u := fposmod(clock * (0.42 + index * 0.027) + 0.14 * index, 1.0)
		var at := Vector2(29 + u * 1190, 178 + fposmod(index * 63.41, 360))
		draw_line(at, at - Vector2(23 + index % 3 * 13, 3), Color(0.78, 0.87, 0.96, sin(u * PI) * 0.24), 1.4, true)
	_draw_hero(Color("c3cade"))

func _draw_calypso(at: Vector2, tint: Color) -> void:
	var height := 103.0 + sin(clock * 2.0) * 1.1
	var size := Vector2(height * CALYPSO.get_width() / CALYPSO.get_height(), height)
	_ground_shadow(at, 16.0, 0.31)
	draw_texture_rect(CALYPSO, Rect2(at - size * Vector2(0.5, 0.97), size), false, tint)

func _ground_shadow(at: Vector2, radius: float, opacity: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, radius, Color(0.17, 0.12, 0.10, opacity))
	draw_set_transform(Vector2.ZERO)

func _draw_hero(tint: Color) -> void:
	var at := paths.position
	var facing := paths.facing
	var regional_row := 1 if facing.y < -0.55 else 0 if facing.y > 0.55 else 2
	var frame: int = [0, 1, 0, 2][posmod(int(footstep), 4)] if paths.velocity.length() > 12.0 else 0
	var cell := HERO.get_size() / 4.0
	_ground_shadow(at, 23.0, 0.35)
	draw_set_transform(at, 0.0, Vector2(-1 if regional_row == 2 and facing.x < 0.0 else 1, 1))
	draw_texture_rect_region(HERO, Rect2(-53, -101, 106, 106), Rect2(Vector2(frame, regional_row) * cell, cell), tint)
	draw_set_transform(Vector2.ZERO)

func _draw_bench() -> void:
	draw_texture_rect(WORKBENCH, Rect2(Vector2.ZERO, VIEW), false, _light())
	_draw_season()
	var raw := paths.oar_condition < 0
	var form := smoothstep(0.07, 0.82, paths.work) if raw else 1.0
	var strain := work_motion * (0.5 + 0.5 * sin(clock * 6.5))
	var oar_at := WORKING_OAR
	oar_at.position += Vector2(strain * 3.2, strain * 0.7)
	if raw and form < 1.0:
		draw_texture_rect_region(OAR, Rect2(258, 350, 503, 119), Rect2(37, 95, 312, 183), Color(0.66, 0.43, 0.23, 1.0 - form))
	if form > 0.0:
		draw_oar(self, oar_at, maxi(0, paths.oar_condition), Color(1, 1, 1, form))
	_draw_hands(strain)
	if paths.oar_condition < 2:
		_draw_shavings(strain, raw)
	if paths.time_cut > 0.0:
		var flicker := pow(maxf(0.0, sin(paths.seasons * PI * 1.6)), 8.0)
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.94, 0.80, 0.62, flicker * 0.105))

func _draw_season() -> void:
	var seasons := paths.seasons
	for mark in mini(7, floori(seasons + 0.001)):
		var at := Vector2(545 + mark * 11, 205 + sin(mark * 2.7) * 3.7)
		draw_line(at + Vector2(3, 0), at + Vector2(-1, 14 + mark % 3 * 2), Color("2b241f"), 2.15, true)
		draw_line(at + Vector2(5, 0), at + Vector2(1, 14 + mark % 3 * 2), Color(0.90, 0.75, 0.56, 0.45), 1.1, true)
	var rain := pow(maxf(0.0, sin(seasons * 2.01 - 0.77)), 2.0) * smoothstep(0.0, 1.3, seasons)
	var petals := 1.0 - smoothstep(0.2, 4.4, seasons)
	for index in 18:
		var u := fposmod(clock * 0.58 + index * 0.138, 1.0)
		var x := 233.0 + fposmod(index * 47.7 + u * 22.0, 241.0)
		var y := 39.0 + fposmod(index * 31.7 + u * 73.0, 146.0)
		draw_line(Vector2(x, y), Vector2(x - 5, y + 13), Color(0.68, 0.78, 0.88, rain * 0.46), 1.4, true)
		draw_circle(Vector2(x, y), 1.75 + index % 3, Color(0.96, 0.68, 0.51, petals * 0.39 * sin(u * PI)))

func _draw_hands(strain: float) -> void:
	var visible_motion := 1.0 if paths.beat != PATHS.Beat.LEAVE_TOOLS else 0.0
	var arm_y := lerpf(664.0, 500.0, work_motion * visible_motion)
	var cell := Vector2(HANDS.get_width() * 0.5, HANDS.get_height())
	var hand_size := Vector2(191, 255)
	draw_texture_rect_region(HANDS, Rect2(Vector2(548, arm_y - 72.0 - strain * 6), hand_size), Rect2(Vector2.ZERO, cell))
	draw_texture_rect_region(HANDS, Rect2(Vector2(791 - strain * 24.0, arm_y - 114.0 - strain * 11), hand_size), Rect2(Vector2(cell.x, 0), cell))

func _draw_shavings(strain: float, raw: bool) -> void:
	var tint := Color("cba878") if raw else Color("a77059")
	for index in ceili(paths.work * 19.0):
		var u := index * 0.71 + strain * 0.3 * float(index % 3)
		var x := 280.0 + fposmod(index * 47.1, 490.0)
		var y := 440.0 + fposmod(index * 12.2, 49.0)
		draw_arc(Vector2(x, y), 2.6 + index % 4, u, u + 1.9, 6, tint, 1.6, true)

static func draw_oar(canvas: CanvasItem, at: Rect2, condition: int, tint := Color.WHITE) -> void:
	var row_height := OAR.get_height() / 3.0
	var region := Rect2(0, clampi(condition, 0, 2) * row_height, OAR.get_width(), row_height)
	canvas.draw_texture_rect_region(OAR, at, region, tint)
