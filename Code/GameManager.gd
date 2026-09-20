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
var player_fake_name: String = ""

var player_age: int = 20
var player_max_hp: int = 10
var player_current_hp: int = 10
var player_speed_mult: float = 1.0
var player_damage: int = 3
var player_dash_cooldown: float = 3.0
var player_intellect: int = 5
var guard_detection_mult: float = 1.0

var inventory: Array = []

var highest_unlocked_level: int = 1
const SAVE_FILE_PATH: String = "user://odisseia_save.json"

func add_item(id: String, item_name: String, icon_path: String, description: String, usage: String) -> void:
	for item in inventory:
		if item["id"] == id:
			return
	inventory.append({
		"id": id,
		"name": item_name,
		"icon": icon_path,
		"description": description,
		"usage": usage
	})

func has_item(id: String) -> bool:
	for item in inventory:
		if item["id"] == id:
			return true
	return false

func remove_item(id: String) -> void:
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i]["id"] == id:
			inventory.remove_at(i)
			break

func get_item(id: String) -> Dictionary:
	for item in inventory:
		if item["id"] == id:
			return item
	return {}

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
	player_damage = 3
	player_dash_cooldown = 3.0
	player_intellect = 5
	guard_detection_mult = 1.0
	highest_unlocked_level = 1
	inventory = []
	
	suspicion_changed.emit(suspicion)
	player_stats_changed.emit()
	player_health_changed.emit(player_current_hp)

func unlock_level(level: int) -> void:
	if level > highest_unlocked_level:
		highest_unlocked_level = level
		save_game()

func save_game() -> void:
	var save_data = {
		"highest_unlocked_level": highest_unlocked_level,
		"player_age": player_age,
		"player_max_hp": player_max_hp,
		"player_current_hp": player_current_hp,
		"player_speed_mult": player_speed_mult,
		"player_damage": player_damage,
		"player_dash_cooldown": player_dash_cooldown,
		"player_intellect": player_intellect,
		"guard_detection_mult": guard_detection_mult,
		"inventory": inventory
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		var err = json.parse(content)
		if err == OK:
			var data = json.get_data()
			highest_unlocked_level = data.get("highest_unlocked_level", 1)
			player_age = data.get("player_age", 20)
			player_max_hp = data.get("player_max_hp", 10)
			player_current_hp = data.get("player_current_hp", 10)
			player_speed_mult = data.get("player_speed_mult", 1.0)
			player_damage = data.get("player_damage", 3)
			player_dash_cooldown = data.get("player_dash_cooldown", 3.0)
			player_intellect = data.get("player_intellect", 5)
			guard_detection_mult = data.get("guard_detection_mult", 1.0)
			inventory = data.get("inventory", [])
			
			player_stats_changed.emit()
			player_health_changed.emit(player_current_hp)
			return true
	return false

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func enable_combat_mode() -> void:
	combat_mode = true
	game_over = false
	has_player_moved = false
	suspicion_changed.emit(suspicion)

func heal_fully() -> void:
	game_over = false
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
	if player_speed_mult < 0.3: player_speed_mult = 0.3
	
	# Inteligência reduz a velocidade de detecção (aumenta furtividade). Base é 5.
	guard_detection_mult = clamp(1.0 - (player_intellect - 5) * 0.1, 0.4, 2.0)
	
	player_current_hp = clampi(player_current_hp, 0, player_max_hp)
	
	player_stats_changed.emit()
	player_health_changed.emit(player_current_hp)
