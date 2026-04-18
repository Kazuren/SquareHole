extends Node3D


# formula:
# enemy_shape INTERSECT player_shape = intersection_shape
# score = intersection_shape_area / max(enemy_shape_area, player_shape_area)


#THINGS TO FIX:

# fairness of game, way to spawn objects in a more fair way
# add gravity field concept to pull far away objects closer to player (we set a min distance away from player) for fairness
# find better gradient for popup text percentage
# sounds: 100% match, 0% match, 100->50% lessen pitch, 49->0% lessen pitch
# more shapes

# game over/win screen(after 20 minutes?)
# main menu

# player switching shape
# rotate player, spawn rotated enemy shapes

@export var intersection_material: BaseMaterial3D
@export var xor_material: BaseMaterial3D
@export var preview_material: BaseMaterial3D
@export var hit_label_scene: PackedScene


@onready var player: ShapeEntity = $Player

@export var enemy_scenes: Array[PackedEnemy]


var starting_time_ticks: int

const GAME_DURATION: float = 1200.0 # 20 minutes in seconds

var SANITY_MULTIPLIER: float = 0.05 # in percent
@export var sanity_penalty_curve: Curve # X: 0-1 (time over 20 min), Y: penalty multiplier
@export_range(0.1, 1.0, 0.05) var enemy_shape_scale: float = 1.0
@export_range(0.0, 5.0, 0.1) var magnet_radius: float = 0.2
@export_range(0.0, 10.0, 0.1) var magnet_strength: float = 3.0

var enemies: Array[ShapeEntity] = []
var enemy_previews: Dictionary = {} # ShapeEntity -> CSGPolygon3D
var enemy_bag: Bag
var SPAWN_HEIGHT: float = 15.0

var rng = RandomNumberGenerator.new()

func render_sanity() -> void:
	$%SanityBar.value = GameStats.sanity * 100;
	$%SanityLabel.text = "%d%%" % (GameStats.sanity * 100)


func get_elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - starting_time_ticks) / 1000.0


func get_game_progress() -> float:
	return clamp(get_elapsed_seconds() / GAME_DURATION, 0.0, 1.0)


func get_sanity_penalty_multiplier() -> float:
	if sanity_penalty_curve:
		return sanity_penalty_curve.sample(get_game_progress())
	return 1.0


enum SanityFormula { DEFAULT, FORGIVING }

func calculate_sanity_change(score_base: float, formula: SanityFormula = SanityFormula.DEFAULT) -> float:
	var change: float
	match formula:
		SanityFormula.DEFAULT:
			change = (score_base - (1.0 - score_base)) * SANITY_MULTIPLIER
		SanityFormula.FORGIVING:
			change = (score_base - (1.0 - score_base) * 0.5) * SANITY_MULTIPLIER
		_:
			change = 0.0

	# Only apply penalty ramp to sanity loss
	if change < 0:
		change *= get_sanity_penalty_multiplier()
	return change


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	render_sanity()

	rng.seed = 42
	enemy_bag = Bag.new(rng)
	for enemy_pack in enemy_scenes:
		enemy_bag.add(enemy_pack, enemy_pack.weight)

	print(enemy_bag.probabilities())

	starting_time_ticks = Time.get_ticks_msec()

	Engine.time_scale = 1
	$SpawnTimer.timeout.connect(_on_timer_timeout)


func update_timer() -> void:
	var elapsed: float = get_elapsed_seconds()
	var minutes: int = int(elapsed / 60)
	var seconds: int = int(fmod(elapsed, 60))
	$%SurvivalTimeLabel.text = "%02d:%02d" % [minutes, seconds]

func _on_timer_timeout() -> void:
	spawn_enemy()


func spawn_enemy() -> void:
	var draw = enemy_bag.draw()
	if draw is not PackedEnemy:
		push_error("USE PACKEDSCENE")
	
	var spawn_point: Vector2 = get_spawn_point()
	var enemy_packed: PackedEnemy = draw as PackedEnemy
	
	var node: ShapeEntity = enemy_packed.scene.instantiate()
	node.shape_scale = enemy_shape_scale

	add_child(node)
	enemies.append(node)
	node.global_position = Vector3(spawn_point.x, SPAWN_HEIGHT, spawn_point.y)

	# Create silhouette preview on the ground
	var preview := CSGPolygon3D.new()
	add_child(preview)
	preview.depth = 0.01
	preview.polygon = node.get_translated_vectorarray()
	preview.rotate_x(deg_to_rad(90))
	preview.global_translate(Vector3(0, 0.005, 0))
	preview.material = preview_material.duplicate()
	preview.sorting_offset = 5
	enemy_previews[node] = preview


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	update_timer()
	pass


func _physics_process(delta: float) -> void:
	# Pull player toward nearest enemy's ground position when idle
	if not player.is_moving and enemies.size() > 0:
		var closest_dist: float = INF
		var closest_ground_pos: Vector3 = player.global_position
		for e: ShapeEntity in enemies:
			var ground_pos := Vector3(e.position.x, player.global_position.y, e.position.z)
			var dist: float = player.global_position.distance_to(ground_pos)
			if dist < closest_dist:
				closest_dist = dist
				closest_ground_pos = ground_pos
		if closest_dist < magnet_radius:
			if closest_dist < 0.01:
				player.global_position = closest_ground_pos
			else:
				player.global_position = player.global_position.lerp(closest_ground_pos, magnet_strength * delta)

	for e: ShapeEntity in enemies:
		var aabb: AABB = e.get_aabb() # e.mesh.get_aabb()

		# Update preview opacity based on enemy height
		if e in enemy_previews:
			var progress: float = 1.0 - clamp(e.position.y / SPAWN_HEIGHT, 0.0, 1.0)
			(enemy_previews[e].material as BaseMaterial3D).albedo_color.a = progress

		var top_point: Vector3 = aabb.end * e.scale + e.position
		if top_point.y < 0:
			# ENEMY CLEANUP
			if e in enemy_previews:
				enemy_previews[e].queue_free()
				enemy_previews.erase(e)
			e.queue_free()
			enemies.erase(e)

			# SCORE
			var score_base: float = player.calculate_score_base(e)
			GameStats.sanity = clamp(GameStats.sanity + calculate_sanity_change(score_base), 0, 1)
			render_sanity()

			# HIT LABEL
			var hit_label: Label3D = hit_label_scene.instantiate()
			add_child(hit_label)
			hit_label.global_position = player.global_position
			hit_label.text = ("%d%%" + ("!" if score_base >= 0.5 else "?!")) % (score_base * 100)
			hit_label.modulate = lerp(Color.TOMATO, Color.SPRING_GREEN, score_base)
			hit_label.rotate(Vector3.UP, PI * 0.25)
			hit_label.rotate(Vector3.FORWARD, rng.randf_range(PI * -0.125, PI * 0.125))
			
			#hit_label.look_at($Pivot/Camera3D.global_position, Vector3.UP, true)
			#hit_label.rotation_degrees.x = 0aasas
			#hit_label.rotation_degrees.z = 0

			var label_tween = get_tree().create_tween()
			label_tween.parallel().tween_property(hit_label, "modulate:a", 0, 1.25).from_current().set_trans(Tween.TransitionType.TRANS_EXPO).set_ease(Tween.EaseType.EASE_IN)
			label_tween.parallel().tween_property(hit_label, "rotation_degrees:z", rng.randf_range(-25, 25), 1).from_current().set_trans(Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)
			
			label_tween.parallel().tween_property(hit_label, "global_position:y", rng.randf_range(1.2, 1.3), 0.75).as_relative().set_trans(Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)
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
				intersection_polygon.material = intersection_material.duplicate()
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
				xor_polygon.material = xor_material.duplicate()
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
	
	var r: float = ($SpawnerMesh.mesh as CylinderMesh).top_radius * sqrt(rng.randf())
	var theta: float = rng.randf() * TAU
	var offset := Vector2(cos(theta) * r, sin(theta) * r)
	return offset
