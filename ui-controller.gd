extends CanvasLayer

@export var camera: Camera2D


func _on_h_slider_value_changed(value: float) -> void:
	var zoom_value = $MarginContainer/HSlider.value
	camera.zoom = Vector2(zoom_value,zoom_value)
	
