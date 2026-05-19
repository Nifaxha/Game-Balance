extends AnimatedSprite3D

# == VAR ==
enum State {IDLE,UP,DOWN,RIGHT,LEFT,DASH,ATTACK_LEFT,HURT}
var curAnim := State.IDLE

func _physics_process(_delta: float) -> void:
	match curAnim:
		State.IDLE:
			play("idle")
		State.UP:
			set("flip_h",false)
			play("left_run")
		State.DOWN:
			set("flip_h",true)
			play("left_run")
		State.LEFT:
			set("flip_h",false)
			play("left_run") 
		State.RIGHT:
			set("flip_h",true)
			play("left_run")
		State.DASH:
			play("dash")
		State.ATTACK_LEFT:
			_play_once("left_attack")
		State.HURT:
			_play_once("hurt")
			
func _play_once(anim_name: String):
	if animation != anim_name:
		play(anim_name)
