extends Control

var cinematic: Control

var current_slide := 0

var texts = [
	"O Cavalo de Madeira é levado aos portões inexpugnáveis de Troia...",
	"Acreditando ser uma oferenda aos deuses, os troianos abrem seus portões.",
	"O Cavalo é recebido com festas no coração da fortaleza.",
	"Mas, na calada da noite... Odisseu e seus guerreiros de Ítaca aguardam o momento de atacar."
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
	cinematic = preload("res://Code/CinematicStaging.gd").attach(self, _on_cinematic_advance)
	_update_slide()

func _update_slide() -> void:
	label.text = texts[current_slide]
	
	if ResourceLoader.exists(images[current_slide]):
		texture_rect.texture = load(images[current_slide])
	else:
		texture_rect.texture = null
		
	if current_slide == texts.size() - 1:
		continue_label.text = "Pressione para invadir Troia..."
	else:
		continue_label.text = "Pressione qualquer botão para continuar..."
	cinematic.present({"text": texts[current_slide], "image": images[current_slide]}, "act1_intro", current_slide)

func _advance_story(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		current_slide += 1
		if current_slide >= texts.size():
			cinematic.transition_to("res://Ato1_Troia/Fase1_PortaoDeTroia.tscn")
		else:
			_update_slide()

func _unhandled_input(event: InputEvent) -> void:
	if cinematic.active or cinematic.is_ending:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	_advance_story(event)

func _on_cinematic_advance() -> void:
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	_advance_story(event)
