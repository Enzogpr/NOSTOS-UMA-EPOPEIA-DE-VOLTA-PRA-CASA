extends Node2D

const LUCK := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const REGIONS := "res://Assets/act4_luck/regions.json"
const VIEW := Vector2(1152, 648)
const GOLD := Color("ffcd83")

const SHOTS := {
	"approach": [Vector2(350, 556), Vector2(801, 543), 3, 1, 350.0, 0.87],
	"order": [Vector2(326, 595), Vector2(792, 582), 1, 1, 435.0, 1.0],
	"torches": [Vector2(164, 572), Vector2(989, 571), 5, 5, 320.0, 0.80],
	"empty": [Vector2(243, 560), Vector2(887, 550), 3, 5, 306.0, 0.74],
	"recognize": [Vector2(296, 605), Vector2(770, 605), 3, 3, 441.0, 0.94],
	"silence": [Vector2(312, 619), Vector2(790, 612), 3, 4, 451.0, 0.88],
}
const CREW_CUTS := [0.0, 258.0, 501.0, 745.0, 1037.0, 1254.0, 1536.0]
const TORCH_HEADS := [Vector2(60, 154), Vector2(327, 165), Vector2(568, 158), Vector2(816, 150), Vector2(1095, 175), Vector2(1319, 164)]

var odysseus: LUCK.Performer
var eurylochus: LUCK.Performer
var eury_pivot: Node2D
var deck: Texture2D
var open_sea: Texture2D
var torch_bearers: Texture2D
var shot := "approach"
var age := 0.0
var time := 0.0
var torch_count := 0
var ending := false
var camera_offset := Vector2.ZERO
var zoom := 1.0

func _ready() -> void:
	deck = load("res://Assets/act8_scylla/cave_deck.png")
	open_sea = load("res://Assets/act8_scylla/open_deck.png")
	torch_bearers = load("res://Assets/act8_scylla/torch_bearers.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
	odysseus = LUCK.Performer.new(data, "odysseus_luck_poses")
	add_child(odysseus)
	eury_pivot = Node2D.new()
	eury_pivot.scale.x = -1.0
	add_child(eury_pivot)
	eurylochus = LUCK.Performer.new(data, "eurylochus_luck_poses")
	eury_pivot.add_child(eurylochus)
	show_shot("approach", "", true)

func show_shot(next: String, speaker: String, snap := false) -> void:
	shot = next
	age = 0.0
	ending = shot in ["empty", "recognize", "silence"]
	var setup: Array = SHOTS[shot]
	odysseus.height = setup[4]
	eurylochus.height = setup[4]
	odysseus.pose(setup[2])
	eurylochus.pose(setup[3])
	for actor in [odysseus, eurylochus]:
		for index in actor.sprites.size():
			var sprite: Sprite2D = actor.sprites[index]
			if sprite.texture != null:
				sprite.scale = Vector2.ONE * actor.height / sprite.region_rect.size.y
			if snap:
				sprite.modulate.a = 1.0 if index == actor.front else 0.0
		if snap:
			actor.blend = 1.0
	odysseus.speaking = speaker == "ODISSEU"
	eurylochus.speaking = speaker == "EURÍLOCO"
	odysseus.walking = shot == "torches"
	eurylochus.walking = shot in ["torches", "empty"]
	if snap:
		odysseus.position = setup[0]
		eury_pivot.position = setup[1]

func advance_view(delta: float) -> void:
	age += delta
	time += delta
	var setup: Array = SHOTS[shot]
	var blend := 1.0 - exp(-delta * 4.0)
	var sway := Vector2(sin(time * 1.28) * 6.0, cos(time * 1.66) * 3.2)
	var offset := Vector2(0, -5) if shot in ["approach", "torches", "empty"] else Vector2(-16, 14) if not ending else Vector2(19, 18)
	camera_offset = camera_offset.lerp(offset + sway, blend * 0.65)
	zoom = lerpf(zoom, 1.0 + float(setup[5]) * 0.12, blend * 0.36)
	odysseus.position = odysseus.position.lerp(Vector2(setup[0]) + sway, blend)
	eury_pivot.position = eury_pivot.position.lerp(Vector2(setup[1]) + sway, blend)
	var warmth := minf(1.0, torch_count / 6.0)
	odysseus.modulate = Color(0.59, 0.72, 0.74).lerp(Color(0.96, 0.83, 0.65), warmth * 0.72)
	eury_pivot.modulate = Color(0.63, 0.75, 0.78).lerp(Color(1.0, 0.88, 0.68), warmth * 0.78)
	queue_redraw()

func _draw() -> void:
	if deck == null:
		return
	var dims := Vector2(1190, 793) * zoom
	var tint := Color("90b6bb") if ending else Color("7c9c9d")
	draw_texture_rect(open_sea if ending else deck, Rect2((VIEW - dims) / 2 + camera_offset, dims), false, tint)
	for index in TORCH_HEADS.size():
		if ending:
			_draw_spent_torch(index)
		else:
			_draw_torch_bearer(index)
	for i in 30:
		var alpha := 0.13 * (1.0 - i / 30.0)
		draw_rect(Rect2(0, 648 - i * 6, 1152, 7), Color(0.025, 0.043, 0.061, alpha))

func _draw_torch_bearer(index: int) -> void:
	var source := Rect2(CREW_CUTS[index], 96.0, CREW_CUTS[index + 1] - CREW_CUTS[index], 847.0)
	var height := 234.0 + (index % 2) * 15.0 + sin(time * 1.9 + index) * 1.4
	var factor := height / source.size.y
	var feet := Vector2(341.0 + index * 94.0, 484.0 + (index % 2) * 12.0) + camera_offset * 0.72
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.31))
	draw_circle(Vector2.ZERO, 31.0, Color(0.03, 0.055, 0.06, 0.43))
	draw_set_transform(Vector2.ZERO)
	var at := feet - Vector2(source.size.x * factor * 0.5, height)
	var lit := index < torch_count
	var tint := Color("c79e73") if lit else Color("677d85")
	draw_texture_rect_region(torch_bearers, Rect2(at, source.size * factor), source, tint)
	if lit:
		var anchor: Vector2 = TORCH_HEADS[index]
		_draw_flame(at + (anchor - source.position) * factor, index)

func _draw_flame(at: Vector2, index: int) -> void:
	var flicker := sin(time * 16.0 + index * 3.4)
	for ring in range(12, 0, -1):
		draw_circle(at, ring * 5.8 + flicker * 2.3, Color(1.0, 0.49, 0.13, 0.009 + (12 - ring) * 0.003))
	var peak := at + Vector2(flicker * 4.5, -20.0 - flicker * 4.0)
	var shape := PackedVector2Array([at + Vector2(-7, -4), at + Vector2(-3, -12), peak, at + Vector2(5, -12), at + Vector2(7, -3), at])
	draw_colored_polygon(shape, Color("f08e46"))
	draw_circle(at + Vector2(0, -5), 4.1, GOLD)
	for particle in 3:
		var rise := fposmod(time * (0.57 + particle * 0.14) + particle * 0.31 + index, 1.0)
		draw_circle(at + Vector2(sin(rise * 4.0 + index) * 8.0, -15.0 - rise * 33.0), 1.35, Color(GOLD, 1.0 - rise))

func _draw_spent_torch(index: int) -> void:
	var at := Vector2(422 + index * 55, 427 + (index % 3) * 25) + camera_offset
	var direction := Vector2.from_angle(0.25 + sin(index * 2.9) * 0.75)
	var base := at + direction * 47.0
	draw_line(base + Vector2(0, 4), at + Vector2(0, 4), Color(0.018, 0.029, 0.036, 0.58), 7.0, true)
	draw_line(base, at, Color("594631"), 5.0, true)
	draw_line(at - direction * 6.0, at + direction * 5.0, Color("282b2a"), 7.0, true)
	var fade := 1.0 - smoothstep(0.0, 5.0, time)
	for particle in 5:
		var rise := fposmod(time * 0.41 + particle * 0.21 + index * 0.13, 1.0)
		draw_circle(at + Vector2(sin(rise * 4.0 + index) * 10.0, -3.0 - rise * 46.0), 1.0 + rise * 7.0, Color(0.61, 0.68, 0.68, fade * (1.0 - rise) * 0.13))
