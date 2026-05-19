extends AnimationTree

@export var chara: CharacterBody3D 
var new_state_name: String

func _physics_process(_delta: float) -> void:
	match chara.state:
		chara.State.PATROL:
			new_state_name = "Walk"
		chara.State.CHASE:
			new_state_name = "Run"
		chara.State.SEARCH:
			new_state_name = "Run"
		chara.State.IDLE:
			new_state_name = "Idle"
		chara.State.JUMPSCARE:
			new_state_name = "Jumpscare"
		_:
			new_state_name = "Idle"
			
	set("parameters/Movement/transition_request", new_state_name)
