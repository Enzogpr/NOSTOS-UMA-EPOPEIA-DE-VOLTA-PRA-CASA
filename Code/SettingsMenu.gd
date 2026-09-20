extends Control

@onready var master_slider: HSlider = $VBoxContainer/MasterContainer/HSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicContainer/HSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXContainer/HSlider
@onready var back_button: Button = $VBoxContainer/BtnVoltar

func _ready() -> void:
	master_slider.value = AudioManager.master_vol
	music_slider.value = AudioManager.music_vol
	sfx_slider.value = AudioManager.sfx_vol
	
	master_slider.value_changed.connect(func(v): AudioManager.set_volume("Master", v))
	music_slider.value_changed.connect(func(v): AudioManager.set_volume("Music", v))
	sfx_slider.value_changed.connect(func(v): AudioManager.set_volume("SFX", v))
	
	back_button.pressed.connect(_on_back_pressed)
	hide()

func open_settings() -> void:
	show()
	master_slider.grab_focus()

func _on_back_pressed() -> void:
	hide()
	# Dá a chance do parente retomar o foco se precisar
	owner.call_deferred("grab_focus")
