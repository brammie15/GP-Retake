# follower.gd
extends CharacterBody2D

@export var speed := 100.0            # Movement speed
@export var arrive_threshold := 6.0   # How close to target before stopping
@export var rotation_speed := 8.0     # How fast to rotate toward direction

@export var flow_controller: Node

func _ready():
	add_to_group("agents")

func set_flow_controller(controller: Node):
	flow_controller = controller

func _physics_process(delta: float) -> void:
	if not flow_controller:
		return

	# Stop if at target
	if global_position.distance_to(flow_controller.target.global_position) <= arrive_threshold:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_free()
		return

	# Get flow field direction
	var dir: Vector2 = flow_controller.field_direction(global_position)

	# Stop if no valid direction (e.g., wall or out of bounds)
	if dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Apply movement
	velocity = dir.normalized() * speed
	move_and_slide()

	# Smooth rotation toward movement direction
	if velocity.length_squared() > 0.01:
		var target_rot = velocity.angle()
		rotation = lerp_angle(rotation, target_rot, rotation_speed * delta)
		
	$"Sprite2D".rotation = -self.rotation
