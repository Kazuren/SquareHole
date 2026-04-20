extends ShapeEntity


@export var BASE_METERS_PER_SECOND: float = 2
@export var WEIGHT: int = 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	self.global_translate(Vector3(0, -BASE_METERS_PER_SECOND * delta, 0))

