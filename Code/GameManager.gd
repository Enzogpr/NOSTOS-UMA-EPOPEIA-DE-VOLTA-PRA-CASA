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
signal act4_progress_changed

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
var act4_unlocked_stage: int = 0
var act4_completed: bool = false
const SAVE_FILE_PATH: String = "user://odisseia_save.json"
# Tests and isolated previews can opt out or redirect persistence without
# touching the player's campaign file.
var persistence_enabled: bool = true
var save_file_path: String = SAVE_FILE_PATH

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

func reset_encounter() -> void:
	suspicion = 0.0
	game_over = false
	combat_mode = false
	has_player_moved = false
	suspicion_changed.emit(suspicion)

func reset() -> void:
	reset_encounter()
	
	player_age = 20
	player_max_hp = 10
	player_current_hp = 10
	player_speed_mult = 1.0
	player_damage = 3
	player_dash_cooldown = 3.0
	player_intellect = 5
	guard_detection_mult = 1.0
	highest_unlocked_level = 1
	act4_unlocked_stage = 0
	act4_completed = false
	inventory = []
	
	player_stats_changed.emit()
	player_health_changed.emit(player_current_hp)
	act4_progress_changed.emit()

func unlock_level(level: int) -> void:
	if level > highest_unlocked_level:
		highest_unlocked_level = level
		save_game()
		act4_progress_changed.emit()

func unlock_act4_stage(stage: int) -> void:
	var next_stage: int=clampi(stage,0,3)
	if highest_unlocked_level>=4 and next_stage<=act4_unlocked_stage: return
	highest_unlocked_level=maxi(4,highest_unlocked_level)
	act4_unlocked_stage=maxi(act4_unlocked_stage,next_stage)
	act4_progress_changed.emit()
	save_game()

func complete_act4() -> void:
	if act4_completed: return
	highest_unlocked_level=maxi(4,highest_unlocked_level)
	act4_unlocked_stage=3
	act4_completed=true
	act4_progress_changed.emit()
	save_game()

func _read_journey_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _restore_act4_progress(data: Dictionary) -> void:
	act4_unlocked_stage=clampi(int(data.get("act4_unlocked_stage",0)),0,3)
	act4_completed=bool(data.get("act4_completed",false))
	if highest_unlocked_level<4:
		act4_unlocked_stage=0
		act4_completed=false
		return
	if act4_completed:
		act4_unlocked_stage=3
		return
	if data.has("act4_unlocked_stage"): return
	# Old saves only knew the act number. Recover completed chapters from their
	# existing records in the same save directory, without rewriting on load.
	var directory: String=ProjectSettings.globalize_path(save_file_path).get_base_dir()
	var vigil: Dictionary=_read_journey_record(directory.path_join("vigil_record.json"))
	var last_run: Variant=vigil.get("last_run",{})
	if last_run is Dictionary and bool(last_run.get("story_complete",false)):
		act4_unlocked_stage=3
	var escape: Dictionary=_read_journey_record(directory.path_join("poseidon_escape_record.json"))
	if bool(escape.get("escaped",false)):
		act4_unlocked_stage=3
		act4_completed=bool(escape.get("aftermath_completed",false))

func save_game() -> void:
	if not persistence_enabled: return
	var save_data = {
		"highest_unlocked_level": highest_unlocked_level,
		"act4_unlocked_stage": act4_unlocked_stage,
		"act4_completed": act4_completed,
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
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Não foi possível salvar a campanha: %s" % error_string(FileAccess.get_open_error()))

func load_game() -> bool:
	if not FileAccess.file_exists(save_file_path):
		return false
	var file = FileAccess.open(save_file_path, FileAccess.READ)
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
			_restore_act4_progress(data)
			
			player_stats_changed.emit()
			player_health_changed.emit(player_current_hp)
			act4_progress_changed.emit()
			return true
	return false

func has_save_file() -> bool:
	return FileAccess.file_exists(save_file_path)

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
	save_game()
