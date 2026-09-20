extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

const SETTINGS_FILE_PATH: String = "user://settings.json"

var master_vol: float = 0.5
var music_vol: float = 0.5
var sfx_vol: float = 0.5

func _ready() -> void:
	load_settings()

func play_music(stream: AudioStream) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(stream: AudioStream) -> void:
	if stream != null:
		sfx_player.stream = stream
		sfx_player.play()

# Funções auxiliares prontas para os efeitos sonoros do usuário
func play_sword_sfx() -> void:
	if ResourceLoader.exists("res://Assets/sfx_sword.wav"):
		play_sfx(load("res://Assets/sfx_sword.wav"))

func play_bow_sfx() -> void:
	if ResourceLoader.exists("res://Assets/sfx_bow.wav"):
		play_sfx(load("res://Assets/sfx_bow.wav"))

func play_damage_sfx() -> void:
	if ResourceLoader.exists("res://Assets/sfx_damage.wav"):
		play_sfx(load("res://Assets/sfx_damage.wav"))

func play_dash_sfx() -> void:
	if ResourceLoader.exists("res://Assets/sfx_dash.wav"):
		play_sfx(load("res://Assets/sfx_dash.wav"))

func set_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index < 0: return
	
	# Converte 0.0-1.0 linear para decibéis
	var db = linear_to_db(value)
	if value <= 0.01:
		db = -80.0 # Mute total
		
	AudioServer.set_bus_volume_db(bus_index, db)
	
	if bus_name == "Master": master_vol = value
	elif bus_name == "Music": music_vol = value
	elif bus_name == "SFX": sfx_vol = value
	
	save_settings()

func save_settings() -> void:
	var settings = {
		"master_vol": master_vol,
		"music_vol": music_vol,
		"sfx_vol": sfx_vol
	}
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		# Applica os padrões
		set_volume("Master", 0.5)
		set_volume("Music", 0.5)
		set_volume("SFX", 0.5)
		return
		
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			master_vol = data.get("master_vol", 0.5)
			music_vol = data.get("music_vol", 0.5)
			sfx_vol = data.get("sfx_vol", 0.5)
			
			set_volume("Master", master_vol)
			set_volume("Music", music_vol)
			set_volume("SFX", sfx_vol)
