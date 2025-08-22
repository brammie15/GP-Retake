extends Node2D
class_name Attractor

@export var strength: float = 1.0  # how strongly it pulls followers


func _ready() -> void:
	add_to_group("attractors")
