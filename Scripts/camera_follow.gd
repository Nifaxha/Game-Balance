extends Camera3D

@export var target: CharacterBody3D

@export_group("Config")
@export var offset: Vector3 = Vector3(0, 3, 10)
@export var follow_speed: float = 5.0 

func _physics_process(delta: float) -> void:
	if not target:
		return

	var target_pos = target.global_position + offset
	
	global_position = global_position.lerp(target_pos, follow_speed * delta)
