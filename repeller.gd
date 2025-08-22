extends Node2D

@export var strength: float = 5.0  # how strongly this pushes things away

func _ready() -> void:
	add_to_group("repellers")


func _draw() -> void:
	# Draw a circle representing the repeller's strength
	# The radius could be proportional to strength
	var radius = strength * 15  # scale as needed
	draw_circle(Vector2.ZERO, radius, Color(1, 0, 0, 0.5))  # semi-transparent red
