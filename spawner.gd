extends Node2D

@export var follower_scene: PackedScene
@export var flow_field_controller: NodePath
@export var spawn_rate := 1.0          # seconds between spawns
@export var spawn_count := 2           # how many to spawn at once
@export var spawn_positions: Array[Vector2] = []  # optional fixed spawn points

@export var total_spawns = 100

var current_spawn_count = 0

var spawn_timer := 0.0

func _ready():
	if flow_field_controller:
		assert(get_node(flow_field_controller) != null, "Flow controller not found!")

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_rate:
		spawn_timer = 0.0
		for i in range(spawn_count):
			spawn_follower()

func spawn_follower():
	if not follower_scene:
		push_warning("No follower_scene assigned!")
		return
	
	current_spawn_count =+ 1
		
	if current_spawn_count > total_spawns:
		print("Reached max spawn limit")
		return

	# Pick spawn position
	var pos: Vector2
	if spawn_positions.size() > 0:
		pos = spawn_positions[randi() % spawn_positions.size()]
	else:
		pos = global_position  # spawn at the spawner node position
	pos += Vector2(randf_range(-8, 8), randf_range(-8, 8))
	# Instance the follower
	var follower = follower_scene.instantiate()
	follower.global_position = pos

	# Link it to flow field controller
	if flow_field_controller:
		var controller = get_node(flow_field_controller)
		follower.set_flow_controller(controller)
	
	
	# Add to scene
	get_tree().current_scene.add_child(follower)
