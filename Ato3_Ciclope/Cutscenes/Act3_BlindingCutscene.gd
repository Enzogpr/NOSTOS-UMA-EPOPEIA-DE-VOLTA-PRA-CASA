extends Control

var current_slide := 0
var is_game_over: bool = false
var in_minigame: bool = false
var sharpness: float = 0.0

var slides_part1 = [
	{
		"image": "res://Assets/act3_ciclope_caindo_sono.jpg",
		"speaker": "Narrador",
		"text": "O terrível efeito do Vinho de Lótus finalmente domina o gigante. Polifemo tomba pesadamente bloqueando a entrada da caverna, adormecendo em um sono profundo."
	},
	{
		"image": "res://Assets/act3_tropa_desespero.jpg",
		"speaker": "Guerreiro de Ítaca",
		"text": "\"O que faremos agora, capitão? O monstro dorme. Devemos matá-lo enquanto podemos?\""
	},
	{
		"image": "res://Assets/act3_odisseu_pensativo.jpg",
		"speaker": "Odisseu",
		"text": "\"Não... Se o matarmos, não haverá força neste mundo capaz de mover a imensa pedra que sela a caverna. O corpo dele está bloqueando o nosso único caminho livre para ela. Morreríamos aqui.\""
	},
	{
		"image": "res://Assets/act3_preparando_estaca.jpg",
		"speaker": "Odisseu",
		"text": "\"Peguem a clava gigante dele. Vamos usar as brasas da fogueira e nossas espadas para afiá-la até que se torne uma estaca letal.\""
	}
]

var slides_part2 = [
	{
		"image": "res://Assets/act3_odisseu_gritando_ataque.jpg",
		"speaker": "Odisseu",
		"text": "\"Mirar direto no olho! AGORA!\""
	},
	{
		"image": "res://Assets/act3_estaca_no_olho.jpg",
		"speaker": "Narrador",
		"text": "A estaca incandescente perfura o olho do monstro. Polifemo dá um urro ensurdecedor de pura agonia e corre desesperado pela caverna, batendo nas paredes."
	},
	{
		"image": "res://Assets/act3_ciclope_ajoelhado.jpg",
		"speaker": "Narrador",
		"text": "Ele cai de joelhos diante de uma fenda profunda na parede de pedra. Nas sombras do buraco, dezenas de grandes olhos brilhantes se abrem no escuro..."
	},
	{
		"image": "res://Assets/act3_fenda_olhos_brilhantes.jpg",
		"speaker": "Vozes Trovão (Outros Ciclopes)",
		"text": "\"Ouvimos seus gritos de dor, Polifemo! Quem está lhe causando esse mal?! Quem o atacou na calada da noite?!\""
	},
	{
		"image": "res://Assets/act3_ciclope_acusando.jpg",
		"speaker": "Polifemo",
		"text": "\"Foi [X]! [X] me cegou! [X] me arruinou!\""
	}
]

var slides_part3_win = [
	{
		"image": "res://Assets/act3_fenda_olhos_sumindo.jpg",
		"speaker": "Vozes Trovão (Outros Ciclopes)",
		"text": "\"Se não foi Ninguém, então pare de chorar! Devem ser os deuses que o amaldiçoaram. Lide com isso em silêncio!\""
	},
	{
		"image": "res://Assets/act3_odisseu_sussurrando_ovelhas.jpg",
		"speaker": "Odisseu (Sussurrando)",
		"text": "\"Os tolos foram embora. Peguem as ovelhas e vamos dar o fora daqui.\""
	},
	{
		"image": "res://Assets/act3_atena_aparece.jpg",
		"speaker": "Deusa Atena",
		"text": "\"Esqueceu das lições que te ensinei? Ele é uma ameaça enquanto vivo. Mate-o!\""
	},
	{
		"image": "res://Assets/act3_odisseu_encara_atena.jpg",
		"speaker": "Odisseu",
		"text": "\"Não.\""
	},
	{
		"image": "res://Assets/act3_atena_furiosa.jpg",
		"speaker": "Deusa Atena",
		"text": "\"Não?!\""
	},
	{
		"image": "res://Assets/act3_odisseu_piedade.jpg",
		"speaker": "Odisseu",
		"text": "\"Que bem faria matar, quando piedade é uma coisa que esse mundo deveria aprender? Meus amigos estão mortos, o inimigo está cego, o sangue que derramamos nunca seca.\""
	},
	{
		"image": "res://Assets/act3_atena_grito.jpg",
		"speaker": "Deusa Atena",
		"text": "\"NÃO!!\""
	},
	{
		"image": "res://Assets/act3_odisseu_costas_caverna.jpg",
		"speaker": "Odisseu (Aos gritos)",
		"text": "\"Ei, Ciclope! Eu tentei oferecer paz, mas você escolheu alimentar sua fera interior! Meus camaradas não irão morrer em vão.\""
	},
	{
		"image": "res://Assets/act3_odisseu_olhando_ciclope.jpg",
		"speaker": "Odisseu",
		"text": "\"Lembre-se deles, da próxima vez que ousar não poupar! Lembre-se deles... Lembre-se de nós...\""
	},
	{
		"image": "res://Assets/act3_odisseu_rosto_sombrio.jpg",
		"speaker": "Odisseu (Fúria Pura)",
		"text": "\"Lembre-se de mim! Eu sou o rei de Ítaca! Eu não sou nem homem e nem ser místico... Eu sou o seu momento mais sombrio...\""
	},
	{
		"image": "res://Assets/act3_odisseu_revela_nome.jpg",
		"speaker": "Odisseu",
		"text": "\"EU SOU ODISSEU!\""
	}
]

var slides_part3_lose = [
	{
		"image": "res://Assets/act3_ciclopes_invadindo.jpg",
		"speaker": "Vozes Trovão (Outros Ciclopes)",
		"text": "\"Então vamos descer aí e esmagar o crânio desse [X] e seus amigos!\""
	},
	{
		"image": "res://Assets/act3_massacre_caverna.jpg",
		"speaker": "Narrador",
		"text": "A parede de pedra cede. Diversos Ciclopes invadem a caverna e massacram Odisseu e todos os seus homens."
	}
]

var active_slides = []

@onready var texture_rect: TextureRect = $TextureRect
@onready var speaker_label: Label = $TextPanel/Margin/VBox/SpeakerLabel
@onready var dialogue_label: Label = $TextPanel/Margin/VBox/DialogueLabel
@onready var text_panel: ColorRect = $TextPanel
@onready var game_over_overlay: ColorRect = $GameOverOverlay
@onready var minigame_panel: Control = $MinigamePanel
@onready var sharpen_bar: ProgressBar = $MinigamePanel/SharpenBar
@onready var hit_area: ColorRect = $MinigamePanel/HitArea

func _ready() -> void:
	if GameManager.player_fake_name == "":
		GameManager.player_fake_name = "Ninguem" # Padrão para testes diretos na cena
		
	MainHUD.set_station("Ato 3 - Fuga da Caverna")
	game_over_overlay.visible = false
	minigame_panel.visible = false
	
	active_slides = slides_part1
	current_slide = 0
	_update_slide()
	
	hit_area.gui_input.connect(_on_hit_area_gui_input)

func _load_texture(path: String) -> Texture2D:
	var variations = [
		path,
		path.replace(".jpg", ".png"),
		path.replace(".png", ".jpg")
	]
	for p in variations:
		if ResourceLoader.exists(p): return load(p)
		if FileAccess.file_exists(p):
			var img = Image.new()
			if img.load(p) == OK:
				return ImageTexture.create_from_image(img)
	return null

func _update_slide() -> void:
	var slide = active_slides[current_slide]
	speaker_label.text = slide["speaker"]
	dialogue_label.text = slide["text"]
	
	if slide["speaker"] == "Odisseu":
		speaker_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1))
	elif "Polifemo" in slide["speaker"] or "Ciclopes" in slide["speaker"] or "Atena" in slide["speaker"]:
		speaker_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		speaker_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		
	var tex = _load_texture(slide["image"])
	if tex:
		texture_rect.texture = tex

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		if event.is_pressed() and event is InputEventKey and event.keycode == KEY_R:
			GameManager.heal_fully()
			get_tree().change_scene_to_file("res://Ato3_Ciclope/Cutscenes/Act3_CaveEncounterCutscene.tscn")
		return
		
	if in_minigame:
		return

	if event.is_pressed() and not event.is_echo():
		current_slide += 1
		if current_slide < active_slides.size():
			_update_slide()
		else:
			_handle_slide_end()

func _handle_slide_end() -> void:
	if active_slides == slides_part1:
		_start_minigame()
	elif active_slides == slides_part2:
		_check_branch()
	elif active_slides == slides_part3_win:
		# Acaba o Ato 3, vai pro Cartão de Encerramento
		get_tree().change_scene_to_file("res://Ato3_Ciclope/Cutscenes/Act3_EndingCard.tscn")
	elif active_slides == slides_part3_lose:
		_trigger_game_over()

func _start_minigame() -> void:
	in_minigame = true
	minigame_panel.visible = true
	text_panel.visible = false
	sharpness = 0.0
	sharpen_bar.value = 0.0

func _on_hit_area_gui_input(event: InputEvent) -> void:
	if not in_minigame: return
	
	if event is InputEventMouseMotion:
		# Incrementa com base na velocidade do movimento do mouse para simular a afiação
		sharpness += event.relative.length() * 0.05
		sharpen_bar.value = sharpness
		
		# Feedback de cor
		var ratio = sharpness / 100.0
		hit_area.color = Color(0.3 + ratio * 0.7, 0.2 + ratio * 0.1, 0.1)
		
		if sharpness >= 100.0:
			in_minigame = false
			minigame_panel.visible = false
			text_panel.visible = true
			active_slides = slides_part2
			current_slide = 0
			
			# Substitui as variáveis [X] antes de tocar
			for slide in active_slides:
				slide["text"] = slide["text"].replace("[X]", GameManager.player_fake_name)
				
			_update_slide()

func _check_branch() -> void:
	var name_lower = GameManager.player_fake_name.to_lower().strip_edges()
	var is_nobody = (name_lower == "ninguem" or name_lower == "ninguém" or name_lower == "nobody")
	
	if is_nobody:
		active_slides = slides_part3_win
	else:
		active_slides = slides_part3_lose
		# Substitui [X] se perder
		for slide in active_slides:
			slide["text"] = slide["text"].replace("[X]", GameManager.player_fake_name)
			
	current_slide = 0
	_update_slide()

func _trigger_game_over() -> void:
	is_game_over = true
	text_panel.visible = false
	game_over_overlay.visible = true
