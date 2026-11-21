extends Node2D

const LUCK := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const OPEN_DECK := preload("res://Assets/act8_scylla/open_deck.png")
const CREW := preload("res://Assets/act4_friends/crew_poses_v3.png")
const VIEW := Vector2(1152, 648)
const POSES := {
	"accuse": [3, 3, Vector2(328, 603), Vector2(792, 592), 409.0],
	"answer": [2, 4, Vector2(353, 603), Vector2(797, 605), 429.0],
	"draw": [1, 0, Vector2(356, 597), Vector2(775, 603), 429.0],
	"intervene": [3, 5, Vector2(474, 590), Vector2(815, 589), 386.0],
	"shore": [3, 5, Vector2(262, 568), Vector2(901, 538), 310.0],
	"warning": [1, 1, Vector2(327, 586), Vector2(789, 580), 362.0],
	"choice": [3, 4, Vector2(277, 602), Vector2(779, 581), 383.0],
	"offering": [0, 5, Vector2(280, 627), Vector2(1002, 551), 357.0],
	"escape": [4, 5, Vector2(305, 595), Vector2(885, 580), 367.0],
	"thunder": [3, 4, Vector2(294, 605), Vector2(862, 596), 336.0],
}

var hero: LUCK.Performer
var eury: LUCK.Performer
var eury_pivot: Node2D
var island: Texture2D
var mask: ColorRect
var shot := "accuse"
var age := 0.0
var clock := 0.0

func _ready() -> void:
	island = load("res://Assets/act9_mutiny/helios_island.png")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json"))
	hero = LUCK.Performer.new(metadata, "odysseus_luck_poses")
	add_child(hero)
	eury_pivot = Node2D.new()
	eury_pivot.scale.x = -1.0
	add_child(eury_pivot)
	eury = LUCK.Performer.new(metadata, "eurylochus_luck_poses")
	eury_pivot.add_child(eury)
	mask = ColorRect.new()
	mask.size = VIEW
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.color = Color(0.018, 0.027, 0.033, 0.0)
	add_child(mask)
	show_shot("accuse", "EURÍLOCO", true)

func show_shot(name: String, speaker: String, snap := false) -> void:
	shot = name
	age = 0.0
	var setup: Array = POSES[shot]
	hero.height = setup[4]
	eury.height = setup[4]
	hero.pose(setup[0])
	eury.pose(setup[1])
	hero.speaking = speaker == "ODISSEU"
	eury.speaking = speaker == "EURÍLOCO"
	hero.walking = shot in ["draw", "escape"]
	eury.walking = shot in ["draw", "intervene", "offering", "escape"]
	for actor in [hero, eury]:
		for index in actor.sprites.size():
			var sprite: Sprite2D = actor.sprites[index]
			if sprite.texture != null:
				sprite.scale = Vector2.ONE * actor.height / sprite.region_rect.size.y
			if snap:
				sprite.modulate.a = 1.0 if index == actor.front else 0.0
		if snap:
			actor.blend = 1.0
	if snap:
		hero.position = setup[2]
		eury_pivot.position = setup[3]

func update_view(delta: float) -> void:
	clock += delta
	age += delta
	var setup: Array = POSES[shot]
	var response := 1.0 - exp(-delta * 5.0)
	var sway := Vector2(sin(clock * 1.32) * 3.5, cos(clock * 1.8) * 2.0)
	var fall := smoothstep(0.62, 1.32, age) if shot == "intervene" else 0.0
	hero.position = hero.position.lerp(Vector2(setup[2]) + sway + Vector2(12, 73) * fall, response)
	eury_pivot.position = eury_pivot.position.lerp(Vector2(setup[3]) + sway, response)
	hero.lean = 0.36 * fall
	eury.lean = -0.075 if shot == "choice" else 0.0
	var color := Color("ebcba3") if shot in ["shore", "warning", "choice", "offering"] else Color("bac8c7")
	hero.modulate = color
	eury_pivot.modulate = color
	var darkness := 0.0
	if shot == "intervene": darkness = smoothstep(0.81, 1.42, age)
	elif shot == "shore": darkness = 1.0 - smoothstep(0.0, 1.28, age)
	elif shot == "offering": darkness = smoothstep(0.7, 1.55, age) * 0.64
	mask.color = Color(0.018, 0.027, 0.033, darkness)
	queue_redraw()

func _draw() -> void:
	var land := shot in ["shore", "warning", "choice", "offering"]
	var weather := shot in ["escape", "thunder"]
	var image: Texture2D = island if land else OPEN_DECK
	if image == null:
		return
	var dims := Vector2(1200, 800) * (1.02 + minf(age, 4.0) * 0.011)
	var shift := Vector2(sin(clock * 0.57) * 12.0, 11.0 if land else 0.0)
	var tint := Color("788c9f") if weather else Color.WHITE
	if shot == "thunder":
		var pulse := exp(-pow((age - 0.73) * 8.0, 2.0)) * 0.45
		tint = tint.lerp(Color(1.46, 1.48, 1.56), pulse)
	draw_texture_rect(image, Rect2((VIEW - dims) * 0.5 + shift, dims), false, tint)
	if shot == "thunder":
		_draw_lightning()
	if shot in ["accuse", "answer", "draw", "intervene"]:
		_draw_witnesses()
	for index in 30:
		draw_rect(Rect2(0, 648 - index * 6, 1152, 7), Color(0.012, 0.025, 0.033, 0.10 * (1.0 - index / 30.0)))

func _draw_lightning() -> void:
	if age < 0.70 or age > 1.04:
		return
	var opacity := 1.0 - smoothstep(0.76, 1.04, age)
	var bolt := PackedVector2Array([Vector2(621, 22), Vector2(650, 87), Vector2(637, 109), Vector2(672, 155), Vector2(662, 176), Vector2(690, 234)])
	var fork := PackedVector2Array([Vector2(637, 109), Vector2(608, 134), Vector2(616, 158), Vector2(590, 200)])
	draw_polyline(bolt, Color(0.72, 0.83, 1.0, opacity * 0.26), 9.0, true)
	draw_polyline(bolt, Color(0.92, 0.96, 1.0, opacity), 2.8, true)
	draw_polyline(fork, Color(0.81, 0.90, 1.0, opacity * 0.78), 1.6, true)

func _draw_witnesses() -> void:
	for index in 4:
		var at := Vector2(423 + index * 100, 479 + (index % 2) * 14)
		var source := Rect2(160, 615, 466, 633) if index % 2 == 0 else Rect2(750, 615, 351, 635)
		var dims := source.size * 0.33
		var tint := Color(0.34, 0.40, 0.42)
		if shot == "intervene" and index == 0:
			var step := smoothstep(0.0, 0.7, age)
			at += Vector2(-48, 98) * step
			source = Rect2(694, 1, 554, 612)
			dims = source.size * lerpf(0.36, 0.62, step)
			tint = Color(0.31, 0.37, 0.39).lerp(Color(0.14, 0.17, 0.20), step)
		draw_texture_rect_region(CREW, Rect2(at - Vector2(dims.x * 0.5, dims.y), dims), source, tint)
