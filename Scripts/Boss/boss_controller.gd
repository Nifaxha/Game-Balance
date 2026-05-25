extends CharacterBody3D

@export_group("Nodes")
@export var anim_sprite: AnimatedSprite3D
@export var as_vfx: AnimatedSprite3D
@export var nav_agent: NavigationAgent3D
@export var attack_area: Area3D
@export var attack_timer: Timer
@export var hp_label: Label3D

@export_group("Stats")
@export var max_hp := 2000 # HP lebih besar untuk boss
@export var atk := 80      # Attack lebih besar
@export var speed := 3.5   # Speed bisa disesuaikan
@onready var healthbar = $SubViewport/Hp

var player: CharacterBody3D

var hp := max_hp

var is_alive := true
var is_moving := false
var is_hurt := false

var can_move := true
var is_attacking := false # Menggantikan can_attack untuk merepresentasikan state kombo

var attack_ready := true

var move_dir := Vector3.ZERO

# Konstanta Combo
const COMBO_HITS := 3
const COMBO_WINDUP := 0.6
const COMBO_DELAY := 0.4
const ATTACK_COOLDOWN := 2.5

# == CONSTANTS ==
const GRAVITY_MULTIPLIER := 4.5

func _ready() -> void:
	hp = max_hp
	if healthbar:
		healthbar.init_health(hp)
	player = get_tree().get_first_node_in_group("player")
	if as_vfx:
		as_vfx.stop()
		as_vfx.visible = false

func _physics_process(delta: float) -> void:
	if not is_alive:
		queue_free()
		return
	
	if not is_on_floor():
		_apply_gravity(delta)
	
	if can_move and player and player.is_alive and not is_attacking:
		_move(player.global_position, delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_moving = false
	
	if player and player.is_alive:
		_check_for_attack()
	
	_update_animation()
	
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	velocity += get_gravity() * GRAVITY_MULTIPLIER * delta

func _move(target: Vector3, delta: float) -> void:
	if nav_agent:
		nav_agent.set_target_position(Vector3(target.x, 0, target.z))
		var dest = nav_agent.get_next_path_position()
		
		# Jarak serang
		if global_position.distance_to(Vector3(target.x, 0, target.z)) < 2.0: 
			return
			
		move_dir = (dest - global_position).normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		_face_target(delta)
		is_moving = true

func _face_target(delta: float) -> void:
	move_dir.y = 0
	if move_dir.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z), 10.0 * delta)

# == LOGIKA SERANGAN BOSS (COMBO) ==

func _check_for_attack() -> void:
	if not attack_ready or is_attacking:
		return
	
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			_perform_combo_attack()
			return # Langsung keluar setelah memicu kombo

func _perform_combo_attack() -> void:
	is_attacking = true
	can_move = false
	attack_ready = false
	
	for i in range(COMBO_HITS):
		if not is_alive: return
		
		# 1. Windup (Memberi waktu pemain menyiapkan Dash)
		# Jika ada animasi persiapan, mainkan di sini
		await get_tree().create_timer(COMBO_WINDUP).timeout
		
		# 2. Eksekusi Hit
		if as_vfx:
			as_vfx.visible = true
			as_vfx.play("attack")
		
		_deal_damage()
		AudioManager.play_sfx("attack")
		
		# 3. Jeda antar ayunan
		await get_tree().create_timer(COMBO_DELAY).timeout
	
	# Kombo selesai, cooldown sebelum bisa serang lagi
	is_attacking = false
	can_move = true
	
	# Mulai timer cooldown menggunakan script, atau kamu bisa pakai node Timer jika mau
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	attack_ready = true

func _deal_damage() -> void:
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		# Pengecekan is_dashing sudah di-handle di hit() milik player_controller
		if body.is_in_group("player") and body.has_method("hit"):
			body.hit(atk)

# == INTERAKSI & ANIMASI ==

func hit(damage: int) -> void:
	if (hp - damage) > 0:
		hp -= damage
		is_hurt = true
		if anim_sprite:
			anim_sprite.set("modulate", Color.BLACK)
		AudioManager.play_sfx("hurt")
		await get_tree().create_timer(0.3).timeout
		if anim_sprite:
			anim_sprite.set("modulate", Color.WHITE)
		is_hurt = false
	else:
		hp = 0
		is_alive = false
	if healthbar:
		healthbar.health = hp

func _update_animation():
	if not anim_sprite: return
	
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

# Fungsi timeout ini mungkin tidak diperlukan lagi jika kita pakai await untuk attack cooldown, 
# tapi dibiarkan kosong agar tidak error jika node timer masih terhubung.
func _on_attack_timer_timeout() -> void:
	pass
