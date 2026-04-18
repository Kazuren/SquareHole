extends Node3D


# game loop:

# Shapes: [1, 2, 3, 4, 5, 6, 7]
# Shape schema: weight
# bag[]
# bag.GetNext(). 2, 1, 1, 


# 1. choose next shape
# 2. shape falls down
# 3. move character to shape/shape shadow
# 4. when the shapes top point of it's bounding box passes through the ground
# we calculate the "score" gained based on how much it INTERSECTS the player shape
# intersect the player shape from the enemy shape and the resulting shapes area is the score



# formula:
# enemy_shape INTERSECT player_shape = intersection_shape
# score = intersection_shape_area / max(enemy_shape_area, player_shape_area)


@onready var player: ShapeEntity = $Player
@onready var enemy: ShapeEntity = $Enemy

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(player.intersect(enemy))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(player.intersect(enemy))
	pass
