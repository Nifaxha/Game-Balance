extends Panel

@export var audio_bus_names: Array[String] = ["Master", "Music", "SFX"]
var audio_bus_indices : Array[int] = []

func _ready() -> void:
	for bus_names in audio_bus_names:
		var idx = AudioServer.get_bus_index(bus_names)
		audio_bus_indices.append(idx)

func _on_fullscreen_control_toggled(toggled_on: bool, _source: BaseButton) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_music_slider_value_changed(value: float, _source: Range) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_indices[1], db)

func _on_sfx_slider_value_changed(value: float, _source: Range) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_indices[2], db)
