extends CanvasLayer

@onready var station_label: Label = $MarginContainer/VBoxContainer/StationLabel
@onready var age_label: Label = $MarginContainer/VBoxContainer/AgeLabel

func _ready() -> void:
	layer = 90
	GameManager.player_stats_changed.connect(_on_stats_changed)
	_on_stats_changed()
	
func _on_stats_changed() -> void:
	if age_label:
		age_label.text = "Idade: " + str(GameManager.player_age) + " Anos"

func _process(_delta: float) -> void:
	var current = get_tree().current_scene
	if current and (current.name.contains("Title") or current.name.contains("Cutscene")):
		visible = false
	else:
		visible = true

func set_station(text: String) -> void:
	if station_label:
		station_label.text = text
