extends Node3D

@export var sceneFile : PackedScene

var next_scene : String

func _ready() -> void:
	next_scene = sceneFile.resource_path
	visible = false

func interact() -> void:
	AudioManager.play_sfx("pickup")
	visible = false
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file(next_scene)
	queue_free()
