extends Control

var cinematic: Control

var current_slide := 0

var texts = [
	"Com determinação e furtividade, Odisseu destranca as pesadas correntes e abre os grandes portões de Troia.",
	"O exército de Ítaca invade a fortaleza sob a luz da lua! A batalha pelas ruas da cidade começa agora."
]

var images = [
	"res://Assets/level2_cutscene_1.png",
	"res://Assets/level2_cutscene_2.png"
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
		continue_label.text = "Pressione para lutar..."
	else:
		continue_label.text = "Pressione qualquer botão para continuar..."
	cinematic.present({"text": texts[current_slide], "image": images[current_slide]}, "act1_invasion", current_slide)

func _advance_story(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		current_slide += 1
		if current_slide >= texts.size():
			cinematic.transition_to("res://Ato1_Troia/Fase2_Invasao.tscn")
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
