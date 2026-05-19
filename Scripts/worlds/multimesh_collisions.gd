extends MultiMeshInstance3D
#Tree MultiMesh only need CylinderShape3D

func _ready():
	if not multimesh:
		return
		
	var shared_shape = CylinderShape3D.new()
	shared_shape.height = 6.0
	shared_shape.radius = 0.5 

	for index in multimesh.instance_count:
		var mesh_transform = multimesh.get_instance_transform(index)
		
		var static_body = StaticBody3D.new()
		var collision_node = CollisionShape3D.new()
		
		collision_node.shape = shared_shape
		
		static_body.transform = mesh_transform
		
		static_body.add_child(collision_node)
		add_child(static_body)
