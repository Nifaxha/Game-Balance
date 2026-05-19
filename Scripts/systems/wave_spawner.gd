extends Node3D

@export_group("Configuration")
@export var wave_patterns: Array[WaveSettings]
@export var delay_between_waves: float = 1.0

@export_group("Nodes")
@export var enemy_spawn_points: Array[Marker3D]

var player: CharacterBody3D

var current_wave_index: int = 0
var spawn_queue: Array[PackedScene] = []
var wave_timer: Timer
var spawn_timer: Timer

var active_enemies: Array[Node] = []

var victory := false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_setup_timers()
	start_next_wave()

func _setup_timers() -> void:
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	wave_timer.timeout.connect(start_next_wave)
	add_child(wave_timer)
	
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_spawn_next_in_queue)
	add_child(spawn_timer)

func start_next_wave() -> void:
	if not player.is_alive or current_wave_index >= wave_patterns.size():
		return
		
	var wave_config = wave_patterns[current_wave_index]
	spawn_queue.clear()

	for entry in wave_config.enemy_list:
		for i in range(entry.count):
			spawn_queue.append(entry.enemy_prefab)

	spawn_timer.wait_time = wave_config.spawn_delay
	spawn_timer.start()

func _spawn_next_in_queue() -> void:
	if not player.is_alive or spawn_queue.is_empty():
		spawn_timer.stop()
		return

	var enemy_prefab = spawn_queue.pop_front()
	var spawn_point = enemy_spawn_points.pick_random()
	
	var enemy_instance = enemy_prefab.instantiate()
	get_parent().add_child(enemy_instance)
	enemy_instance.global_transform = spawn_point.global_transform
	
	active_enemies.append(enemy_instance)
	
	enemy_instance.tree_exited.connect(_on_enemy_destroyed.bind(enemy_instance))
	
	if spawn_queue.is_empty():
		spawn_timer.stop()

func _on_enemy_destroyed(enemy: Node) -> void:
	active_enemies.erase(enemy)
	
	if active_enemies.is_empty() and spawn_queue.is_empty():
		_finish_wave()

func _finish_wave() -> void:
	current_wave_index += 1
	
	if current_wave_index >= wave_patterns.size():
		_victory()
	else:
		print("Wave cleared! Next wave in: ", delay_between_waves)
		wave_timer.start(delay_between_waves)

func _victory() -> void:
	victory = true
	print("All waves completed! Player wins.")
