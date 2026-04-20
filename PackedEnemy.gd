class_name PackedEnemy
extends Resource


# weight over game progress (X: 0-1, Y: spawn weight)
@export var weight_curve: Curve
@export var scene: PackedScene
# weight curve per rotation bucket: index i → rotation of i * rotation_step degrees
# Curve X: game progress (0-1), Y: weight for that rotation at that time
@export var rotation_weight_curves: Array[Curve]