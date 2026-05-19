extends CharacterBody3D

@export_group("Nodes")
@export var anim_sprite: AnimatedSprite3D
@export var nav_agent: NavigationAgent3D
@export var attack_area: Area3D
@export var attack_timer: Timer
@export var explosion_vfx: GPUParticles3D
#@export var game_over: Control

@export_group("Stats")
@export var max_hp := 100
@export var atk := 90
@export var speed := 10.0
@onready var healthbar = $SubViewport/Hp

var player: CharacterBody3D
var has_exploded := false
var is_winding_up := false

var hp := max_hp

var is_alive := true
var is_moving := false

var can_move := true
var can_attack := false

var move_dir := Vector3.ZERO

# == CONSTANTS ==
const GRAVITY_MULTIPLIER := 4.5

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_alive:
		queue_free()
		return
	
	if not is_on_floor():
		_apply_gravity(delta)
	
	if can_move and player.is_alive:
		_move(player.global_position, delta)
	else:
		velocity = Vector3.ZERO
	
	if player.is_alive:
		_attack()
	
	_update_animation()
	
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	velocity += get_gravity() * GRAVITY_MULTIPLIER * delta

func _move(target: Vector3, delta: float) -> void:
	nav_agent.set_target_position(Vector3(target.x, 0, target.z))
	var dest = nav_agent.get_next_path_position()
	if global_position.distance_to(Vector3(target.x, 0, target.z)) < 0.5:
		can_move = false
		return
	move_dir = (dest - global_position).normalized()
	velocity = move_dir * speed
	_face_target(delta)
	is_moving = true

func _face_target(delta: float) -> void:
	move_dir.y = 0
	rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z), 50.0 * delta)

func _attack() -> void:
	if has_exploded or is_winding_up:
		return
		
	var bodies := attack_area.get_overlapping_bodies()
	
	if bodies.size() == 0:
		return
		

	if not attack_timer.is_stopped():
		return
	
	for body in bodies:
		if body and body.has_method("hit") and body.is_in_group("player"):
			is_winding_up = true
			can_move = false
			velocity = Vector3.ZERO

			# optional: play attack animation
			anim_sprite.curAnim = anim_sprite.State.ATTACK_LEFT

			await get_tree().create_timer(0.09).timeout  

			if has_exploded:
				return

			has_exploded = true
			is_alive = false

			AudioManager.play_sfx("explosion")

			attack_area.monitoring = false
			set_physics_process(false)

			anim_sprite.visible = false
			explosion_vfx.visible = true
			explosion_vfx.emitting = true
			
			for b in bodies:
				if b and b.is_in_group("player") and b.has_method("hit"):
					if global_position.distance_to(b.global_position) <= 4.5:
						b.hit(atk)
						
			healthbar.visible = false
			await get_tree().create_timer(1.0).timeout
			queue_free()
		else:
			can_move = true

func hit(damage: int) -> void:
	if (hp - damage) > 0:
		hp -= damage
		anim_sprite.set("modulate", Color.BLACK)
		AudioManager.play_sfx("hurt")
	else:
		hp = 0
		is_alive = false
	
	healthbar.health = hp	
	
	#print("enemy hp : ", hp)
	await get_tree().create_timer(0.1).timeout
	anim_sprite.set("modulate", Color.WHITE)


func _update_animation():
	var forward_dot = move_dir.dot(Vector3(0, 0, -1))
	var back_dot    = move_dir.dot(Vector3(0, 0, 1))
	var right_dot   = move_dir.dot(Vector3(1, 0, 0))
	var left_dot    = move_dir.dot(Vector3(-1, 0, 0))

	var max_val = max(forward_dot, back_dot, right_dot, left_dot)
	
	if can_attack:
		if max_val == left_dot:
			anim_sprite.set("flip_h",false)
		elif max_val == right_dot:
			anim_sprite.set("flip_h",true)
		anim_sprite.curAnim = anim_sprite.State.ATTACK_LEFT

	# Movement direction based animation
	elif is_moving:
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



func _on_attack_timer_timeout() -> void:
	can_attack = true
