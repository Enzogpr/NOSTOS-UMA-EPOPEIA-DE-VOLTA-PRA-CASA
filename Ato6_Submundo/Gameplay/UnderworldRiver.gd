extends Node2D

const BANK := preload("res://Assets/act6_underworld/river_bank.png")
const MIST := preload("res://Assets/act6_underworld/river_mist.gdshader")
const WATER := preload("res://Assets/act6_underworld/river_water.gdshader")
const VIEW := Vector2(1152, 648)
const FLOOR_TILE := Vector2(510, 236)

var model: RefCounted
var camera := Vector2.ZERO
var ground_texture: ImageTexture
var wisp_texture: GradientTexture2D
var water_material: ShaderMaterial
var ground_uvs: Array[PackedVector2Array] = []
var shores: Array[Vector4] = []
var mist_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var background := BANK.get_image()
	ground_texture = ImageTexture.create_from_image(background.get_region(Rect2i(214, 574, 1018, 424)))
	var water := ColorRect.new()
	water.size = VIEW
	water.show_behind_parent = true
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_material = ShaderMaterial.new()
	water_material.shader = WATER
	water_material.set_shader_parameter("reflections", ImageTexture.create_from_image(background.get_region(Rect2i(105, 277, 1170, 102))))
	water.material = water_material
	add_child(water)
	wisp_texture = GradientTexture2D.new()
	wisp_texture.fill = GradientTexture2D.FILL_RADIAL
	wisp_texture.fill_from = Vector2(0.5, 0.5)
	wisp_texture.fill_to = Vector2(1.0, 0.5)
	wisp_texture.gradient = Gradient.new()
	wisp_texture.gradient.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	for bank: PackedVector2Array in model.banks:
		var uv := PackedVector2Array()
		for point in bank:
			uv.append(point / FLOOR_TILE)
		ground_uvs.append(uv)
		for i in bank.size():
			var start := bank[i]
			var end := bank[(i + 1) % bank.size()]
			var direction := start.direction_to(end)
			var outward := Vector2(direction.y, -direction.x)
			var segments := ceili(start.distance_to(end) / 20.0)
			for step in segments:
				var a := start.lerp(end, float(step) / segments)
				var b := start.lerp(end, float(step + 1) / segments)
				if not model.on_ground((a + b) * 0.5 + outward * 3.0):
					shores.append(Vector4(a.x, a.y, b.x, b.y))

func add_mist(parent: Node, density: float) -> void:
	var plane := ColorRect.new()
	plane.size = VIEW
	plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mist := ShaderMaterial.new()
	mist.shader = MIST
	mist.set_shader_parameter("density", density)
	plane.material = mist
	parent.add_child(plane)
	mist_materials.append(mist)

func update_view(offset: Vector2) -> void:
	camera = offset
	water_material.set_shader_parameter("camera_offset", offset)
	water_material.set_shader_parameter("clock", model.clock)
	for mist in mist_materials:
		mist.set_shader_parameter("camera_offset", offset)
		mist.set_shader_parameter("traveler", model.position)
		mist.set_shader_parameter("clearing", model.mother_position)
		mist.set_shader_parameter("clock", model.clock)
	queue_redraw()

func _draw() -> void:
	var horizon := 176.0 - camera.y * 0.27
	for i in range(-1, 3):
		var x := i * 1152 - fposmod(camera.x * 0.22, 1152.0)
		var reflected := posmod(i, 2) == 1
		draw_set_transform(Vector2(x + (1152 if reflected else 0), horizon - 242), 0, Vector2(-1 if reflected else 1, 1))
		var tint := Color(0.77, 0.87, 0.87)
		draw_texture_rect_region(BANK, Rect2(0, 0, 1152, 266), Rect2(0, 0, 1536, 271), tint)
		var shore_reflection := PackedVector2Array([Vector2(0, 266), Vector2(1152, 266), Vector2(1152, 438), Vector2(0, 438)])
		var uv := PackedVector2Array([Vector2(0, 271.0 / 1024.0), Vector2(1, 271.0 / 1024.0),
			Vector2(1, 388.0 / 1024.0), Vector2(0, 388.0 / 1024.0)])
		draw_polygon(shore_reflection, PackedColorArray([tint, tint, Color(tint, 0.0), Color(tint, 0.0)]), uv, BANK)
	draw_set_transform(-camera)
	var screen := Rect2(camera, VIEW).grow(100)
	for i in model.banks.size():
		if not model.bank_bounds[i].intersects(screen): continue
		var bank: PackedVector2Array = model.banks[i]
		var ledge := PackedVector2Array()
		for point in bank: ledge.append(point + Vector2(0, 10))
		draw_colored_polygon(ledge, Color("1a3033"))
	for i in model.banks.size():
		if not model.bank_bounds[i].intersects(screen): continue
		draw_polygon(model.banks[i], PackedColorArray([Color("8ea5a2")]), ground_uvs[i], ground_texture)
	for edge in shores:
		var a := Vector2(edge.x, edge.y)
		if not screen.has_point(a): continue
		var b := Vector2(edge.z, edge.w)
		var direction := a.direction_to(b)
		var outward := Vector2(direction.y, -direction.x)
		var glint := 0.52 + sin(a.x * 0.029 + a.y * 0.043) * 0.13
		if outward.y > 0.1:
			var seam := Vector2(0, 7.0 + sin(a.x * 0.21 + a.y) * 3.0)
			draw_colored_polygon(PackedVector2Array([a, b, b + seam, a + seam]), Color(0.13, 0.22, 0.22, glint))
		draw_line(a, b, Color(0.61, 0.71, 0.67, glint * 0.75), 1.8, true)
		var ripple := outward * (9.0 + 2.0 * sin(model.clock * 1.1 + a.x * 0.03))
		draw_line(a + ripple, b + ripple, Color(0.39, 0.75, 0.73, glint * 0.27), 1.6, true)
	for at in model.checkpoints:
		if screen.has_point(at): _lantern(at, 1.0)
	for at in model.shelters:
		if screen.has_point(at): _lantern(at, 0.54)
	_lantern(model.exit_position, 0.87)
	for wave: Dictionary in model.waves:
		if screen.grow(110.0).has_point(wave.position) or screen.grow(110.0).has_point(wave.origin):
			_draw_wave(wave)
	draw_set_transform(model.position - camera, 0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 21, Color(0.0, 0.04, 0.05, 0.48))
	draw_set_transform(Vector2.ZERO)

func _lantern(at: Vector2, scale: float) -> void:
	var flicker := 0.85 + sin(model.clock * 6.0 + at.x) * 0.11 + sin(model.clock * 11.0 - at.y) * 0.04
	for j in range(7, 0, -1):
		draw_set_transform(at - camera, 0, Vector2(1.0, 0.66))
		draw_circle(Vector2.ZERO, (19.0 + j * 12.5) * scale, Color(1.0, 0.77, 0.44, 0.020 * flicker))
	draw_set_transform(-camera)
	var base := at + Vector2(0, 10)
	var flame := at + Vector2(0, -31) * scale
	draw_line(base, flame, Color("4a4133"), 7.0 * scale, true)
	draw_line(base, flame, Color("b09965"), 2.1 * scale, true)
	draw_circle(flame, 12.0 * scale, Color(1.0, 0.73, 0.37, 0.10 * flicker))
	draw_circle(flame, 5.2 * scale * flicker, Color("ffe4ac"))

func _draw_wave(wave: Dictionary) -> void:
	var center: Vector2 = wave.position
	var strength: float = wave.strength
	if wave.gathering > 0.0:
		center = wave.origin
		strength = wave.gathering * 0.56
	if strength <= 0.0: return
	for i in 4:
		var width: float = wave.width * (0.73 + i % 2 * 0.19)
		var at := center + Vector2((i - 1.5) * wave.width * 0.43, -wave.direction * (i % 3 * 23.0 + 15.0))
		var size := Vector2(width, 84.0 + i * 9.0)
		draw_texture_rect(wisp_texture, Rect2(at - size * 0.5, size), false, Color(0.49, 0.78, 0.76, strength * 0.27))
	for row in 4:
		for column in 6:
			var points := PackedVector2Array()
			var seed := column * 9.31 + row * 2.17 + center.x * 0.01
			var band: float = wave.width * (0.33 - row * 0.034)
			var shift: float = (column - 2.5) * wave.width * 0.29 + sin(seed) * 10.0
			for step in 8:
				var t := float(step) / 7.0
				var x: float = shift + (t - 0.5) * band
				var shape: float = (1.0 - pow(absf(x) / wave.width, 1.4)) * 20.0
				var y: float = wave.direction * (shape - row * 18.0) + sin(t * TAU * 0.7 + model.clock * 4.0 + seed) * 5.0
				points.append(center + Vector2(x, y))
			var opacity := strength * (0.55 - row * 0.11)
			draw_polyline(points, Color(0.29, 0.75, 0.74, opacity * 0.38), 7.0 - row, true)
			draw_polyline(points, Color(0.68, 0.95, 0.89, opacity), 1.7, true)
