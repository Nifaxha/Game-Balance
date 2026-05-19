extends Node

@export var waveSpawner := Node3D
@export var mask : StaticBody3D

func _process(_delta: float) -> void:
	if waveSpawner.victory:
		AudioManager.play_sfx("win")
		mask.visible = true
		waveSpawner.victory = false
