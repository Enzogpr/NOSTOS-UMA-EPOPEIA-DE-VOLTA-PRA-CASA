extends Node

## Controla o estado global da fase: nível de suspeita dos guardas,
## e se o jogador já venceu ou foi descoberto.

signal suspicion_changed(value: float)
signal detected
signal victory
signal player_health_changed(hp: int)
signal game_over_combat
signal player_first_move

var suspicion: float = 0.0
var max_suspicion: float = 100.0
var game_over: bool = false
var combat_mode: bool = false
var has_player_moved: bool = false

func add_suspicion(amount: float) -> void:
	if game_over:
		return
	var new_val: float = clamp(suspicion + amount, 0.0, max_suspicion)
	if new_val == suspicion:
		return
	suspicion = new_val
	suspicion_changed.emit(suspicion)
	if suspicion >= max_suspicion:
		trigger_detected()

func reduce_suspicion(amount: float) -> void:
	if game_over:
		return
	var new_val: float = clamp(suspicion - amount, 0.0, max_suspicion)
	if new_val == suspicion:
		return
	suspicion = new_val
	suspicion_changed.emit(suspicion)

func trigger_detected() -> void:
	if game_over:
		return
	game_over = true
	detected.emit()

func trigger_victory() -> void:
	if game_over:
		return
	game_over = true
	victory.emit()

func reset() -> void:
	suspicion = 0.0
	game_over = false
	combat_mode = false
	has_player_moved = false
	suspicion_changed.emit(suspicion)

func enable_combat_mode() -> void:
	combat_mode = true
	game_over = false
	has_player_moved = false
	suspicion_changed.emit(suspicion)
