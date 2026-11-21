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
var circe_moly_found: bool = false
var circe_search_completed: bool = false
var circe_battle_completed: bool = false
var underworld_crossing_completed: bool = false
var underworld_prophecy_completed: bool = false
var underworld_mother_heard: bool = false
var underworld_checkpoint: int = 0
var underworld_vision_index: int = 0
const UNDERWORLD_VISION_COUNT := 6
var sirens_completed: bool = false
var scylla_completed: bool = false
var mutiny_completed: bool = false
var ogygia_paths_completed: bool = false
var calypso_completed: bool = false
var charybdis_completed: bool = false
var final_poseidon_completed: bool = false
var ithaca_completed: bool = false
const SAVE_FILE_PATH: String = "user://odisseia_save.json"
const STANDALONE_STAGES := [
	"res://Ato5_Circe/Gameplay/CirceForest.tscn",
	"res://Ato5_Circe/Gameplay/CirceBattle.tscn",
	"res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn",
	"res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn",
	"res://Ato7_Sereias/Gameplay/SirenCove.tscn",
	"res://Ato8_Cila/Gameplay/ScyllaPassage.tscn",
	"res://Ato9_Motim/Gameplay/Mutiny.tscn",
	"res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn",
	"res://Ato10_Calipso/Gameplay/CalypsoDeparture.tscn",
	"res://Ato11_Caribdis/Gameplay/Charybdis.tscn",
	"res://Ato12_Poseidon/Gameplay/FinalPoseidon.tscn",
	"res://Ato13_Itaca/Gameplay/Ithaca.tscn",
]
# Tests and isolated previews can opt out or redirect persistence without
# touching the player's campaign file.
var persistence_enabled: bool = true
var save_file_path: String = SAVE_FILE_PATH
var standalone_stage_preview := false

func _ready() -> void:
	if not OS.has_feature("editor"): return
	# F6 supplies the scene as a startup argument. Campaign transitions do not.
	for argument in OS.get_cmdline_args():
		var path := argument
		if path.begins_with("uid://"):
			var id := ResourceUID.text_to_id(path)
			if not ResourceUID.has_id(id): continue
			path=ResourceUID.get_id_path(id)
		elif path.ends_with(".tscn") and not path.begins_with("res://"):
			if path.is_relative_path(): path="res://"+path
			else: path=ProjectSettings.localize_path(path)
		if path in STANDALONE_STAGES:
			standalone_stage_preview=true
			persistence_enabled=false
			return

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
	circe_moly_found = false
	circe_search_completed = false
	circe_battle_completed = false
	underworld_crossing_completed = false
	underworld_prophecy_completed = false
	underworld_mother_heard = false
	underworld_checkpoint = 0
	underworld_vision_index = 0
	sirens_completed = false
	scylla_completed = false
	mutiny_completed = false
	ogygia_paths_completed = false
	calypso_completed = false
	charybdis_completed = false
	final_poseidon_completed = false
	ithaca_completed = false
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

func collect_circe_moly() -> void:
	circe_moly_found = true
	highest_unlocked_level = maxi(5, highest_unlocked_level)
	add_item("holimoli", "Holimoli", "res://Assets/act5_circe/moly_icon.tres",
		"Flor de pétalas brancas e raiz negra, encontrada com a orientação de Hermes.",
		"Protege Odisseu dos feitiços de Circe. O efeito é automático; não é consumida na busca.")
	save_game()
	act4_progress_changed.emit()

func complete_circe_search() -> void:
	if not circe_moly_found: return
	circe_search_completed = true
	save_game()
	act4_progress_changed.emit()

func complete_circe_battle() -> void:
	if not circe_moly_found or not circe_search_completed: return
	circe_battle_completed=true
	save_game()
	act4_progress_changed.emit()

func record_underworld_checkpoint(index: int) -> void:
	if not circe_battle_completed: return
	underworld_checkpoint=maxi(underworld_checkpoint,clampi(index,0,2))
	highest_unlocked_level=maxi(6,highest_unlocked_level)
	save_game()

func record_underworld_mother() -> void:
	if not circe_battle_completed: return
	underworld_mother_heard=true
	save_game()

func complete_underworld_crossing() -> void:
	if not circe_battle_completed: return
	underworld_crossing_completed=true
	highest_unlocked_level=maxi(6,highest_unlocked_level)
	underworld_checkpoint=2
	save_game()
	act4_progress_changed.emit()

func record_underworld_vision(index: int) -> void:
	if not underworld_crossing_completed: return
	underworld_vision_index=maxi(underworld_vision_index,clampi(index,0,UNDERWORLD_VISION_COUNT))
	save_game()

func complete_underworld_prophecy() -> void:
	if not underworld_crossing_completed or underworld_vision_index<UNDERWORLD_VISION_COUNT: return
	underworld_prophecy_completed=true
	highest_unlocked_level = maxi(7, highest_unlocked_level)
	save_game()
	act4_progress_changed.emit()

func complete_sirens(remaining_hp: int) -> void:
	if not underworld_prophecy_completed or sirens_completed or remaining_hp <= 0:
		return
	sirens_completed = true
	highest_unlocked_level = maxi(8, highest_unlocked_level)
	player_current_hp = mini(remaining_hp, player_max_hp)
	player_health_changed.emit(player_current_hp)
	save_game()
	act4_progress_changed.emit()

func complete_scylla() -> void:
	if not sirens_completed or scylla_completed:
		return
	scylla_completed = true
	highest_unlocked_level = maxi(9, highest_unlocked_level)
	save_game()
	act4_progress_changed.emit()

func complete_mutiny(remaining_hp: int) -> void:
	if not scylla_completed or mutiny_completed or remaining_hp <= 0:
		return
	mutiny_completed = true
	highest_unlocked_level = maxi(10, highest_unlocked_level)
	player_current_hp = mini(remaining_hp, player_max_hp)
	player_health_changed.emit(player_current_hp)
	save_game()
	act4_progress_changed.emit()

func complete_ogygia_paths() -> void:
	if not mutiny_completed or ogygia_paths_completed:
		return
	ogygia_paths_completed = true
	save_game()
	act4_progress_changed.emit()

func complete_calypso() -> void:
	if not ogygia_paths_completed or calypso_completed:
		return
	calypso_completed = true
	highest_unlocked_level = maxi(11, highest_unlocked_level)
	save_game()
	act4_progress_changed.emit()

func complete_charybdis() -> void:
	if not calypso_completed or charybdis_completed:
		return
	charybdis_completed = true
	highest_unlocked_level = maxi(12, highest_unlocked_level)
	save_game()
	act4_progress_changed.emit()

func complete_final_poseidon(remaining_hp: int) -> void:
	if not charybdis_completed or final_poseidon_completed or remaining_hp <= 0:
		return
	final_poseidon_completed = true
	highest_unlocked_level = maxi(13, highest_unlocked_level)
	player_current_hp = mini(remaining_hp, player_max_hp)
	player_health_changed.emit(player_current_hp)
	save_game()
	act4_progress_changed.emit()

func complete_ithaca(remaining_hp: int) -> void:
	if not final_poseidon_completed or ithaca_completed or remaining_hp <= 0:
		return
	ithaca_completed = true
	player_current_hp = mini(remaining_hp, player_max_hp)
	player_health_changed.emit(player_current_hp)
	save_game()
	act4_progress_changed.emit()

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
		"circe_moly_found": circe_moly_found,
		"circe_search_completed": circe_search_completed,
		"circe_battle_completed": circe_battle_completed,
		"underworld_crossing_completed": underworld_crossing_completed,
		"underworld_prophecy_completed": underworld_prophecy_completed,
		"underworld_mother_heard": underworld_mother_heard,
		"underworld_checkpoint": underworld_checkpoint,
		"underworld_vision_index": underworld_vision_index,
		"sirens_completed": sirens_completed,
		"scylla_completed": scylla_completed,
		"mutiny_completed": mutiny_completed,
		"ogygia_paths_completed": ogygia_paths_completed,
		"calypso_completed": calypso_completed,
		"charybdis_completed": charybdis_completed,
		"final_poseidon_completed": final_poseidon_completed,
		"ithaca_completed": ithaca_completed,
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
			circe_moly_found = bool(data.get("circe_moly_found", false)) or has_item("holimoli")
			circe_search_completed = bool(data.get("circe_search_completed", false)) and circe_moly_found
			circe_battle_completed = bool(data.get("circe_battle_completed", false)) and circe_search_completed
			underworld_crossing_completed = bool(data.get("underworld_crossing_completed",false)) and circe_battle_completed
			underworld_vision_index = clampi(int(data.get("underworld_vision_index",0)),0,UNDERWORLD_VISION_COUNT) if underworld_crossing_completed else 0
			var finished_prophecy := bool(data.get("underworld_prophecy_completed",false))
			# The earlier version ended after three visions. Preserve completed campaigns.
			if finished_prophecy and underworld_vision_index == 3:
				underworld_vision_index = UNDERWORLD_VISION_COUNT
			underworld_prophecy_completed = finished_prophecy and underworld_crossing_completed and underworld_vision_index == UNDERWORLD_VISION_COUNT
			underworld_checkpoint = clampi(int(data.get("underworld_checkpoint",0)),0,2) if circe_battle_completed else 0
			underworld_mother_heard = bool(data.get("underworld_mother_heard",false)) and circe_battle_completed
			sirens_completed = bool(data.get("sirens_completed", false)) and underworld_prophecy_completed
			scylla_completed = bool(data.get("scylla_completed", false)) and sirens_completed
			mutiny_completed = bool(data.get("mutiny_completed", false)) and scylla_completed
			ogygia_paths_completed = bool(data.get("ogygia_paths_completed", false)) and mutiny_completed
			calypso_completed = bool(data.get("calypso_completed", false)) and ogygia_paths_completed
			charybdis_completed = bool(data.get("charybdis_completed", false)) and calypso_completed
			final_poseidon_completed = bool(data.get("final_poseidon_completed", false)) and charybdis_completed
			ithaca_completed = bool(data.get("ithaca_completed", false)) and final_poseidon_completed
			if final_poseidon_completed:
				highest_unlocked_level = maxi(13, highest_unlocked_level)
			elif charybdis_completed:
				highest_unlocked_level = maxi(12, highest_unlocked_level)
			elif calypso_completed:
				highest_unlocked_level = maxi(11, highest_unlocked_level)
			elif mutiny_completed:
				highest_unlocked_level = maxi(10, highest_unlocked_level)
			elif scylla_completed:
				highest_unlocked_level = maxi(9, highest_unlocked_level)
			elif sirens_completed:
				highest_unlocked_level = maxi(8, highest_unlocked_level)
			elif underworld_prophecy_completed:
				highest_unlocked_level = maxi(7, highest_unlocked_level)
			
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
