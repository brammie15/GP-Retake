extends Sprite2D

@export var speed: int = 300

func _process(delta: float) -> void:
	var dir_x = Input.get_axis("move_left", "move_right")
	var dir_y = Input.get_axis("move_up", "move_down")
	var direction = Vector2(dir_x, dir_y)
	
	self.position += direction * speed * delta
	
