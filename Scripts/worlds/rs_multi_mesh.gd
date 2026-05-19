extends Node3D

@export var count: int
@export var mesh: Mesh

var rid_array: Array[RID]

func _ready() -> void:
	var mesh_rid = mesh.get_rid()
	rid_array.resize(count)
	var scenario_rid = get_world_3d().scenario
	for n in count:
		var row: int = n / 100
		var col: int = n % 100
		var mesh_transform = Transform3D.IDENTITY.translated(Vector3(row * 1.5, 0.0, col * 1.5))
		var rid = RenderingServer.instance_create()
		RenderingServer.instance_set_base(rid, mesh_rid)
		RenderingServer.instance_set_scenario(rid, scenario_rid)
		RenderingServer.instance_set_transform(rid, mesh_transform)
		
		rid_array[n] = rid		

func _exit_tree() -> void:
	for n in count:
		RenderingServer.free_rid(rid_array[n])
