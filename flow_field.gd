extends Node

var flow_field: PackedVector2Array = PackedVector2Array()
var costs: PackedInt32Array = PackedInt32Array()

@export var field_size: Vector2 = Vector2(64, 48)
@onready var bounds = Rect2i(Vector2i.ZERO - Vector2i(field_size) / 2, field_size)

@export var tile_map: TileMapLayer

const TILE_SIZE: int = 16
const MAX_COST = 99999

@export var target: Node2D

var target_tile = Vector2i.ZERO
var cost_queue: Array[Vector2i] = []

const DIRECTIONS = [
	Vector2.UP, 
	Vector2.DOWN, 
	Vector2.LEFT, 
	Vector2.RIGHT
]

func _ready() -> void:
	init_field()
	
func _physics_process(delta: float) -> void:
	generate_flow_field()
	
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
	
	target_tile = next_target_tile
	bounds.position = target_tile - Vector2i(field_size) / 2
	costs[get_field_index(target_tile)] = 0 
	
	cost_queue = [target_tile]
	var seen: Dictionary = {}
	
	while not cost_queue.is_empty():
		var current_cell = cost_queue.pop_front()
		seen[current_cell] = true
		
		var index = get_field_index(current_cell)
		if costs[index] == MAX_COST:
			continue
		
		for neighbor_cell in get_neighbors(current_cell):
			var cell_rect = Rect2i(neighbor_cell.x, neighbor_cell.y, 1, 1)
			
			if seen.has(neighbor_cell) or not bounds.encloses(cell_rect):
				continue
			var neighbor_cell_index = get_field_index(neighbor_cell)
			costs[neighbor_cell_index] = costs[index] + 1
			
			cost_queue.append(neighbor_cell)
			seen[neighbor_cell] = true


	for i in flow_field.size():
		var cell = index_to_cell(i)
		if cell == target_tile:
			continue
		
		var cheapest = MAX_COST	
		var cheapest_neighbor = cell
		for neighbor_cell in get_neighbors(cell):
			var neighbor_index = get_field_index(neighbor_cell)
			
			var cell_rect = Rect2i(neighbor_cell.x, neighbor_cell.y, 1, 1)
			if not bounds.encloses(cell_rect):
				continue
			
			var cost = costs[neighbor_index]
			if cost < cheapest:
				cheapest = cost
				cheapest_neighbor = neighbor_cell
		flow_field[i] = Vector2(cheapest_neighbor - cell)
		tile_map.set_cell(cell, 0, Vector2i(DIRECTIONS.find(flow_field[i]), 0))
