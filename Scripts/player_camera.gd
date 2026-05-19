extends Node3D

# === Nodes ===
@export_group("Nodes")
@export var player: CharacterBody3D

# === Configuration ===
@export_group("Configs")
@export var mouse_sensitivity := 0.002
@export var auto_follow_sensitivity := 1.0
@export var arrow_sensitivity := 135
@export var turn_around_sensitivity := 10.0

@export_range(-90.0, 0.0, 0.1, "radians_as_degrees")
var min_vertical_angle: float = -PI / 2

@export_range(0.0, 90.0, 0.1, "radians_as_degrees")
var max_vertical_angle: float = PI / 4

@onready var camera_end_pos: Node3D = $SpringArm3D/CameraEndPos

# === Constants ===
const DEFAULT_PITCH := deg_to_rad(-25)
const DOUBLE_PRESS_INTERVAL := 0.3  # seconds

# === State ===
var mouse_captured := false
var look_rotation := Vector3.ZERO
var target_look_rotation := Vector3.ZERO
var is_rotating_180 := false
var mouse_idle_time := 0.0
var last_move_down_press_time := 0.0

#local var
var follow_speed: float = 25.0

# === Lifecycle ===
func _ready() -> void:
	_capture_mouse()

func _process(delta: float) -> void:
	if not mouse_captured:
		return

	_handle_arrow_input(delta)
	mouse_idle_time += delta

	_handle_double_press()
	
	_update_head_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_capture_mouse()
		mouse_idle_time = 0.0
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mouse_idle_time = 0.0
	elif Input.is_key_pressed(KEY_ESCAPE):
		_release_mouse()

	if mouse_captured and event is InputEventMouseMotion:
		_rotate_look(event.relative)
		mouse_idle_time = 0.0

# === Input Handlers ===

func _rotate_look(rot_input: Vector2) -> void:
	look_rotation.x = clamp(look_rotation.x - rot_input.y * mouse_sensitivity, min_vertical_angle, max_vertical_angle)
	look_rotation.y -= rot_input.x * mouse_sensitivity
	_update_head_rotation()

func _handle_arrow_input(delta: float) -> void:
	if is_rotating_180:
		return

	var yaw_input := int(Input.is_action_pressed("ui_left")) - int(Input.is_action_pressed("ui_right"))
	var pitch_input := int(Input.is_action_pressed("ui_up")) - int(Input.is_action_pressed("ui_down"))

	if yaw_input or pitch_input:
		mouse_idle_time = 0.0
		var rad_per_sec := deg_to_rad(arrow_sensitivity)
		look_rotation.y += yaw_input * rad_per_sec * delta
		look_rotation.x = clamp(look_rotation.x + pitch_input * rad_per_sec * delta, min_vertical_angle, max_vertical_angle)

func _handle_double_press() -> void:
	if Input.is_action_just_pressed("move_back"):
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time - last_move_down_press_time < DOUBLE_PRESS_INTERVAL:
			_rotate_camera_180()
			last_move_down_press_time = 0.0
		else:
			last_move_down_press_time = current_time


# === Mouse Capture ===
func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

# === Utility ===
func _update_head_rotation() -> void:
	var x_rot := Basis(Vector3.RIGHT, look_rotation.x)
	var y_rot := Basis(Vector3.UP, look_rotation.y)
	transform.basis = y_rot * x_rot

func _rotate_camera_180() -> void:
	target_look_rotation = look_rotation
	target_look_rotation.y = wrapf(look_rotation.y + PI, -PI, PI)
	is_rotating_180 = true
	#print("Camera starting 180-degree smooth rotation")
