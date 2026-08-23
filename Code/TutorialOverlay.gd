extends CanvasLayer

@onready var label: Label = $SpeechBubble/Label
@onready var athena_tex: TextureRect = $AthenaTex

func _ready() -> void:
	if ResourceLoader.exists("res://Assets/athena.png"):
		athena_tex.texture = load("res://Assets/athena.png")

func setup(text: String) -> void:
	label.text = text
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		get_tree().paused = false
		queue_free()
