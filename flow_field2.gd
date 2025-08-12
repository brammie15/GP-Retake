extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var field_size: Vector2 = Vector2(64, 48)
@onready var bounds = Rect2i(Vector2i.ZERO - Vector2i(field_size) / 2, field_size)

@export var tile_map: TileMapLayer
@export var walls_map: TileMapLayer

const TILE_SIZE: int = 16
const MAX_COST = 99999

@export var target: Node2D

var update_time = 0
@export var update_time_interval = 2

var target_tile = Vector2i.ZERO
var cost_queue: Array[Vector2i] = []

const DIRECTIONS = [
	Vector2.UP,           # 0
	Vector2.DOWN,         # 1
	Vector2.LEFT,         # 2
	Vector2.RIGHT,        # 3
	Vector2(-1, -1),      # 4 Top-left diagonal
	Vector2(1, -1),       # 5 Top-right diagonal
	Vector2(1, 1),        # 6 Bottom-right diagonal
	Vector2(-1, 1),       # 7 Bottom-left diagonal
]

func _ready() -> void:
	init_field()
	generate_flow_field()
	
func _process(delta: float) -> void:
	print("fps: " + str(Engine.get_frames_per_second()))

func _physics_process(delta: float) -> void:
	generate_flow_field()
	update_time += delta
	if update_time > update_time_interval:
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
	var index: int = get_field_index(Vector2i(pos/ TILE_SIZE))
	if index < 0 or index >= flow_field.size():
		return Vector2.ZERO
	return flow_field[index].normalized()

func init_field() -> void:
	for x in field_size.x:
		for y in field_size.y:
			costs.append(MAX_COST)
			flow_field.append(Vector2.ZERO)
			
func generate_flow_field(force: bool = false) -> void:
	var next_target_tile = Vector2i((target.global_position / TILE_SIZE).floor())
	
	# player didn't move :p
	if target_tile == next_target_tile: 
		return
	target_tile = next_target_tile
	
	for i in costs.size():
		costs[i] = MAX_COST
		flow_field[i] = Vector2.ZERO

	# Get target tile in grid coords
	bounds.position = target_tile - Vector2i(field_size) / 2

	# Set target cost to 0
	costs[get_field_index(target_tile)] = 0
	cost_queue.clear()
	cost_queue.append(target_tile)

	var seen: Dictionary = {}
	seen[target_tile] = true

	# BFS cost field generation
	while not cost_queue.is_empty():
		var current_cell = cost_queue.pop_front()
		var index = get_field_index(current_cell)

		for neighbor_cell in get_neighbors(current_cell):
			var cell_rect = Rect2i(neighbor_cell.x, neighbor_cell.y, 1, 1)

			if seen.has(neighbor_cell) or not bounds.encloses(cell_rect):
				continue

			var neighbor_index = get_field_index(neighbor_cell)
			var tile_data: TileData = walls_map.get_cell_tile_data(neighbor_cell)

			var travel_cost: int = 1  # Default

			# Wall detection
			if tile_data:
				travel_cost = int(tile_data.get_custom_data("travel_cost"))
				if tile_data.get_collision_polygons_count(0) > 0:
					costs[neighbor_index] = MAX_COST
					seen[neighbor_cell] = true
					continue

			# Assign cost and enqueue
			costs[neighbor_index] = costs[index] + travel_cost

			# Diagonal penalty
			var angle = Vector2(target_tile).angle_to_point(Vector2(neighbor_cell))
			if abs(angle - snappedf(angle, PI / 2)) > PI / 12:
				costs[neighbor_index] += 1

			cost_queue.append(neighbor_cell)
			seen[neighbor_cell] = true

	# Flow field direction assignment
	for i in flow_field.size():
		if costs[i] == MAX_COST:
			# Wall or unreachable
			flow_field[i] = Vector2.ZERO
			continue

		var cell: Vector2i = index_to_cell(i)
		if cell == target_tile:
			continue

		var cheapest = MAX_COST
		var cheapest_neighbor = cell

		for neighbor_cell in get_neighbors(cell):
			var neighbor_index = get_field_index(neighbor_cell)

			var cell_rect = Rect2i(neighbor_cell.x, neighbor_cell.y, 1, 1)
			if not bounds.encloses(cell_rect):
				continue

			if costs[neighbor_index] < cheapest:
				cheapest = costs[neighbor_index]
				cheapest_neighbor = neighbor_cell

		flow_field[i] = Vector2(cheapest_neighbor - cell)

		# Set tile map direction arrow
		var tile_idx = Vector2i(DIRECTIONS.find(flow_field[i]), 0)
		tile_map.set_cell(cell, 0, tile_idx)
