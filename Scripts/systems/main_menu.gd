extends Node

@export_file_path("*.tscn") var game_scene_path: String

@export var title: Control
@export var main_buttons: VBoxContainer
@export var first_button: Button

@export var settings: Panel
@export var credits: Panel

func _ready() -> void:
	show_main_menu()
	first_button.call_deferred("grab_focus")
	
	AudioManager.play_music("main_menu")

func show_main_menu() -> void:
	title.visible = true
	main_buttons.visible = true
	settings.visible = false
	credits.visible = false

func _on_start_button_pressed() -> void:
	if game_scene_path:
		AudioManager.play_music("battle")
		get_tree().change_scene_to_file(game_scene_path)
	else:
		print("No game scene assigned.")

func _on_settings_button_pressed() -> void:
	title.visible = false
	main_buttons.visible = false
	settings.visible = true

func _on_credits_button_pressed() -> void:
	title.visible = false
	main_buttons.visible = false
	credits.visible = true

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	show_main_menu()
