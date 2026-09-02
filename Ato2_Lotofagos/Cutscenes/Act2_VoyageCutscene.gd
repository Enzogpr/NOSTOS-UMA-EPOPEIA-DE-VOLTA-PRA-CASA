extends Control

var current_slide := 0

var slides = [
	{
		"image": "res://Assets/act2_cutscene_1.jpg",
		"text": "Euríloco: \"Capitão Odisseu, os mantimentos acabaram. Os homens estão famintos e exaustos... se não encontrarmos terra logo, a morte nos levará antes dos deuses.\""
	},
	{
		"image": "res://Assets/act2_cutscene_2.jpg",
		"text": "Odisseu: \"Mantenham a calma. Olhem para o céu! Os pássaros nunca voam para o nada... eles sempre retornam para terra firme. Ajustem as velas e sigam o rumo deles!\""
	},
	{
		"image": "res://Assets/act2_cutscene_3.jpg",
		"text": "Odisseu: \"Terra à vista! Ancorem na enseada e enviem um grupo de batedores para explorar a praia e buscar comida fresca para todos.\""
	},
	{
		"image": "res://Assets/act2_cutscene_3.jpg",
		"text": "Horas se passam em silêncio absoluto e os homens não retornam. Temendo o pior, Odisseu desembainha sua lâmina e desembarca sozinho na ilha misteriosa..."
	}
]

@onready var texture_rect: TextureRect = $TextureRect
@onready var text_panel: ColorRect = $TextPanel
@onready var label: Label = $TextPanel/Label
@onready var continue_label: Label = $TextPanel/ContinueLabel

func _ready() -> void:
	_update_slide()

func _update_slide() -> void:
	label.text = slides[current_slide]["text"]
	var img_path: String = slides[current_slide]["image"]
	
	if ResourceLoader.exists(img_path):
		texture_rect.texture = load(img_path)
	elif ResourceLoader.exists(img_path.replace(".jpg", ".png")):
		texture_rect.texture = load(img_path.replace(".jpg", ".png"))
	else:
		texture_rect.texture = null
		
	continue_label.text = "Pressione qualquer botão para continuar..."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if current_slide < slides.size() - 1:
			current_slide += 1
			_update_slide()
		else:
			get_tree().change_scene_to_file("res://Ato2_Lotofagos/Fase1_IlhaDosLotofagos.tscn")
