extends CharacterBody3D

@export_group("Nodes")
@export var collider: CollisionShape3D
@export var direction: Node3D
@export var anim_sprite: AnimatedSprite3D
@export var as_vfx: AnimatedSprite3D
@export var interact_area: Area3D
@export var attack_area: Area3D
@export var attack_timer: Timer
@export var pop_up_label: Label

@export_group("Stats")
@export var max_hp := 600
@export var atk := 50
@export var speed := 7.0

@onready var healthbar = $CanvasLayer/Control/TexturedHp

var hp := 0

func _ready():
	hp = max_hp
	healthbar.init_health(hp)

#Speeds
var sprint_speed := speed * 1.5
var rotation_speed := 50.0

# == CONSTANTS ==
const GRAVITY_MULTIPLIER := 4.5

# == State ==
var is_alive := true
var is_moving := false
var is_sprint := false
var is_hiding:= false
var is_dashing := false
var is_attacking := false
var is_hurt := false

# local variable
var input_dir := Vector2.ZERO
var move_dir := Vector3.ZERO
var current_speed := 0.0
var camera_basis := Basis.IDENTITY

# == DASH ==
var dash_speed := 25.0
var dash_duration := 0.3
var dash_cooldown := 0.5
var dash_ready := true
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_direction := Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_alive:
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
		return
	
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULTIPLIER * delta

	_handle_interact()

	_handle_dash(delta)
	
	if not is_dashing:
		_apply_movement()

	_update_model_rotation(move_dir,delta)
	_update_animation()
	
	move_and_slide()

func _unhandled_input(_event: InputEvent) -> void:
	if pop_up_label.visible:
		return
	
	if Input.is_action_just_pressed("attack"):
		_attack()

# == MOVEMENT & PHYSICS ==

func _apply_movement() -> void:
	is_sprint = Input.is_action_pressed("sprint")
	if is_sprint :
		current_speed = sprint_speed
		anim_sprite.speed_scale = 1.5
	else:
		current_speed = speed
		anim_sprite.speed_scale = 1.0
	
	camera_basis = Basis(Vector3.UP, rotation.y)
	move_dir = (camera_basis * Vector3(input_dir.x, 0, input_dir.y))
	move_dir = move_dir.normalized()
	
	if move_dir.length_squared() > 0:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		is_moving = false


# == DASHING ==

func _handle_dash(delta: float) -> void:
	# cooldown
	if not dash_ready:
		dash_cooldown_left -= delta
		if dash_cooldown_left <= 0.0:
			dash_ready = true

	# start dash
	if not is_dashing and dash_ready \
	and Input.is_action_just_pressed("dash") and input_dir.length() > 0.1:
		is_dashing = true
		dash_time_left = dash_duration
		dash_ready = false
		dash_cooldown_left = dash_cooldown
		dash_direction = Basis(Vector3.UP, rotation.y) \
			* Vector3(input_dir.x, 0, input_dir.y)
		dash_direction = dash_direction.normalized()

	# handle dash motion
	if is_dashing:
		dash_time_left -= delta
		move_dir = (Basis(Vector3.UP, rotation.y) \
			* Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if (dash_duration - dash_time_left) >= dash_duration / 3.0 \
		and move_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				speed = sprint_speed
			var combined = (dash_direction * dash_speed + move_dir * speed).normalized()
			velocity.x = combined.x * dash_speed
			velocity.z = combined.z * dash_speed
		else:
			velocity.x = dash_direction.x * dash_speed
			velocity.z = dash_direction.z * dash_speed

		if dash_time_left <= 0.0:
			is_dashing = false

		_update_model_rotation(move_dir if move_dir.length() > 0.1 else dash_direction, delta)

# == INTERACT ==
func _handle_interact() -> void:
	var bodies := interact_area.get_overlapping_bodies()
	
	if bodies.size() == 0:
		pop_up_label.visible = false
		return
	
	for body in bodies:
		if body.visible and body.has_method("interact"):
			pop_up_label.visible = true
	
	if pop_up_label.visible and Input.is_action_just_pressed("attack"):
		for body in bodies:
			if body.has_method("interact"):
				body.interact()
				pop_up_label.visible = false

func _attack() -> void:
	if not attack_timer.is_stopped():
		return 
	
	is_attacking = true
	attack_timer.start()
	
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if body and body.has_method("hit") and body.is_in_group("enemy"):
			body.hit(atk)
	
	as_vfx.play("attack")
	AudioManager.play_sfx("attack")
	
	await get_tree().create_timer(attack_timer.wait_time).timeout
	is_attacking = false

func hit(damage: int) -> void:
	if not is_alive:
		return
	
	if is_dashing:
		return
	
	if (hp - damage) > 0:
		hp -= damage
		is_hurt = true
		anim_sprite.set("modulate", Color.RED)
		AudioManager.play_sfx("hurt")
		#print("player hp : ", hp)
		await get_tree().create_timer(0.1).timeout
		anim_sprite.set("modulate", Color.WHITE)
		is_hurt = false
	else:
		hp = 0
		is_alive = false
	healthbar.health = hp

# == VISUALS ==

func _update_model_rotation(target_dir: Vector3, delta: float) -> void:
	if target_dir.length_squared() > 0.0001:
		var target_angle = atan2(target_dir.x, target_dir.z)
		direction.rotation.y = lerp_angle(direction.rotation.y, target_angle, rotation_speed * delta)

func _update_animation():
	var forward_dot = move_dir.dot(Vector3(0, 0, -1))
	var back_dot    = move_dir.dot(Vector3(0, 0, 1))
	var right_dot   = move_dir.dot(Vector3(1, 0, 0))
	var left_dot    = move_dir.dot(Vector3(-1, 0, 0))

	var max_val = max(forward_dot, back_dot, right_dot, left_dot)
	
	if is_hurt:
		if max_val == left_dot:
			anim_sprite.set("flip_h",false)
		elif max_val == right_dot:
			anim_sprite.set("flip_h",true)
		
		anim_sprite.curAnim = anim_sprite.State.HURT
		return
	
	if is_attacking:
		if max_val == left_dot:
			anim_sprite.set("flip_h",false)
		elif max_val == right_dot:
			anim_sprite.set("flip_h",true)
		anim_sprite.curAnim = anim_sprite.State.ATTACK_LEFT
		return
	
	if is_dashing:
		anim_sprite.curAnim = anim_sprite.State.DASH
		return
		

	# Movement direction based animation
	if is_moving:
		if max_val == forward_dot:
			anim_sprite.curAnim = anim_sprite.State.UP
		elif max_val == back_dot:
			anim_sprite.curAnim = anim_sprite.State.DOWN
		elif max_val == right_dot:
			anim_sprite.curAnim = anim_sprite.State.RIGHT
		elif max_val == left_dot:
			anim_sprite.curAnim = anim_sprite.State.LEFT
	else:
		anim_sprite.curAnim = anim_sprite.State.IDLE
