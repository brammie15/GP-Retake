extends Object
class_name GridUtils

static func get_cell_index(cell: Vector2i, bounds: Rect2i) -> int:
	var offset = cell - bounds.position
	return offset.y * bounds.size.x + offset.x

static func index_to_cell(index: int, bounds: Rect2i) -> Vector2i:
	var x = index % bounds.size.x
	var y = index / bounds.size.x
	return Vector2i(x, y) + bounds.position

static func get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.UP,
		cell + Vector2i.RIGHT,
		cell + Vector2i.DOWN,
		cell + Vector2i.LEFT,
		cell + Vector2i(-1, -1),
		cell + Vector2i(1, -1),
		cell + Vector2i(1, 1),
		cell + Vector2i(-1, 1),
	]

static func world_to_cell(world_pos: Vector2, tile_size: int) -> Vector2i:
	return Vector2(world_pos / tile_size).floor()
