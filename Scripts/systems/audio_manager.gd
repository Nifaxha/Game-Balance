extends Node

# CONFIGURATION
@export var music_library: Array[AudioLibraryEntry] = []
@export var sfx_library: Array[AudioLibraryEntry] = []
@export var max_sfx_players: int = 10
@export var music_bus: StringName = &"Music" 
@export var sfx_bus: StringName = &"SFX"

# DATA CACHE
var _music_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}

# NODES
var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_initialize_lookup_tables()
	_initialize_audio_nodes()

# PUBLIC API

func play_music(key: StringName, volume: float = 0.0) -> void:
	var stream: AudioStream = _music_cache.get(key)
	
	if not _is_resource_valid(stream, key): return
	if _is_already_playing(music_player, stream): return
	
	music_player.stream = stream
	music_player.volume_db = volume
	music_player.play()

func play_sfx(key: StringName, volume: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _sfx_cache.get(key)
	
	if not _is_resource_valid(stream, key): return
	
	var player: AudioStreamPlayer = _get_best_available_player()
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()

func stop_music() -> void:
	music_player.stop()

# INITIALIZATION (Functional Setup)

func _initialize_lookup_tables() -> void:
	for entry in music_library:
		_music_cache[entry.key] = entry.stream
		
	for entry in sfx_library:
		_sfx_cache[entry.key] = entry.stream

func _initialize_audio_nodes() -> void:
	music_player = _create_player("MusicPlayer", music_bus)
	
	for i in max_sfx_players:
		sfx_pool.append(_create_player("SFXPlayer_" + str(i), sfx_bus))

func _create_player(node_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = bus_name
	add_child(player)
	return player

# INTERNAL UTILITIES (Guard Clauses & Logic)

func _is_resource_valid(stream: AudioStream, key: StringName) -> bool:
	if stream: return true
	push_warning("AudioManager: Entry missing or not found for key: ", key)
	return false

func _is_already_playing(player: AudioStreamPlayer, stream: AudioStream) -> bool:
	return player.is_playing() and player.stream == stream

func _get_best_available_player() -> AudioStreamPlayer:
	var free_players = sfx_pool.filter(func(p): return not p.is_playing())
	
	if not free_players.is_empty():
		return free_players.front()
	
	return sfx_pool.front()
