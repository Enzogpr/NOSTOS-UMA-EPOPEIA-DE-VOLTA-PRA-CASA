extends Control

var current_slide := 0

var texts = [
	"O Cavalo de Madeira é levado aos portões inexpugnáveis de Troia...",
	"Acreditando ser uma oferenda aos deuses, os troianos abrem seus portões.",
	"O Cavalo é recebido com festas no coração da fortaleza.",
	"Mas, na calada da noite... Odisseu e seus espartanos aguardam o momento de atacar."
]

var images = [
	"res://Assets/cutscene_1.png",
	"res://Assets/cutscene_2.png",
	"res://Assets/cutscene_3.png",
	"res://Assets/cutscene_4.png"
]

@onready var texture_rect: TextureRect = $TextureRect
@onready var label: Label = $TextPanel/Label
@onready var continue_label: Label = $TextPanel/ContinueLabel

func _ready() -> void:
	_update_slide()

func _update_slide() -> void:
	label.text = texts[current_slide]
	
	if ResourceLoader.exists(images[current_slide]):
		texture_rect.texture = load(images[current_slide])
	else:
		# Fallback color if image is missing
		texture_rect.texture = null
		
	if current_slide == texts.size() - 1:
		continue_label.text = "Pressione para invadir Troia..."
	else:
		continue_label.text = "Pressione qualquer botão para continuar..."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		current_slide += 1
		if current_slide >= texts.size():
			get_tree().change_scene_to_file("res://Estoria/Ato1/Act1TitleCard.tscn")
		else:
			_update_slide()
