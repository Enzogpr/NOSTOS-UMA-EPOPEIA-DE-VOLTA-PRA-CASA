extends Control

var cinematic: Control

var current_slide := 0
var release_started: bool = false
var ending_tween: Tween

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
	cinematic = preload("res://Code/CinematicStaging.gd").attach(self, _on_cinematic_advance)
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
		
	cinematic.present(slides[current_slide], "act1_ending", current_slide)

func _on_cinematic_advance() -> void:
	if current_slide < slides.size() - 1:
		current_slide += 1
		_update_slide()
	else:
		cinematic.suspend(true)
		choice_container.visible = true
		choice_container.offset_top = -52.0
		choice_container.offset_bottom = -4.0
		drop_button.custom_minimum_size.y = 44.0
		drop_button.offset_top = -22.0
		drop_button.offset_bottom = 22.0
		drop_button.grab_focus()

func _on_drop_pressed() -> void:
	if release_started:
		return
	release_started = true
	cinematic.present_silent("act1_release")
	hand_rect.visible = false
	choice_container.visible = false
	text_panel.visible = false
	texture_rect.visible = false
	
	final_container.visible = true
	end_title.modulate.a = 0.0
	end_subtitle.modulate.a = 0.0
	
	ending_tween = create_tween()
	var tween := ending_tween
	# Give the empty hands and Odysseus's reaction a silent beat before the card.
	tween.tween_interval(3.5)
	tween.tween_callback(func(): cinematic.fade_out(1.7))
	tween.tween_interval(2.4)
	tween.tween_property(end_title, "modulate:a", 1.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 1.0, 1.5)
	tween.tween_interval(3.5)
	tween.tween_property(end_title, "modulate:a", 0.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	
	tween.tween_callback(func():
		GameManager.unlock_level(2)
		get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")
	)
