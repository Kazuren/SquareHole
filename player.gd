extends ShapeEntity


@export var PLAYER_WALK_SPEED_PER_SECOND: float = 1.0
@export var PLAYER_RUN_SPEED_PER_SECOND: float = 5.0

var is_moving: bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
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


