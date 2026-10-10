extends Control

var cinematic: Control

var current_slide := 0

var texts = [
	"Deixando o caos das ruas para trás, Odisseu sobe as escadarias sombrias em direção ao topo da torre do palácio.",
	"No salão real, o Rei de Troia aguarda em seu trono, empunhando suas armas para um confronto final até a morte."
]

var images = [
	"res://Assets/level3_cutscene_1.png",
	"res://Assets/level3_cutscene_2.png"
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
		continue_label.text = "Pressione para a Batalha Final..."
	else:
		continue_label.text = "Pressione qualquer botão para continuar..."
	cinematic.present({"text": texts[current_slide], "image": images[current_slide]}, "act1_palace", current_slide)

func _advance_story(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		current_slide += 1
		if current_slide >= texts.size():
			cinematic.transition_to("res://Ato1_Troia/Fase3_ReiDeTroia.tscn")
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
