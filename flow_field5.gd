extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var field_size: Vector2i = Vector2i(64, 64)  # fixed size
@export var grid_origin: Vector2i = Vector2i.ZERO    # top-left in tile coords
@onready var bounds := Rect2i(grid_origin, field_size)  # fixed position

@export var tile_map: TileMapLayer
@export var walls_map: TileMapLayer

var update_tilemap = true

const TILE_SIZE: int = 16
const MAX_COST = 99999

@export var target: Node2D

var update_time = 0
@export var update_time_interval = 2

var target_tile = Vector2i.ZERO
var cost_queue: Array[Vector2i] = []

const DIRECTIONS = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2(-1, -1),
	Vector2(1, -1),
	Vector2(1, 1),
	Vector2(-1, 1),
]

func _ready() -> void:
	init_field()
	generate_flow_field()

func _process(_delta: float) -> void:
	print("fps: " + str(Engine.get_frames_per_second()))

func _physics_process(delta: float) -> void:
	update_time += delta
	if update_time > update_time_interval:
		generate_flow_field()
		update_time = 0

func get_field_index(cell: Vector2i) -> int:
	var offset = cell - bounds.position
	var index = offset.y * bounds.size.x + offset.x
	return clampi(index, 0, flow_field.size() - 1)

func index_to_cell(index: int) -> Vector2i:
	var x = index % bounds.size.x
	var y = index / bounds.size.x
	return Vector2i(x, y) + bounds.position

func add_cost_to_cell(pos: Vector2i) -> void:
	var index = get_field_index(Vector2i(pos / TILE_SIZE))
	costs[index] += 1

func get_neighbors(current_cell) -> Array[Vector2i]:
	return [
		current_cell + Vector2i.UP,
		current_cell + Vector2i.RIGHT,
		current_cell + Vector2i.DOWN,
		current_cell + Vector2i.LEFT,
		current_cell + Vector2i(-1, -1),
		current_cell + Vector2i(1, -1),
		current_cell + Vector2i(1, 1),
		current_cell + Vector2i(-1, 1),
	]

func field_direction(pos: Vector2) -> Vector2:
	var index: int = get_field_index(Vector2i(pos / TILE_SIZE))
	if index < 0 or index >= flow_field.size():
		return Vector2.ZERO
	return flow_field[index]

func init_field() -> void:
	var total_cells = field_size.x * field_size.y
	costs.resize(total_cells)
	flow_field.resize(total_cells)
	for i in total_cells:
		costs[i] = MAX_COST
		flow_field[i] = Vector2.ZERO

func generate_flow_field(force: bool = false) -> void:
	var next_target_tile = Vector2i((target.global_position / TILE_SIZE).floor())
	
	if target_tile == next_target_tile and not force:
		return
	
	target_tile = next_target_tile

	# Reset fields
	for i in costs.size():
		costs[i] = MAX_COST
		flow_field[i] = Vector2.ZERO

	# Set target cost to 0
	costs[get_field_index(target_tile)] = 0
	cost_queue.clear()
	# Instead of simple append, we'll store tuples (cell, f_score)
	cost_queue.append({'cell': target_tile, 'f': 0})

	var seen: Dictionary = {}
	seen[target_tile] = true

	# A* search from target outward
	while not cost_queue.is_empty():
		# Pop the element with the lowest f value (cost + heuristic)
		cost_queue.sort_custom(_sort_by_f)  # Sort ascending by f
		var current_data = cost_queue.pop_front()
		var current_cell = current_data['cell']
		var index = get_field_index(current_cell)

		for neighbor_cell in get_neighbors(current_cell):
			var cell_rect = Rect2i(neighbor_cell.x, neighbor_cell.y, 1, 1)
			if seen.has(neighbor_cell) or not bounds.encloses(cell_rect):
				continue

			var neighbor_index = get_field_index(neighbor_cell)
			var tile_data: TileData = walls_map.get_cell_tile_data(neighbor_cell)

			var travel_cost: int = 1

			# Wall detection
			if tile_data:
				travel_cost = int(tile_data.get_custom_data("travel_cost"))
				if tile_data.get_collision_polygons_count(0) > 0:
					costs[neighbor_index] = MAX_COST
					seen[neighbor_cell] = true
					continue

			var base_cost = costs[index] + travel_cost

			# Diagonal penalty
			var angle = Vector2(target_tile).angle_to_point(Vector2(neighbor_cell))
			if abs(angle - snappedf(angle, PI / 2)) > PI / 12:
				base_cost += 1

			# Heuristic - distance from neighbor to some origin (or target_tile)
			# Because this is a flow field from target outward, heuristic can be 0 or a fixed point. Here, 0 heuristic (Dijkstra) or distance to target_tile.
			var heuristic = neighbor_cell.distance_to(target_tile)
			var f_score = base_cost + heuristic

			if base_cost < costs[neighbor_index]:
				costs[neighbor_index] = base_cost
				# Insert neighbor with priority f_score
				cost_queue.append({'cell': neighbor_cell, 'f': f_score})
				seen[neighbor_cell] = true

func _sort_by_f(a, b):
	return int(a['f'] - b['f'])
