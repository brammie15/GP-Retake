extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()
var crowd_costs: PackedInt32Array = PackedInt32Array()

@export var crowdDesnity: Control

@export var field_size: Vector2i = Vector2i(64, 64)  # fixed size
@export var grid_origin: Vector2i = Vector2i.ZERO    # top-left in tile coords
@onready var bounds := Rect2i(grid_origin, field_size)  # fixed position

@export var tile_map: TileMapLayer
@export var walls_map: TileMapLayer

const TILE_SIZE: int = 16
const MAX_COST = 99999

@export var target: Node2D
@export var agents: Array[Node2D] = []

var crowd_image: Image
var crowd_texture: ImageTexture

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
	crowd_image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RF) # one float channel
	crowd_texture = ImageTexture.create_from_image(crowd_image)
	generate_flow_field()

	var overlay_node = Sprite2D.new()
	overlay_node.texture = crowd_texture
	overlay_node.position = Vector2(grid_origin.x * TILE_SIZE * 5, grid_origin.y * TILE_SIZE * 2)	
	overlay_node.scale = Vector2(
		bounds.size.x * TILE_SIZE / float(crowd_texture.get_width()),
		bounds.size.y * TILE_SIZE / float(crowd_texture.get_height())
	)
	walls_map.add_child(overlay_node)  # add to the same parent as your tilemap

func update_crowd_texture():
	if crowd_image == null:
		return
	
	var max_density = 1
	for count in crowd_costs:
		if count > max_density:
			max_density = count
	
	for i in crowd_costs.size():
		var density = float(crowd_costs[i]) / float(max_density)
		var cell = index_to_cell(i) - bounds.position
		if cell.x >= 0 and cell.y >= 0 and cell.x < bounds.size.x and cell.y < bounds.size.y:
			crowd_image.set_pixel(cell.x, cell.y, Color(density, 0, 0))
	
	crowd_texture.update(crowd_image)

func _process(delta: float) -> void:
	print("fps: " + str(Engine.get_frames_per_second()))
	#if crowd_texture and $"../CanvasLayer/TextureRect2".material:
		#var mat = $"../CanvasLayer/TextureRect2".material
		#mat.set_shader_parameter("density_tex", crowd_texture)
		#mat.set_shader_parameter("tex_size", bounds.size)

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
	var index: int = get_field_index(Vector2i(pos / TILE_SIZE))
	if index < 0 or index >= flow_field.size():
		return Vector2.ZERO
	return flow_field[index].normalized()

func init_field() -> void:
	for x in field_size.x:
		for y in field_size.y:
			costs.append(MAX_COST)
			flow_field.append(Vector2.ZERO)
			crowd_costs.append(0)

func update_crowd_costs() -> void:
	# Reset
	for i in crowd_costs.size():
		crowd_costs[i] = 0
	
	# Count agents in each cell
	for agent in get_tree().get_nodes_in_group("agents"):
		if not agent is Node2D:
			continue
		var cell = Vector2i(agent.global_position / TILE_SIZE)
		var idx = get_field_index(cell)
		if idx >= 0 and idx < crowd_costs.size():
			crowd_costs[idx] += 1
	
	# Optional: spread influence to neighbors
	var temp_costs = crowd_costs.duplicate()
	for i in crowd_costs.size():
		if crowd_costs[i] > 0:
			var cell = index_to_cell(i)
			for n in get_neighbors(cell):
				var ni = get_field_index(n)
				if ni >= 0 and ni < crowd_costs.size():
					temp_costs[ni] += int(crowd_costs[i] * 0.5)
	crowd_costs = temp_costs

func generate_flow_field(force: bool = false) -> void:
	var next_target_tile = Vector2i((target.global_position / TILE_SIZE).floor())

	if target_tile == next_target_tile and not force:
		return
	target_tile = next_target_tile

	# Reset fields
	for i in costs.size():
		costs[i] = MAX_COST
		flow_field[i] = Vector2.ZERO

	# Update crowd data before BFS
	update_crowd_costs()
	update_crowd_texture()

	# No longer moving bounds — fixed grid

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

			var travel_cost: int = 1

			# Wall detection
			if tile_data:
				travel_cost = int(tile_data.get_custom_data("travel_cost"))
				if tile_data.get_collision_polygons_count(0) > 0:
					costs[neighbor_index] = MAX_COST
					seen[neighbor_cell] = true
					continue

			# Base cost from parent
			var base_cost = costs[index] + travel_cost

			# Add crowd penalty
			base_cost += crowd_costs[neighbor_index] * 2

			# Diagonal penalty
			var angle = Vector2(target_tile).angle_to_point(Vector2(neighbor_cell))
			if abs(angle - snappedf(angle, PI / 2)) > PI / 12:
				base_cost += 1

			costs[neighbor_index] = base_cost
			cost_queue.append(neighbor_cell)
			seen[neighbor_cell] = true

	# Flow field direction assignment
	for i in flow_field.size():
		if costs[i] == MAX_COST:
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
		var tile_idx = Vector2i(DIRECTIONS.find(flow_field[i]), 0)
		tile_map.set_cell(cell, 0, tile_idx)
