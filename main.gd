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



# TODO ORDER:
# score tracking (global stats object)
# enemy spawning (bag data structure)
# player switching shape

@export var intersection_material: BaseMaterial3D
@export var xor_material: BaseMaterial3D


@onready var player: ShapeEntity = $Player
@onready var enemy: ShapeEntity = $Enemy


var enemies: Array[ShapeEntity] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemies.append(enemy)

	Engine.time_scale = 1
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	for e: ShapeEntity in enemies:
		var aabb: AABB = e.get_aabb() # e.mesh.get_aabb()

		var top_point: Vector3 = aabb.end + e.position
		if top_point.y < 0:
			e.queue_free()
			enemies.erase(e)

			var score: float = player.calculate_score_base(e)

			var intersection_shape: Variant = player.get_intersection_shape(e) # PackedVector2Array | NULL
			var xor_shape: Variant = player.get_xor_shape(e) # PackedVector2Array | NULL

			if intersection_shape != null:
				var intersection_polygon: CSGPolygon3D = CSGPolygon3D.new()
				add_child(intersection_polygon)

				intersection_polygon.depth = 0.02
				intersection_polygon.polygon = intersection_shape
				intersection_polygon.rotate_x(deg_to_rad(90))
				intersection_polygon.global_translate(Vector3(0, 0.01, 0))
				intersection_polygon.material = intersection_material
				intersection_polygon.sorting_offset = 10

				var intersection_tween = get_tree().create_tween()

				# from 0 alpha to 1 over 0.1 seconds
				intersection_tween.tween_property((intersection_polygon.material as BaseMaterial3D), "albedo_color:a", 1, 0.5).from(0) \
				.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_OUT)

				 # from 1 alpha to 0 over 1 seconds
				intersection_tween.tween_property((intersection_polygon.material as BaseMaterial3D), "albedo_color:a", 0, 1).from_current() \
				 	.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				intersection_tween.tween_callback(intersection_polygon.queue_free)


			if xor_shape != null:
				var xor_polygon: CSGPolygon3D = CSGPolygon3D.new()
				add_child(xor_polygon)

				xor_polygon.depth = 0.02
				xor_polygon.polygon = xor_shape
				xor_polygon.rotate_x(deg_to_rad(90))
				xor_polygon.global_translate(Vector3(0, 0.01, 0))
				xor_polygon.material = xor_material
				xor_polygon.sorting_offset = 10
				
				var xor_tween = get_tree().create_tween()

				# from 0 alpha to 1 over 0.1 seconds
				xor_tween.tween_property((xor_polygon.material as BaseMaterial3D), "albedo_color:a", 1, 0.5).from(0) \
				 	.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_OUT)

				# from 1 alpha to 0 over 1 seconds
				xor_tween.tween_property((xor_polygon.material as BaseMaterial3D), "albedo_color:a", 0, 1).from_current() \
					.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				xor_tween.tween_callback(xor_polygon.queue_free)

			print(score)
