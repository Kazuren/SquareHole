extends ShapeEntity


signal shape_changed(idx: int)


@export var PLAYER_WALK_SPEED_PER_SECOND: float = 1.0
@export var PLAYER_RUN_SPEED_PER_SECOND: float = 5.0
@export var shapes: Array[PackedShape]

var is_moving: bool = false
var current_shape_index: int = 0

@onready var visual: CSGPolygon3D = $Visual


func _ready() -> void:
	if shapes.size() > 0:
		apply_shape(0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("switch_left"):
		switch_shape(-1)
	elif Input.is_action_just_pressed("switch_right"):
		switch_shape(1)

	if Input.is_action_just_pressed("rotate"):
		rotate_shape()

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_down", "move_up")

	if input_vector.is_zero_approx():
		is_moving = false
		return

	is_moving = true

	var running: bool = Input.is_action_pressed("run")

	var camera = get_viewport().get_camera_3d()
	var forward: Vector3 = camera.global_transform.basis.z;
	var right: Vector3 = camera.global_transform.basis.x;

	forward.y = 0;
	right.y = 0;

	var movement_vector: Vector3 = (forward.normalized() * -input_vector.y + right.normalized() * input_vector.x)
	self.global_position += movement_vector * delta * (PLAYER_RUN_SPEED_PER_SECOND if running else PLAYER_WALK_SPEED_PER_SECOND)


func switch_shape(direction: int) -> void:
	if shapes.is_empty():
		return
	var n := shapes.size()
	apply_shape(posmod(current_shape_index + direction, n))


func rotate_shape() -> void:
	shape_rotation_degrees = fposmod(shape_rotation_degrees + GameStats.rotation_step, 360.0)


func apply_shape(idx: int) -> void:
	current_shape_index = idx
	shape_rotation_degrees = 0.0 # reset rotation when switching shapes
	var shape := shapes[idx]
	(collisionShape2D.shape as ConvexPolygonShape2D).points = shape.points
	# Collision points are in 100-unit space, scale down to world scale
	var visual_points := PackedVector2Array()
	for p in shape.points:
		visual_points.append(p)
		#visual_points.append(p / float(baseline_scale))
	visual.polygon = visual_points
	shape_changed.emit(idx)
