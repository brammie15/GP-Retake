extends CanvasLayer

@export var camera: Camera2D


func _on_h_slider_value_changed(value: float) -> void:
	var zoom_value = $MarginContainer/HSlider.value
	camera.zoom = Vector2(zoom_value,zoom_value)
	


func _on_check_button_toggled(toggled_on: bool) -> void:
	$"../FlowField".update_tilemap = toggled_on
	$"../TileMapLayer".visible = toggled_on


func _on_check_button_2_toggled(toggled_on: bool) -> void:
	for spawner in get_tree().get_nodes_in_group("spawner"):
		spawner.do_spawning = toggled_on
