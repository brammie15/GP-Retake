extends Node2D

@export var strength: float = 5.0  # how strongly this pushes things away
@export var range: float = 64.0    # max distance this repeller affects

func _ready() -> void:
	add_to_group("repellers")

func _draw() -> void:
	draw_circle(Vector2.ZERO, range, Color(1, 0, 0, 0.3))
