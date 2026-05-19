extends CharacterBody3D

@export_group("Nodes")
@export var anim_sprite: AnimatedSprite3D
@export var as_vfx: AnimatedSprite3D
@export var nav_agent: NavigationAgent3D
@export var attack_area: Area3D
@export var attack_timer: Timer
@export var hp_label: Label3D
#@export var game_over: Control

@export_group("Stats")
@export var max_hp := 350
@export var atk := 30
@export var speed := 5.0
@onready var healthbar = $SubViewport/Hp

var player: CharacterBody3D

var hp := max_hp

var is_alive := true
var is_moving := false
var is_hurt := false

var can_move := true
var can_attack := false
var is_winding_up := false

var attack_ready := false

var move_dir := Vector3.ZERO

# == CONSTANTS ==
const GRAVITY_MULTIPLIER := 4.5

func _ready() -> void:
	hp = max_hp
	healthbar.init_health(hp)
	attack_ready = true
	player = get_tree().get_first_node_in_group("player")
	as_vfx.stop()
	as_vfx.visible = false

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

func start_attack_with_delay(delay := 0.3):
	if can_attack or is_winding_up:
		return

	is_winding_up = true
	can_move = false

	await get_tree().create_timer(delay).timeout

	is_winding_up = false
	can_attack = true


func _attack() -> void:
	if not attack_timer.is_stopped():
		return
	
	var bodies := attack_area.get_overlapping_bodies()
	
	if bodies.size() == 0:
		can_attack = false
		return
	
	for body in bodies:
		if body and body.has_method("hit") and body.is_in_group("player"):
			can_attack = true
			can_move = false
			
			if can_attack and attack_ready:
				attack_ready =  false
				await get_tree().create_timer(0.45).timeout
				as_vfx.visible = true
				as_vfx.play("attack")
				attack_timer.start()
				can_move = false
				
				var hit_bodies := attack_area.get_overlapping_bodies()
				if body in hit_bodies:
					body.hit(atk)

				AudioManager.play_sfx("attack")
		else:
			can_move = true

func hit(damage: int) -> void:
	if (hp - damage) > 0:
		hp -= damage
		is_hurt = true
		anim_sprite.set("modulate", Color.BLACK)
		AudioManager.play_sfx("hurt")
		await get_tree().create_timer(0.3).timeout
		anim_sprite.set("modulate", Color.WHITE)
		is_hurt = false
	else:
		hp = 0
		is_alive = false
	healthbar.health = hp
	#print("enemy hp : ", hp)
	

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
	
	if can_attack:
		if max_val == left_dot:
			anim_sprite.set("flip_h",false)
		elif max_val == right_dot:
			anim_sprite.set("flip_h",true)
		anim_sprite.curAnim = anim_sprite.State.ATTACK_LEFT
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



func _on_attack_timer_timeout() -> void:
	if can_attack:
		can_attack = false
	attack_ready = true
