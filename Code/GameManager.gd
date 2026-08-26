extends Node

## Controla o estado global da fase: nível de suspeita dos guardas,
## e se o jogador já venceu ou foi descoberto.

signal suspicion_changed(value: float)
signal detected
signal victory
signal player_health_changed(hp: int)
signal game_over_combat
signal player_first_move
signal player_stats_changed

var suspicion: float = 0.0
var max_suspicion: float = 100.0
var game_over: bool = false
var combat_mode: bool = false
var has_player_moved: bool = false

var player_age: int = 20
var player_max_hp: int = 10
var player_current_hp: int = 10
var player_speed_mult: float = 1.0
var player_damage: int = 1
var player_dash_cooldown: float = 3.0
var player_intellect: int = 1
var guard_detection_mult: float = 1.0

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
	
	player_age = 20
	player_max_hp = 10
	player_current_hp = 10
	player_speed_mult = 1.0
	player_damage = 1
	player_dash_cooldown = 3.0
	player_intellect = 1
	guard_detection_mult = 1.0
	
	suspicion_changed.emit(suspicion)
	player_stats_changed.emit()
	player_health_changed.emit(player_current_hp)

func enable_combat_mode() -> void:
	combat_mode = true
	game_over = false
	has_player_moved = false
	suspicion_changed.emit(suspicion)

func heal_fully() -> void:
	player_current_hp = player_max_hp
	player_health_changed.emit(player_current_hp)

func sacrifice_year() -> void:
	player_age += 1
	
	if player_age >= 20 and player_age <= 29:
		player_speed_mult += 0.08
		player_dash_cooldown -= 0.15
	elif player_age >= 30 and player_age <= 39:
		player_damage += 1
		player_speed_mult -= 0.04
		if player_age % 2 == 0:
			player_intellect += 1
		if player_age == 30 or player_age == 35:
			player_max_hp -= 1
	elif player_age >= 40 and player_age <= 49:
		player_intellect += 1
		player_max_hp -= 1
		player_dash_cooldown += 0.1
	elif player_age >= 50:
		player_max_hp -= 1
		player_intellect += 1
		player_speed_mult -= 0.05
		
	if player_max_hp < 1: player_max_hp = 1
	if player_dash_cooldown < 0.5: player_dash_cooldown = 0.5
	
	# Inteligência reduz a velocidade de detecção (aumenta furtividade)
	guard_detection_mult = clamp(1.0 - (player_intellect - 1) * 0.1, 0.4, 2.0)
	
	player_current_hp = clampi(player_current_hp, 0, player_max_hp)
	
	player_stats_changed.emit()
	player_health_changed.emit(player_current_hp)
