class_name PackedEnemy
extends Resource


# weight over game progress (X: 0-1, Y: spawn weight)
@export var weight_curve: Curve
@export var scene: PackedScene
# Discrete rotation angles (degrees) this enemy can spawn at.
@export var rotation_angles: Array[float] = [0.0]
# Weight curve per rotation angle, parallel to rotation_angles (same length required).
# Curve X: game progress (0-1), Y: weight for that rotation at that time
@export var rotation_weight_curves: Array[Curve]