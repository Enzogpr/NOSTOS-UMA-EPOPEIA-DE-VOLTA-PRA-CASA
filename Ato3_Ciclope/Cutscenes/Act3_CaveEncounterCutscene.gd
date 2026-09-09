extends Control

## Cena do Encontro na Caverna de Polifemo (Ato 3)
## Sequência dramática com revelação gradual do Ciclope e mini-game interativo de sobrevivência.

var current_slide := 0
var is_interactive_mode: bool = false
var is_game_over: bool = false
var is_resolved: bool = false
var is_waiting_for_name: bool = false
var time_left: float = 60.0

var slides = [
	{
		"image": "res://Assets/act3_cave_sheep.jpg",
		"speaker": "Narrador",
		"text": "Guiados pela fome e em busca de alimento, Odisseu e seus guerreiros adentram a colossal caverna nas colinas e encontram um imenso rebanho de ovelhas repousando na penumbra."
	},
	{
		"image": "res://Assets/act3_sheep_slaughter.jpg",
		"speaker": "Narrador",
		"text": "Acreditando ser apenas o abrigo natural de pastores locais, os guerreiros abatem uma das ovelhas para saciar sua fraqueza de dias no mar."
	},
	{
		"image": "res://Assets/act3_cyclops_reveal_1.jpg",
		"speaker": "Voz Ominosa na Escuridão",
		"text": "\"QUEM SÃO VOCÊS?!\""
	},
	{
		"image": "res://Assets/act3_cyclops_reveal_1.jpg",
		"speaker": "Odisseu",
		"text": "\"Olá... Somos apenas viajantes vindos de além-mar. Viemos em paz em busca de sustento.\""
	},
	{
		"image": "res://Assets/act3_cyclops_reveal_2.jpg",
		"speaker": "Polifemo (surgindo das sombras)",
		"text": "\"Vocês mataram minha ovelha... Minha ovelha favorita.\""
	},
	{
		"image": "res://Assets/act3_cyclops_reveal_3.jpg",
		"speaker": "Polifemo",
		"text": "\"O que lhes dá o direito de causar uma dor tão grande?!\""
	},
	{
		"image": "res://Assets/act3_odysseus_grabbed.jpg",
		"speaker": "Polifemo (agarrando Odisseu)",
		"text": "\"Hora de tomar... seu sangue bem aonde estão!\""
	},
	{
		"image": "res://Assets/act3_odysseus_grabbed",
		"speaker": "Polifemo",
		"text": "\"Suas vidas estão em minhas mãos.\""
	},
	{
		"image": "res://Assets/act3_odysseus_grabbed",
		"speaker": "Polifemo",
		"text": "\"E antes de eu terminar, verão que não é tão divertido roubar!\""
	},
	{
		"image": "res://Assets/act3_odysseus_grabbed",
		"speaker": "Polifemo",
		"text": "\"Uma troca, entende? Tirar de vocês... como tiraram de mim!\""
	}
]

var resolution_slides = [
	{
		"image": "res://Assets/act3_offering_wine.jpg",
		"speaker": "Odisseu (oferecendo a ânfora)",
		"text": "\"Vejo que houve um mal entendido, nossa intenção nunca foi roubar, mas agora vemos o dano que causamos. Podemos fazer um acordo, nós lhe daremos nosso melhor tesouro, o melhor vinho do mundo.\""
	},
	{
		"image": "res://Assets/act3_cyclops_reveal_3.jpg",
		"speaker": "Polifemo",
		"text": "\"Vinho?\""
	},
	{
		"image": "res://Assets/act3_offering_wine.jpg",
		"speaker": "Odisseu",
		"text": "\"Sim, um vinho tão bom que você nunca mais irá querer provar carne humana novamente. Tome um gole, sem mais derramamento de sangue aqui. Uma troca, entende? Um presente seu e um presente meu.\""
	},
	{
		"image": "res://Assets/act3_cyclops_drinking.jpg",
		"speaker": "Narrador",
		"text": "Polifemo toma a ânfora e bebe vorazmente em um único trago."
	},
	{
		"image": "res://Assets/act3_cyclops_grinning.jpg",
		"speaker": "Polifemo",
		"text": "\"Eu gostaria de lhe agradecer, estranho... qual o seu nome?\""
	},
	{
		"image": "res://Assets/act3_cyclops_grinning.jpg",
		"speaker": "Odisseu",
		"text": "\"Meu nome é... [X]\""
	},
	{
		"image": "res://Assets/act3_cyclops_grinning.jpg",
		"speaker": "Polifemo",
		"text": "\"[X], pelo seu presente eu gostaria de retribuir.\""
	},
	{
		"image": "res://Assets/act3_offering_wine.jpg",
		"speaker": "Odisseu",
		"text": "\"Fico feliz que vemos a situação com o mesmo olho.\""
	},
	{
		"image": "res://Assets/act3_cyclops_grinning.jpg",
		"speaker": "Polifemo",
		"text": "\"Sim, pelo seu presente... Você será o último homem a morrer.\""
	}
]
var resolution_index := 0

# Nós da UI
@onready var texture_rect: TextureRect = $TextureRect
@onready var text_panel: ColorRect = $TextPanel
@onready var speaker_label: Label = $TextPanel/Margin/VBox/SpeakerLabel
@onready var dialogue_label: Label = $TextPanel/Margin/VBox/DialogueLabel
@onready var continue_label: Label = $TextPanel/Margin/VBox/ContinueLabel

# UI do Mini-game de 1 minuto
@onready var panic_hud: Control = $PanicHUD
@onready var timer_label: Label = $PanicHUD/TimerPanel/TimerLabel
@onready var instruction_label: Label = $PanicHUD/InstructionLabel
@onready var btn_open_inventory: Button = $PanicHUD/ActionButtons/BtnOpenInventory
@onready var btn_offer_wine: Button = $PanicHUD/ActionButtons/BtnOfferWine

@onready var inventory_menu: Control = $InventoryMenu
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var game_over_label: Label = $GameOverOverlay/Label

@onready var name_input_panel: Panel = $NameInputPanel
@onready var name_line_edit: LineEdit = $NameInputPanel/Margin/VBox/NameLineEdit
@onready var btn_confirm_name: Button = $NameInputPanel/Margin/VBox/BtnConfirmName

func _ready() -> void:
	MainHUD.set_station("Ato 3: A Caverna do Ciclope")
	panic_hud.visible = false
	game_over_overlay.visible = false
	
	# Garante que os itens necessários existam no inventário
	_ensure_base_items()
	
	btn_open_inventory.pressed.connect(_on_open_inventory_pressed)
	btn_offer_wine.pressed.connect(_on_offer_wine_pressed)
	btn_confirm_name.pressed.connect(_on_confirm_name_pressed)
	
	if inventory_menu:
		inventory_menu.inventory_closed.connect(_on_inventory_closed)
		
	_update_slide()

func _ensure_base_items() -> void:
	if not GameManager.has_item("lotus_flower"):
		GameManager.add_item(
			"lotus_flower",
			"Flor de Lótus Sagrada",
			"res://Assets/lotus_encounter_3.jpg",
			"Uma flor sagrada de pétalas púrpuras. Provoca torpor profundo e sonolência irresistível.",
			"Pode ser misturada a bebidas ou vinhos para potencializar seu efeito entorpecente."
		)
	if not GameManager.has_item("wine_amphora") and not GameManager.has_item("lotus_wine"):
		GameManager.add_item(
			"wine_amphora",
			"Ânfora de Vinho Doce",
			"res://Assets/act2_cutscene_1.jpg",
			"Uma ânfora lacrada com vinho puro e forte, trazido de Ítaca.",
			"Pode receber ervas ou flores soníferas para criar uma poção entorpecente."
		)

func _process(delta: float) -> void:
	if is_interactive_mode and not is_game_over and not is_resolved:
		time_left -= delta
		if time_left < 0:
			time_left = 0
			_trigger_game_over()
		_update_panic_hud()

func _update_panic_hud() -> void:
	var secs = int(ceil(time_left))
	timer_label.text = "⏱️ TEMPO RESTANTE: %02d s" % secs
	if secs <= 15:
		timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		
	var has_drugged_wine = GameManager.has_item("lotus_wine")
	btn_offer_wine.disabled = not has_drugged_wine
	if has_drugged_wine:
		btn_offer_wine.text = "🍷 OFERECER VINHO DE LÓTUS A POLIFEMO"
		btn_offer_wine.add_theme_color_override("font_color", Color(1, 1, 0.4))
	else:
		btn_offer_wine.text = "🔒 Vinho Sonífero Não Preparado"
		btn_offer_wine.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _load_texture(path: String) -> Texture2D:
	var variations = [
		path,
		path.replace(".jpg", ".png"),
		path.replace(".png", ".jpg"),
		path.replace(".jpg", ".jpeg"),
		path.replace(".png", ".jpeg"),
		path.replace(".jpg", ".webp"),
		path.replace(".png", ".webp")
	]
	for p in variations:
		if ResourceLoader.exists(p):
			return load(p)
		if FileAccess.file_exists(p):
			var img = Image.new()
			var err = img.load(p)
			if err == OK:
				return ImageTexture.create_from_image(img)
	return null

func _update_slide() -> void:
	var slide = slides[current_slide]
	speaker_label.text = slide["speaker"]
	dialogue_label.text = slide["text"]
	
	if slide["speaker"] == "Polifemo" or slide["speaker"].begins_with("Polifemo") or slide["speaker"].begins_with("Voz"):
		speaker_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif slide["speaker"] == "Odisseu":
		speaker_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1))
	else:
		speaker_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		
	var tex = _load_texture(slide["image"])
	if tex:
		texture_rect.texture = tex

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		if event.is_pressed() and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_R)):
			get_tree().reload_current_scene()
		return
		
	if is_interactive_mode:
		if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_I:
			if inventory_menu.visible:
				inventory_menu.close_inventory()
			else:
				_on_open_inventory_pressed()
			get_viewport().set_input_as_handled()
		return

	if event.is_pressed() and not event.is_echo():
		if is_waiting_for_name:
			return
			
		if is_resolved:
			resolution_index += 1
			if resolution_index == 5:
				_start_name_input()
				return
				
			if resolution_index < resolution_slides.size():
				_show_resolution_slide()
			else:
				# Transição para o combate
				get_tree().change_scene_to_file("res://Ato3_Ciclope/Act3_CyclopsBossFight.tscn")
			return
			
		current_slide += 1
		if current_slide < slides.size():
			_update_slide()
		else:
			_start_interactive_survival()

func _start_interactive_survival() -> void:
	is_interactive_mode = true
	text_panel.visible = false
	panic_hud.visible = true
	time_left = 60.0
	_update_panic_hud()
	
	var tutorial = preload("res://Scenes/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
	tutorial.setup([
		"⚠️ ALERTA: Polifemo agarrou Odisseu e está pronto para o golpe fatal!",
		"Você tem 1 MINUTO para agir antes que seja tarde demais.",
		"Abra o Inventário [ I ], misture a Flor de Lótus no Vinho Doce e ofereça ao Ciclope!"
	])

func _on_open_inventory_pressed() -> void:
	if inventory_menu:
		inventory_menu.open_inventory()
		_inject_crafting_option_if_needed()

func _on_inventory_closed() -> void:
	_update_panic_hud()

func _inject_crafting_option_if_needed() -> void:
	var has_lotus = GameManager.has_item("lotus_flower")
	var has_wine = GameManager.has_item("wine_amphora")
	
	# Verifica se pode misturar
	if has_lotus and has_wine:
		# Adiciona botão de misturar no modal ou lista
		var details_vbox = inventory_menu.get_node_or_null("DetailsModal/Margin/VBox")
		if details_vbox and not details_vbox.has_node("CraftBtn"):
			var craft_btn = Button.new()
			craft_btn.name = "CraftBtn"
			craft_btn.text = "🌸 + 🍷 MISTURAR FLOR DE LÓTUS NO VINHO"
			craft_btn.custom_minimum_size = Vector2(0, 44)
			craft_btn.add_theme_font_size_override("font_size", 16)
			craft_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
			craft_btn.pressed.connect(func():
				_combine_lotus_and_wine()
				if details_vbox.has_node("CraftBtn"):
					details_vbox.get_node("CraftBtn").queue_free()
				inventory_menu.close_inventory()
			)
			details_vbox.add_child(craft_btn)

func _combine_lotus_and_wine() -> void:
	GameManager.remove_item("lotus_flower")
	GameManager.remove_item("wine_amphora")
	GameManager.add_item(
		"lotus_wine",
		"Vinho de Lótus Sonífero",
		"res://Assets/lotus_encounter_3.jpg",
		"O mais puro vinho grego potentemente infundido com o aroma e o néctar da Flor de Lótus Sagrada.",
		"Capaz de adormecer qualquer criatura viva em poucos instantes."
	)
	_update_panic_hud()

func _on_offer_wine_pressed() -> void:
	if not GameManager.has_item("lotus_wine") or is_resolved:
		return
		
	is_interactive_mode = false
	is_resolved = true
	panic_hud.visible = false
	if inventory_menu.visible:
		inventory_menu.close_inventory()
		
	resolution_index = 0
	text_panel.visible = true
	_show_resolution_slide()

func _show_resolution_slide() -> void:
	var slide = resolution_slides[resolution_index]
	speaker_label.text = slide["speaker"]
	dialogue_label.text = slide["text"]
	speaker_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	
	var tex = _load_texture(slide["image"])
	if tex:
		texture_rect.texture = tex

func _trigger_game_over() -> void:
	is_game_over = true
	is_interactive_mode = false
	panic_hud.visible = false
	if inventory_menu.visible:
		inventory_menu.close_inventory()
		
	game_over_label.text = "O TEMPO ACABOU!\nPolifemo esmagou Odisseu e seus companheiros.\nPressione [ R ] para tentar novamente."
	game_over_overlay.visible = true

func _start_name_input() -> void:
	is_waiting_for_name = true
	name_input_panel.visible = true
	name_line_edit.grab_focus()

func _on_confirm_name_pressed() -> void:
	var chosen_name = name_line_edit.text.strip_edges()
	if chosen_name == "":
		return
		
	GameManager.player_fake_name = chosen_name
	is_waiting_for_name = false
	name_input_panel.visible = false
	
	for i in range(5, 7):
		resolution_slides[i]["text"] = resolution_slides[i]["text"].replace("[X]", chosen_name)
		
	_show_resolution_slide()
