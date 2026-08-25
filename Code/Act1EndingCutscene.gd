extends Control

var current_slide := 0

var slides = [
	{
		"image": "res://Assets/ending_cutscene_1.png",
		"text": "Com a queda do Rei de Troia, os céus se abrem em chamas e sombras. Os deuses descem em uma visão aterradora para Odisseu."
	},
	{
		"image": "res://Assets/ending_cutscene_2.png",
		"text": "Guiado pela voz dos deuses, Odisseu caminha até os aposentos reais e encontra o herdeiro infante de Troia — o filho do rei, sozinho em seu berço."
	},
	{
		"image": "res://Assets/ending_cutscene_3.png",
		"text": "\"Se ele viver, crescerá alimentado pelo ódio e destruirá Ítaca em vingança. O sangue já está em suas mãos... cabe a você escolher de quem será!\""
	},
	{
		"image": "res://Assets/ending_cutscene_4.png",
		"text": "Odisseu empunha sua lâmina, mas sua mão treme diante da inocência da criança. Tomado pelo peso do destino, ele toma uma decisão desesperada."
	},
	{
		"image": "res://Assets/ending_cutscene_5.png",
		"text": "Carregando o bebê até a sacada mais alta da torre sobre o abismo de Troia, ele estende os braços para a noite fria..."
	}
]

@onready var texture_rect: TextureRect = $TextureRect
@onready var text_panel: ColorRect = $TextPanel
@onready var label: Label = $TextPanel/Label
@onready var continue_label: Label = $TextPanel/ContinueLabel

@onready var choice_container: Control = $ChoiceContainer
@onready var drop_button: Button = $ChoiceContainer/DropButton

@onready var final_container: Control = $FinalContainer
@onready var hand_rect: TextureRect = $FinalContainer/HandRect
@onready var end_title: Label = $FinalContainer/EndTitle
@onready var end_subtitle: Label = $FinalContainer/EndSubtitle

func _ready() -> void:
	choice_container.visible = false
	final_container.visible = false
	drop_button.pressed.connect(_on_drop_pressed)
	_update_slide()

func _update_slide() -> void:
	label.text = slides[current_slide]["text"]
	var img_path = slides[current_slide]["image"]
	
	if ResourceLoader.exists(img_path):
		texture_rect.texture = load(img_path)
	else:
		texture_rect.texture = null
		
	if current_slide == slides.size() - 1:
		continue_label.visible = false
		choice_container.visible = true
		drop_button.grab_focus()
	else:
		continue_label.visible = true
		continue_label.text = "Pressione qualquer botão para continuar..."

func _unhandled_input(event: InputEvent) -> void:
	if choice_container.visible or final_container.visible:
		return
		
	if event.is_pressed() and not event.is_echo():
		if current_slide < slides.size() - 1:
			current_slide += 1
			_update_slide()

func _on_drop_pressed() -> void:
	choice_container.visible = false
	text_panel.visible = false
	texture_rect.visible = false
	
	# Carrega a imagem da mão se existir
	if ResourceLoader.exists("res://Assets/ending_hand.png"):
		hand_rect.texture = load("res://Assets/ending_hand.png")
	else:
		hand_rect.texture = null
		
	final_container.visible = true
	hand_rect.modulate.a = 0.0
	end_title.modulate.a = 0.0
	end_subtitle.modulate.a = 0.0
	
	var tween = create_tween()
	# 1. Tela preta por 0.8s
	tween.tween_interval(0.8)
	
	# 2. Fade in da mão abrindo
	tween.tween_property(hand_rect, "modulate:a", 1.0, 1.2)
	tween.tween_interval(2.2)
	
	# 3. Fade out da mão
	tween.tween_property(hand_rect, "modulate:a", 0.0, 1.5)
	tween.tween_interval(0.8)
	
	# 4. Fade in do "FIM DO PRIMEIRO ATO"
	tween.tween_property(end_title, "modulate:a", 1.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 1.0, 1.5)
	tween.tween_interval(3.5)
	
	# 5. Fade out final e volta ao Menu Principal
	tween.tween_property(end_title, "modulate:a", 0.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	
	tween.tween_callback(func():
		GameManager.reset()
		get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
	)
