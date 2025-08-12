extends RigidBody2D

@export var speed := 400.0             # Force magnitude
@export var arrive_threshold := 6.0    # How close to target before stopping
@export var rotation_speed := 8.0      # Rotation smoothing

@export var flow_controller: Node

func _ready():
	add_to_group("agents")

func set_flow_controller(controller: Node):
	flow_controller = controller

func _physics_process(delta: float) -> void:
	if not flow_controller:
		return

	# Check arrival
	if global_position.distance_to(flow_controller.target.global_position) <= arrive_threshold:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		queue_free()
		return

	var dir: Vector2 = flow_controller.field_direction(global_position)
	if dir == Vector2.ZERO:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		return

	dir = dir.normalized()

	# Apply impulse proportional to speed and delta time
	# Impulse = force * delta * mass
	# Here we use apply_central_impulse for a direct force at center of mass
	var impulse = dir * speed * delta * mass
	apply_central_impulse(impulse)

	# Optional: clamp max speed for stability
	var max_speed = speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	# Smooth rotation toward movement direction
	if linear_velocity.length_squared() > 0.01:
		var target_rot = linear_velocity.angle()
		rotation = lerp_angle(rotation, target_rot, rotation_speed * delta)
		$"Sprite2D".rotation = -rotation
