extends "res://Ato4_Tempestade/Gameplay/NineDaysVigil.gd"
## Preview the actual campaign ending, without playing or saving a full voyage.
func _ready() -> void:
	persist_record = false
	super._ready()
	await get_tree().create_timer(0.45).timeout
	begin()
	model.day = 9
	model.fatigue = 100.0
	model.tick(0.01)
	_show_thought(3)
