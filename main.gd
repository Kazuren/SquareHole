extends Node3D


# formula:
# enemy_shape INTERSECT player_shape = intersection_shape
# score = intersection_shape_area / max(enemy_shape_area, player_shape_area)


# TODO ORDER:
# player switching shape

# "damage" text that shows percentage of fill, modulate from red/green depending on percentage filled


#THINGS TO FIX:
# fairness of game, way to spawn objects in a more fair way
# add gravity field concept to pull far away objects closer to player (we set a min distance away from player) for fairness
# shadows pop out very fast, use decals instead and fade in
# find better gradient for popup text percentage
# sanity meter. as game goes on, we could make it so a higher % match is required to not lose sanity
# survival timer for sharing score
# sounds: 100% match, 0% match, 100->50% lessen pitch, 49->0% lessen pitch
# more shapes
# implement shape scaling for difficulty tuning (we probably want enemy shapes to be 90% of their actual size to make it easier for the player to match it)

@export var intersection_material: BaseMaterial3D
@export var xor_material: BaseMaterial3D
@export var hit_label_scene: PackedScene


@onready var player: ShapeEntity = $Player
@onready var enemy: ShapeEntity = $Enemy

@export var enemy_scenes: Array[PackedEnemy]


var SCORE_MULTIPLIER: float = 15.0
var enemies: Array[ShapeEntity] = []
var enemy_bag: Bag

func render_score() -> void:
	$ScoreLabel.text = "Score: %.3f" % GameStats.score


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemies.append(enemy)
	render_score()

	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	enemy_bag = Bag.new(rng)
	for enemy_pack in enemy_scenes:
		enemy_bag.add(enemy_pack, enemy_pack.weight)

	print(enemy_bag.probabilities())

	Engine.time_scale = 1
	$SpawnTimer.timeout.connect(_on_timer_timeout)


func _on_timer_timeout() -> void:
	spawn_enemy()


func spawn_enemy() -> void:
	var draw = enemy_bag.draw()
	if draw is not PackedEnemy:
		push_error("USE PACKEDSCENE")
	
	var spawn_point: Vector2 = get_spawn_point()
	var enemy_packed: PackedEnemy = draw as PackedEnemy
	
	var node: ShapeEntity = enemy_packed.scene.instantiate()

	add_child(node)
	enemies.append(node)
	node.global_position = Vector3(spawn_point.x, 15, spawn_point.y)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	for e: ShapeEntity in enemies:
		var aabb: AABB = e.get_aabb() # e.mesh.get_aabb()

		var top_point: Vector3 = aabb.end + e.position
		if top_point.y < 0:
			# ENEMY CLEANUP
			e.queue_free()
			enemies.erase(e)

			# SCORE
			var score_base: float = player.calculate_score_base(e)
			GameStats.score += score_base * SCORE_MULTIPLIER
			render_score()

			# HIT LABEL
			var hit_label: Label3D = hit_label_scene.instantiate()
			add_child(hit_label)
			hit_label.global_position = player.global_position
			hit_label.text = ("%d%%" + ("!" if score_base >= 0.5 else "?!")) % (score_base * 100)
			hit_label.modulate = lerp(Color.TOMATO, Color.SPRING_GREEN, score_base)
			hit_label.rotate(Vector3.UP, PI * 0.25)
			hit_label.rotate(Vector3.FORWARD, randf_range(PI * -0.125, PI * 0.125))
			
			#hit_label.look_at($Pivot/Camera3D.global_position, Vector3.UP, true)
			#hit_label.rotation_degrees.x = 0aasas
			#hit_label.rotation_degrees.z = 0

			var label_tween = get_tree().create_tween()
			label_tween.parallel().tween_property(hit_label, "modulate:a", 0, 1.25).from_current().set_trans(Tween.TransitionType.TRANS_EXPO).set_ease(Tween.EaseType.EASE_IN)
			label_tween.parallel().tween_property(hit_label, "rotation_degrees:z", randf_range(-25, 25), 1).from_current().set_trans(Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)
			
			label_tween.parallel().tween_property(hit_label, "global_position:y", randf_range(1.2, 1.3), 0.75).as_relative().set_trans(Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)
			label_tween.parallel().tween_property(hit_label, "global_position:y", -0.5, 0.50).as_relative().set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EaseType.EASE_IN_OUT).set_delay(0.75)
			
			label_tween.tween_callback(hit_label.queue_free)

			# SHAPES
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


func get_spawn_point() -> Vector2:
	var r: float = ($SpawnerMesh.mesh as CylinderMesh).top_radius * sqrt(randf())
	var theta: float = randf() * TAU
	var offset := Vector2(cos(theta) * r, sin(theta) * r)
	return offset
