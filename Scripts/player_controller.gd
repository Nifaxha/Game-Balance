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

@export_group("Sanity System")
@export var max_sanity := 100
@export var weapon_skill_cost := 35
var sanity := 100
var is_hollow := false # Status ketika sanity = 0
@onready var healthbar = $CanvasLayer/Control/TexturedHp

# Tambahkan baris ini (sesuaikan path-nya jika berbeda)
var dash_bar: ProgressBar
var dash_label: Label
# @onready var dash_label = $CanvasLayer/Control/DashChargeLabel # (Hapus tanda # jika kamu pakai Label)
# Naik ke Entitys (../) -> naik ke World (../../) -> turun ke CanvasLayer

var hp := 0

func _ready():
	hp = max_hp
	healthbar.init_health(hp)
	
	# Mencari node dari ujung atas Scene (World)
	var scene_root = get_tree().current_scene
	if scene_root:
		dash_bar = scene_root.get_node_or_null("CanvasLayer/Control/DashBar")
		dash_label = scene_root.get_node_or_null("CanvasLayer/Control/DashBar/Label")
	
	# Pengecekan
	if dash_bar == null:
		print("ERROR: DashBar MASIH TIDAK DITEMUKAN!")
	else:
		dash_bar.max_value = dash_cooldown
		dash_bar.value = dash_cooldown
		print("UI Dash Berhasil Terhubung!")

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
var dash_direction := Vector3.ZERO
var dash_time_left := 0.0 # <--- Tambahkan baris ini kembali

# Sistem Charge
var max_dash_charges := 2
var dash_charges := 2
var dash_cooldown := 3.0 # Cooldown setelah kedua charge habis
var dash_cooldown_left := 0.0

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
		
	# Input baru untuk Weapon Skill (pastikan sudah di-map di Project Settings)
	if Input.is_action_just_pressed("weapon_skill"):
		_use_weapon_skill()

# == WEAPON SKILL & SANITY ==
func _use_weapon_skill() -> void:
	# Tidak bisa cast jika sedang cooldown attack, sedang hollow, atau nge-dash
	if not attack_timer.is_stopped() or is_hollow or is_dashing:
		return
		
	if sanity >= weapon_skill_cost:
		is_attacking = true
		attack_timer.start()
		
		# Kurangi Sanity
		sanity -= weapon_skill_cost
		print("Weapon Skill Digunakan! Sanity tersisa: ", sanity)
		
		if sanity <= 0:
			sanity = 0
			_become_hollow()
			
		# Logika Weapon Skill (Burst Damage / AoE besar)
		var bodies := attack_area.get_overlapping_bodies()
		for body in bodies:
			if body and body.has_method("hit") and body.is_in_group("enemy"):
				body.hit(atk * 3) # Contoh: Memberikan 3x lipat damage biasa
				
		as_vfx.play("weapon_skill_effect") # Ganti dengan nama animasi VFX skill-mu
		
		await get_tree().create_timer(attack_timer.wait_time).timeout
		is_attacking = false
	else:
		print("Sanity tidak cukup!")

func _become_hollow() -> void:
	is_hollow = true
	anim_sprite.set("modulate", Color(0.5, 0.5, 0.5, 0.7)) # Efek visual transparan/abu-abu
	print("Kewarasan Habis! Pemain menjadi jiwa kosong.")
	# Hukuman hollow: Misalnya speed turun drastis
	speed = 3.0 
	sprint_speed = 3.0

func restore_sanity(amount: int) -> void:
	sanity += amount
	if sanity > max_sanity:
		sanity = max_sanity
		
	if is_hollow and sanity > 0:
		is_hollow = false
		anim_sprite.set("modulate", Color.WHITE) # Normal kembali
		speed = 7.0 # Kembalikan speed normal
		sprint_speed = speed * 1.5
		print("Kewarasan kembali.")

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
	# 1. Update UI & Cooldown
	if dash_charges == 0:
		dash_cooldown_left -= delta
		
		# Menggerakkan bar secara real-time
		if dash_bar:
			dash_bar.value = dash_cooldown - dash_cooldown_left
			
		if dash_cooldown_left <= 0.0:
			dash_charges = max_dash_charges
			if dash_bar:
				dash_bar.value = dash_cooldown
			print("Dash charges dipulihkan!")
	else:
		if dash_bar:
			dash_bar.value = dash_cooldown

	# 2. Update Teks Label secara real-time
	if dash_label:
		dash_label.text = str(dash_charges) + "/2"

	# 3. Start Dash Action
	if not is_dashing and dash_charges > 0 \
	and Input.is_action_just_pressed("dash") and input_dir.length() > 0.1:
		
		is_dashing = true
		dash_time_left = dash_duration
		dash_charges -= 1
		
		if dash_charges == 0:
			dash_cooldown_left = dash_cooldown
			if dash_bar:
				dash_bar.value = 0.0 # Kosongkan bar seketika
				
		dash_direction = Basis(Vector3.UP, rotation.y) * Vector3(input_dir.x, 0, input_dir.y)
		dash_direction = dash_direction.normalized()
		AudioManager.play_sfx("dash")

	# 4. Handle Dash Motion
	if is_dashing:
		dash_time_left -= delta
		move_dir = (Basis(Vector3.UP, rotation.y) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if (dash_duration - dash_time_left) >= dash_duration / 3.0 and move_dir.length() > 0.1:
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
