extends Node

func _ready():
	print("--- INICIANDO CONSTRUÇÃO DAS CENAS ---")
	
	_build_title_screen()
	_build_intro_cutscene()
	
	# Construir Level 1
	var level1 = Node2D.new()
	level1.name = "TrojanHorse"
	var l1_script = load("res://Code/Level.gd")
	level1.set_script(l1_script)
	level1._build_background()
	level1._build_walls()
	level1._build_shadows()
	level1._build_horse()
	level1._build_gate()
	level1._build_ui()
	_set_owner_recursive(level1, level1)
	var pack1 = PackedScene.new()
	pack1.pack(level1)
	ResourceSaver.save(pack1, "res://Scenes/TrojanHorse.tscn")
	print("Level 1 salvo!")

	# Construir Level 2
	var level2 = Node2D.new()
	level2.name = "Level2"
	var l2_script = load("res://Code/Level2.gd")
	level2.set_script(l2_script)
	level2._build_city_streets()
	level2._build_combat_ui()
	_set_owner_recursive(level2, level2)
	var pack2 = PackedScene.new()
	pack2.pack(level2)
	ResourceSaver.save(pack2, "res://Scenes/Level2.tscn")
	print("Level 2 salvo!")

	# Construir Level 3
	var level3 = Node2D.new()
	level3.name = "Level3"
	var l3_script = load("res://Code/Level3.gd")
	level3.set_script(l3_script)
	level3._build_arena()
	level3._build_ui()
	_set_owner_recursive(level3, level3)
	var pack3 = PackedScene.new()
	pack3.pack(level3)
	ResourceSaver.save(pack3, "res://Scenes/Level3.tscn")
	print("Level 3 salvo!")

	print("--- CONSTRUÇÃO FINALIZADA ---")
	get_tree().quit()

func _set_owner_recursive(node: Node, owner_node: Node):
	if node != owner_node:
		node.owner = owner_node
	for child in node.get_children():
		_set_owner_recursive(child, owner_node)

func _build_title_screen() -> void:
	var title = Control.new()
	title.name = "TitleScreen"
	title.set_script(load("res://Code/TitleScreen.gd"))
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(bg)
	
	var tex_rect = TextureRect.new()
	tex_rect.name = "TextureRect"
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title.add_child(tex_rect)
	
	var lbl = Label.new()
	lbl.name = "TitleLabel"
	lbl.text = "A Odisseia do Cavalo de Troia"
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(576 - 350, 324 - 100)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(lbl)
	
	var sub = Label.new()
	sub.name = "SubtitleLabel"
	sub.text = "Pressione qualquer botão para jogar"
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.position = Vector2(576 - 150, 324 + 50)
	title.add_child(sub)
	
	_set_owner_recursive(title, title)
	var pack = PackedScene.new()
	pack.pack(title)
	ResourceSaver.save(pack, "res://Scenes/TitleScreen.tscn")
	print("TitleScreen salvo!")

func _build_intro_cutscene() -> void:
	var cut = Control.new()
	cut.name = "IntroCutscene"
	cut.set_script(load("res://Estoria/Ato1/IntroCutscene.gd"))
	
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0, 0, 0)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	cut.add_child(bg)
	
	var tex := TextureRect.new()
	tex.name = "TextureRect"
	tex.anchors_preset = Control.PRESET_FULL_RECT
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cut.add_child(tex)
	
	var pnl := ColorRect.new()
	pnl.name = "TextPanel"
	pnl.color = Color(0, 0, 0, 0.8)
	pnl.anchors_preset = Control.PRESET_BOTTOM_WIDE
	pnl.offset_top = -150
	pnl.custom_minimum_size = Vector2(0, 150)
	cut.add_child(pnl)
	
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.anchors_preset = Control.PRESET_FULL_RECT
	lbl.offset_left = 40
	lbl.offset_top = 20
	lbl.offset_right = -40
	lbl.offset_bottom = -40
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.text = "..."
	pnl.add_child(lbl)
	
	var cont := Label.new()
	cont.name = "ContinueLabel"
	cont.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	cont.offset_left = -350
	cont.offset_top = -40
	cont.offset_right = -20
	cont.offset_bottom = -10
	cont.text = "Pressione qualquer botão para continuar..."
	cont.add_theme_font_size_override("font_size", 16)
	cont.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pnl.add_child(cont)
	
	_set_owner_recursive(cut, cut)
	var pack := PackedScene.new()
	pack.pack(cut)
	ResourceSaver.save(pack, "res://Estoria/Ato1/IntroCutscene.tscn")
	print("IntroCutscene salva!")
