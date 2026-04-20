class_name ShapeCarousel
extends Control


@export var player_path: NodePath
@export var slot_spacing: float = 120.0
@export var current_scale: float = 1.0
@export var side_scale: float = 0.6
@export var current_color: Color = Color(1, 1, 1, 1)
@export var side_color: Color = Color(1, 1, 1, 0.4)
@export var shape_size: float = 80.0

var _prev_slot: Polygon2D
var _current_slot: Polygon2D
var _next_slot: Polygon2D
var _player: Node


func _ready() -> void:
	_player = get_node(player_path)

	_prev_slot = _make_slot(-slot_spacing, side_scale, side_color)
	_current_slot = _make_slot(0, current_scale, current_color)
	_next_slot = _make_slot(slot_spacing, side_scale, side_color)

	resized.connect(_layout_slots)
	_layout_slots()

	_player.shape_changed.connect(_on_shape_changed)
	_on_shape_changed(_player.current_shape_index)


func _make_slot(x_offset: float, slot_scale: float, color: Color) -> Polygon2D:
	var slot := Polygon2D.new()
	add_child(slot)
	slot.set_meta("x_offset", x_offset)
	slot.scale = Vector2(slot_scale, slot_scale)
	slot.color = color
	return slot


func _layout_slots() -> void:
	# Position slots relative to the Control's center
	var center := size * 0.5
	for slot in [_prev_slot, _current_slot, _next_slot]:
		slot.position = center + Vector2(slot.get_meta("x_offset"), 0)


func _on_shape_changed(idx: int) -> void:
	var shapes: Array = _player.shapes
	if shapes.is_empty():
		return
	var n := shapes.size()
	_set_slot_shape(_prev_slot, shapes[posmod(idx - 1, n)])
	_set_slot_shape(_current_slot, shapes[idx])
	_set_slot_shape(_next_slot, shapes[posmod(idx + 1, n)])


func _set_slot_shape(slot: Polygon2D, shape: PackedShape) -> void:
	var pts := PackedVector2Array()
	var k := shape_size
	for p in shape.points:
		pts.append(p * k)
	slot.polygon = pts
