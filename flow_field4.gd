extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var field_size: Vector2i = Vector2i(64, 64)  # fixed size
@onready var bounds := Rect2i(Vector2i.ZERO, field_size)  # fixed 

@export var tile_map: TileMapLayer
@export var walls_map: TileMapLayer

var update_tilemap = true

const TILE_SIZE: int = 16
const MAX_COST = 999999

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

# For followers
func field_direction(pos: Vector2) -> Vector2:
	var index: int = get_field_index(Vector2i(pos / TILE_SIZE))
	if index < 0 or index >= flow_field.size():
		return Vector2.ZERO
	return flow_field[index]
	
func is_blocked(cell: Vector2i) -> bool:
	var tile_data: TileData = walls_map.get_cell_tile_data(cell)
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		return true
	return false

func get_travel_cost(cell: Vector2i) -> int:
	# Return custom travel cost, or default to 1.
	var tile_data: TileData = walls_map.get_cell_tile_data(cell)
	if tile_data:
		return int(tile_data.get_custom_data("travel_cost"))
	return 1

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

	costs.fill(MAX_COST)
	flow_field.fill(Vector2.ZERO)

	var target_index = get_field_index(target_tile)
	costs[target_index] = 0
	cost_queue.clear()
	cost_queue.append(target_tile)

	# BFS
	while not cost_queue.is_empty():
		var current_cell: Vector2i = cost_queue.pop_front()
		var index = get_field_index(current_cell)

		for neighbor_cell in get_neighbors(current_cell):
			if neighbor_cell.x < bounds.position.x or neighbor_cell.x >= bounds.end.x:
				continue
			if neighbor_cell.y < bounds.position.y or neighbor_cell.y >= bounds.end.y:
				continue

			var neighbor_index = get_field_index(neighbor_cell)

			# Already visited
			if costs[neighbor_index] != MAX_COST:
				continue

			# Wall detection
			if is_blocked(neighbor_cell):
				costs[neighbor_index] = MAX_COST
				continue

			# Base travel cost
			var base_cost: int = costs[index] + get_travel_cost(neighbor_cell)

			# Diagonal Penalty
			# Smoother than checking if x and y changed
			var angle = Vector2(target_tile).angle_to_point(Vector2(neighbor_cell)) 
			if abs(angle - snappedf(angle, PI / 2)) > PI / 12: base_cost += 1

			# Assign and enqueue
			costs[neighbor_index] = base_cost
			cost_queue.append(neighbor_cell)

	# --- Flow field direction assignment ---
	for i in flow_field.size():
		if costs[i] == MAX_COST:
			flow_field[i] = Vector2.ZERO
			continue

		var cell: Vector2i = index_to_cell(i)
		if cell == target_tile:
			continue

		var cheapest: int = MAX_COST
		var cheapest_neighbor: Vector2i = cell

		for neighbor_cell in get_neighbors(cell):
			if neighbor_cell.x < bounds.position.x or neighbor_cell.x >= bounds.end.x:
				continue
			if neighbor_cell.y < bounds.position.y or neighbor_cell.y >= bounds.end.y:
				continue

			var neighbor_index = get_field_index(neighbor_cell)
			if costs[neighbor_index] < cheapest:
				cheapest = costs[neighbor_index]
				cheapest_neighbor = neighbor_cell
				if cheapest == 0: # can't do better than target
					break

		flow_field[i] = Vector2(cheapest_neighbor - cell)

		if update_tilemap:
			var tile_idx = Vector2i(DIRECTIONS.find(flow_field[i]), 0)
			tile_map.set_cell(cell, 0, tile_idx)
