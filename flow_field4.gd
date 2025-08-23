extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var vis_map: TileMapLayer
@export var walls_map: TileMapLayer
@export var size: Vector2i = Vector2i(64, 64)  # fixed size
@export var target: Node2D
@export var update_time_interval = 2

@onready var bounds := Rect2i(Vector2i.ZERO, size)  # fixed 

@export var bfs_strength = 1
@export var attractor_strength = 1
@export var repeller_strength = 1


var update_tilemap = true

const TILE_SIZE: int = 16
const MAX_COST = 999999


var update_time = 0

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

func find_closest(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	var closest = DIRECTIONS[0]
	var best_dot = v.normalized().dot(closest.normalized())
	for d in DIRECTIONS:
		var dot = v.normalized().dot(d.normalized())
		if dot > best_dot:
			best_dot = dot
			closest = d
	return closest

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
		
func get_repellers() -> Array:
	var repellers: Array = []
	for repeller in get_tree().get_nodes_in_group("repellers"):
		repellers.append(repeller)
	return repellers

func get_attractors() -> Array:
	var attractors: Array = []
	for attractor in get_tree().get_nodes_in_group("attractors"):
		attractors.append(attractor)
	return attractors

# For followers
func field_direction(pos: Vector2) -> Vector2:
	var index: int = GridUtils.get_cell_index(Vector2i(pos / TILE_SIZE), bounds)
	if index < 0 or index >= flow_field.size():
		return Vector2.ZERO
	return flow_field[index]
	
func is_blocked(cell: Vector2i) -> bool:
	var tile_data: TileData = walls_map.get_cell_tile_data(cell)
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		return true
	return false

func get_travel_cost(cell: Vector2i) -> int:
	# return custom travel cost or default 1
	var tile_data: TileData = walls_map.get_cell_tile_data(cell)
	if tile_data:
		return int(tile_data.get_custom_data("travel_cost"))
	return 1

func init_field() -> void:
	var total_cells: int = size.x * size.y
	costs.resize(total_cells)
	costs.fill(MAX_COST)

	flow_field.resize(total_cells)
	flow_field.fill(Vector2.ZERO)

func generate_flow_field(force: bool = false) -> void:
	var next_target = Vector2i((target.global_position / TILE_SIZE).floor())

	if target_tile == next_target and not force:
		return

	target_tile = next_target

	costs.fill(MAX_COST)
	flow_field.fill(Vector2.ZERO)

	var target_index = GridUtils.get_cell_index(target_tile, bounds)
	costs[target_index] = 0
	cost_queue.clear()
	cost_queue.append(target_tile)

	# BFS
	while not cost_queue.is_empty():
		var current_cell: Vector2i = cost_queue.pop_front()
		var index = GridUtils.get_cell_index(current_cell, bounds)

		for neighbor_cell in GridUtils.get_neighbors(current_cell):
			if neighbor_cell.x < bounds.position.x or neighbor_cell.x >= bounds.end.x:
				continue
			if neighbor_cell.y < bounds.position.y or neighbor_cell.y >= bounds.end.y:
				continue

			var neighbor_index = GridUtils.get_cell_index(neighbor_cell, bounds)

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
			
	var repellers = get_repellers()
	var attractors = get_attractors()
	
			
	for i in flow_field.size():
		var cell: Vector2i = GridUtils.index_to_cell(i, bounds)

		# Skip walls themselves
		if costs[i] == MAX_COST:
			continue

	# Now for the directions based on costs
	for i in flow_field.size():
		if costs[i] == MAX_COST:
			flow_field[i] = Vector2.ZERO
			continue

		var cell: Vector2i = GridUtils.index_to_cell(i, bounds)
		if cell == target_tile:
			continue

		var cheapest: int = MAX_COST
		var cheapest_neighbor: Vector2i = cell

		for neighbor_cell in GridUtils.get_neighbors(cell):
			if neighbor_cell.x < bounds.position.x or neighbor_cell.x >= bounds.end.x:
				continue
			if neighbor_cell.y < bounds.position.y or neighbor_cell.y >= bounds.end.y:
				continue

			var neighbor_index =  GridUtils.get_cell_index(neighbor_cell, bounds)
			if costs[neighbor_index] < cheapest:
				cheapest = costs[neighbor_index]
				cheapest_neighbor = neighbor_cell
				if cheapest == 0: # can't do better than target
					break
					
		var dir = Vector2(cheapest_neighbor - cell)
		
		var repeller_force = Vector2.ZERO
		for repeller in repellers:
			var repeller_cell: Vector2i = GridUtils.world_to_cell(repeller.global_position, TILE_SIZE)
			if not bounds.has_point(repeller_cell):
				continue

			var diff = Vector2(cell - repeller_cell)
			var dist = max(diff.length(), 0.001)

			# Strength decays with distance
			var push = diff.normalized() * (repeller.strength / dist)
			repeller_force += push
		
		var attractor_force = Vector2.ZERO
		for attractor in attractors:
			var attractor_cell: Vector2i = GridUtils.world_to_cell(attractor.global_position, TILE_SIZE)
			if not bounds.has_point(attractor_cell):
				continue

			var diff = Vector2(attractor_cell - cell)  # point toward attractor
			var dist = max(diff.length(), 0.001)

			if dist <= attractor.range:
				var pull = diff.normalized() * (attractor.strength / dist)
				attractor_force += pull

		#flow_field[i] = dir.normalized()
		flow_field[i] = ((dir * bfs_strength) + (attractor_force * attractor_strength) + (repeller_force * repeller_strength)).normalized()

		if update_tilemap:
			var snapped_dir = find_closest(flow_field[i])
			var tile_idx = Vector2i(DIRECTIONS.find(snapped_dir), 0)
			vis_map.set_cell(cell, 0, tile_idx)
