extends Node3D


# formula:
# enemy_shape INTERSECT player_shape = intersection_shape
# score = intersection_shape_area / max(enemy_shape_area, player_shape_area)


#THINGS TO FIX:

# fairness of game, way to spawn objects in a more fair way
# add gravity field concept to pull far away objects closer to player (we set a min distance away from player) for fairness

# sounds: 100% match, 0% match, 100->50% lessen pitch, 49->0% lessen pitch
# main menu

# distortion as player loses sanity?

# maybe switch from curved to linear score formula as game progresses to aid in difficulty scaling?


@onready var heartbeat_player := AudioStreamPlayer.new()
@onready var heartbeat_timer := Timer.new()



@export var intersection_material: BaseMaterial3D
@export var xor_material: BaseMaterial3D
@export var preview_material: BaseMaterial3D
@export var hit_label_scene: PackedScene
@export var score_color_gradient: Gradient # sampled at score_base (0-1) for the hit label color


@onready var player: ShapeEntity = $Player
@onready var end_screens: EndScreens = $EndScreens
@onready var signal_distortion_rect: ColorRect = $SignalDistortion/ColorRect

@export var enemy_scenes: Array[PackedEnemy]


# Integer physics-frame counter so elapsed time is exact and pauses with the tree.
var elapsed_physics_frames: int = 0
var endless_mode: bool = false
var game_ended: bool = false

@export var game_duration: float = 1200.0 # seconds

var SANITY_MULTIPLIER: float = 0.05 # in percent
@export var sanity_penalty_curve: Curve # X: 0-1 (progress over game_duration), Y: penalty multiplier
@export_range(0.1, 1.0, 0.05) var enemy_shape_scale: float = 1.0
@export_range(0.0, 5.0, 0.1) var magnet_radius: float = 0.2
@export_range(0.0, 10.0, 0.1) var magnet_strength: float = 3.0

@export var heartbeat_min_bpm: float = 60.0
@export var heartbeat_max_bpm: float = 133.0

# x -> insanity, y -> bpm
@export var heartbeat_bpm_curve: Curve

var enemies: Array[ShapeEntity] = []
var enemy_previews: Dictionary = {} # ShapeEntity -> CSGPolygon3D
var SPAWN_HEIGHT: float = 15.0

var rng = RandomNumberGenerator.new()

const SANE_TEXTURE = preload("res://Art/GirlExpressions/squareHoleGirlSane.png")
const SEMISANE_TEXTURE = preload("res://Art/GirlExpressions/squareHoleGirlSemiSane.png")
const INSANE_TEXTURE = preload("res://Art/GirlExpressions/squareHoleGirlInsane.png")

const HIT_SFX = preload("res://Sound/Sfx/successSfx.wav")
const MISS_SFX = preload("res://Sound/Sfx/failureSfx.wav")

func render_girl_sanity_expression(sanityValue: float) -> void:
	if sanityValue <= 100 and sanityValue >= 67:
		%GirlSanityExpression.texture = SANE_TEXTURE
	elif sanityValue < 67 and sanityValue >= 34:
		%GirlSanityExpression.texture = SEMISANE_TEXTURE
	else:
		%GirlSanityExpression.texture = INSANE_TEXTURE
		

func render_sanity() -> void:
	#sanity bar
	$%SanityBar.value = GameStats.sanity * 100;
	$%SanityLabel.text = "%d%%" % (GameStats.sanity * 100)

	#girl sanity expression
	render_girl_sanity_expression($%SanityBar.value)

	#signal distortion — more distortion the lower the sanity
	(signal_distortion_rect.material as ShaderMaterial).set_shader_parameter("intensity", 1.0 - GameStats.sanity)

	#heartbeat — BPM speeds up as sanity drops (pitch unchanged)
	var panic: float = 1.0 - GameStats.sanity
	var curved_panic: float = heartbeat_bpm_curve.sample(panic) if heartbeat_bpm_curve else panic
	var bpm: float = lerp(heartbeat_min_bpm, heartbeat_max_bpm, curved_panic)
	heartbeat_timer.wait_time = 60.0 / bpm

func get_elapsed_seconds() -> float:
	return elapsed_physics_frames / float(Engine.physics_ticks_per_second)


func get_game_progress() -> float:
	return clamp(get_elapsed_seconds() / game_duration, 0.0, 1.0)


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
	# Reset sanity on game restart
	GameStats.sanity = 1.0
	render_sanity()

	rng.seed = 42

	print_enemy_spawn_probabilities()
	print_enemy_rotation_probabilities()

	Engine.time_scale = 1
	$SpawnTimer.timeout.connect(_on_timer_timeout)

	end_screens.retry_pressed.connect(_on_retry_pressed)
	end_screens.endless_mode_pressed.connect(_on_endless_mode_pressed)

	add_child(heartbeat_player)
	heartbeat_player.stream = _make_heartbeat()
	add_child(heartbeat_timer)
	heartbeat_timer.timeout.connect(func() -> void: heartbeat_player.play())
	render_sanity()
	heartbeat_timer.start()
	heartbeat_player.play()


func update_timer() -> void:
	var elapsed: float = get_elapsed_seconds()
	var minutes: int = int(elapsed / 60)
	var seconds: int = int(fmod(elapsed, 60))
	$%SurvivalTimeLabel.text = "%02d:%02d" % [minutes, seconds]

func _on_timer_timeout() -> void:
	spawn_enemy()


func spawn_enemy() -> void:
	var enemy_packed: PackedEnemy = pick_enemy()
	if enemy_packed == null:
		return

	var spawn_point: Vector2 = get_spawn_point()

	var node: ShapeEntity = enemy_packed.scene.instantiate()
	node.shape_scale = enemy_shape_scale
	node.shape_rotation_degrees = pick_enemy_rotation(enemy_packed)

	add_child(node)
	enemies.append(node)
	node.global_position = Vector3(spawn_point.x, SPAWN_HEIGHT, spawn_point.y)

	# Create silhouette preview on the ground
	var preview := CSGPolygon3D.new()
	add_child(preview)
	preview.depth = 0.01
	preview.polygon = node.get_points_local_transformed()
	preview.rotate_x(deg_to_rad(90))
	preview.global_position = Vector3(node.position.x, 0.005, node.position.z)
	preview.material = preview_material.duplicate()
	preview.sorting_offset = 5
	enemy_previews[node] = preview


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	update_timer()
	check_end_conditions()


func check_end_conditions() -> void:
	if game_ended:
		return
	if GameStats.sanity <= 0.0:
		game_ended = true
		get_tree().paused = true
		end_screens.show_game_over()
		return
	if not endless_mode and get_elapsed_seconds() >= game_duration:
		game_ended = true
		get_tree().paused = true
		end_screens.show_victory()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_endless_mode_pressed() -> void:
	endless_mode = true
	game_ended = false
	get_tree().paused = false
	end_screens.hide_all()

func _physics_process(delta: float) -> void:
	elapsed_physics_frames += 1

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
			hit_label.text = ("%d%%" + ("!" if score_base >= 0.5 else "?!")) % (score_base * 100) #int(round(score_base * 100))
			if score_color_gradient:
				hit_label.modulate = score_color_gradient.sample(score_base)
			else:
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
			
	
			if score_base >= 0.5:
				$AudioPlayer.stream = HIT_SFX
				$AudioPlayer.pitch_scale = score_base
			else:
				$AudioPlayer.stream = MISS_SFX
				$AudioPlayer.pitch_scale = score_base

			$AudioPlayer.play()

			# SHAPES
			var intersection_shape: Variant = player.get_intersection_shape(e) # PackedVector2Array | NULL
			var enemy_uncovered_shapes: Array[PackedVector2Array] = player.get_enemy_uncovered_shapes(e)
			var player_excess_shapes: Array[PackedVector2Array] = player.get_player_excess_shapes(e)

			if intersection_shape != null:
				var centroid := Vector2.ZERO
				for p in intersection_shape:
					centroid += p
				centroid /= intersection_shape.size()

				var local_points := PackedVector2Array()
				for p in intersection_shape:
					local_points.append(p - centroid)

				var intersection_polygon: CSGPolygon3D = CSGPolygon3D.new()
				add_child(intersection_polygon)

				intersection_polygon.depth = 0.02
				intersection_polygon.polygon = local_points
				intersection_polygon.rotate_x(deg_to_rad(90))
				intersection_polygon.global_position = Vector3(centroid.x, 0.01, centroid.y)
				intersection_polygon.material = intersection_material.duplicate()
				intersection_polygon.sorting_offset = 10

				var intersection_tween = get_tree().create_tween()

				# from 0 alpha to 1 over 0.5 seconds
				intersection_tween.tween_property((intersection_polygon.material as BaseMaterial3D), "albedo_color:a", 1, 0.5).from(0) \
				.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_OUT)

				# from 1 alpha to 0 over 1 seconds
				intersection_tween.tween_property((intersection_polygon.material as BaseMaterial3D), "albedo_color:a", 0, 1).from_current() \
				 	.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

				intersection_tween.tween_callback(intersection_polygon.queue_free)


			spawn_xor_visual(enemy_uncovered_shapes)
			spawn_xor_visual(player_excess_shapes)


func spawn_xor_visual(shapes: Array[PackedVector2Array]) -> void:
	if shapes.is_empty():
		return

	# Shared pivot across all shapes so the combiner sits at a meaningful
	# position and each child polygon is stored in local space around it.
	var centroid := Vector2.ZERO
	var total_points := 0
	for shape in shapes:
		for p in shape:
			centroid += p
			total_points += 1
	if total_points > 0:
		centroid /= total_points

	# Use a combiner so clockwise-winding polygons (holes from clip_polygons)
	# can be subtracted from their outer boundary. This produces ring shapes
	# when one polygon fully contains the other.
	var combiner := CSGCombiner3D.new()
	add_child(combiner)
	combiner.rotate_x(deg_to_rad(90))
	combiner.global_position = Vector3(centroid.x, 0.01, centroid.y)
	combiner.sorting_offset = 10

	var child_materials: Array[BaseMaterial3D] = []

	for shape in shapes:
		var csg := CSGPolygon3D.new()
		combiner.add_child(csg)
		var local_shape := PackedVector2Array()
		for p in shape:
			local_shape.append(p - centroid)
		csg.polygon = local_shape
		csg.depth = 0.02
		csg.material = xor_material.duplicate()
		child_materials.append(csg.material)

		if Geometry2D.is_polygon_clockwise(shape):
			csg.operation = CSGShape3D.OPERATION_SUBTRACTION

	var tween = get_tree().create_tween()
	for mat in child_materials:
		# from 0 alpha to 1 over 0.5 seconds
		tween.parallel().tween_property(mat, "albedo_color:a", 1, 0.5).from(0) \
			.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for mat in child_materials:
		# from 1 alpha to 0 over 1 second
		tween.parallel().tween_property(mat, "albedo_color:a", 0, 1).from_current() \
			.set_trans(Tween.TransitionType.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
			.set_delay(0.5)
	tween.tween_callback(combiner.queue_free)


func get_spawn_point() -> Vector2:

	var r: float = ($SpawnerMesh.mesh as CylinderMesh).top_radius * sqrt(rng.randf())
	var theta: float = rng.randf() * TAU
	var offset := Vector2(cos(theta) * r, sin(theta) * r)
	return offset


func print_enemy_spawn_probabilities() -> void:
	if enemy_scenes.is_empty():
		return

	print("Enemy spawn probabilities by minute:")
	var header := "  min  "
	for pack in enemy_scenes:
		var enemy_name := "?"
		if pack and pack.scene:
			enemy_name = pack.scene.resource_path.get_file().get_basename()
		header += "| %10s " % enemy_name
	print(header)

	var total_minutes := int(game_duration / 60.0)
	for minute in range(total_minutes + 1):
		var progress: float = clamp((minute * 60.0) / game_duration, 0.0, 1.0)

		var weights: Array[float] = []
		var total: float = 0.0
		for pack in enemy_scenes:
			var w: float = 0.0
			if pack and pack.weight_curve:
				w = maxf(pack.weight_curve.sample(progress), 0.0)
			weights.append(w)
			total += w

		var row := "  %3d  " % minute
		for w in weights:
			var pct: float = (w / total * 100.0) if total > 0.0 else 0.0
			row += "| %9.1f%% " % pct
		print(row)


func print_enemy_rotation_probabilities() -> void:
	if enemy_scenes.is_empty():
		return

	var total_minutes := int(game_duration / 60.0)
	for pack in enemy_scenes:
		if not pack:
			continue
		var enemy_name := "?"
		if pack.scene:
			enemy_name = pack.scene.resource_path.get_file().get_basename()

		if pack.rotation_weight_curves.is_empty():
			print("Rotation probabilities for ", enemy_name, ": none (always 0°)")
			continue

		print("Rotation probabilities for ", enemy_name, " by minute:")
		var header := "  min  "
		for i in pack.rotation_weight_curves.size():
			header += "| %6s° " % str(int(pack.rotation_angles[i]))
		print(header)

		for minute in range(total_minutes + 1):
			var progress: float = clamp((minute * 60.0) / game_duration, 0.0, 1.0)

			var weights: Array[float] = []
			var total: float = 0.0
			for curve: Curve in pack.rotation_weight_curves:
				var w: float = 0.0
				if curve:
					w = maxf(curve.sample(progress), 0.0)
				weights.append(w)
				total += w

			var row := "  %3d  " % minute
			for w in weights:
				var pct: float = (w / total * 100.0) if total > 0.0 else 0.0
				row += "| %6.1f%% " % pct
			print(row)


func pick_enemy() -> PackedEnemy:
	if enemy_scenes.is_empty():
		return null

	var progress := get_game_progress()
	var weights: Array[float] = []
	var total: float = 0.0
	for pack in enemy_scenes:
		var w: float = 0.0
		if pack and pack.weight_curve:
			w = maxf(pack.weight_curve.sample(progress), 0.0)
		weights.append(w)
		total += w

	if total <= 0.0:
		return null

	var roll := rng.randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return enemy_scenes[i]
	return enemy_scenes[enemy_scenes.size() - 1]


func pick_enemy_rotation(pack: PackedEnemy) -> float:
	if pack.rotation_weight_curves.is_empty():
		return 0.0

	var progress := get_game_progress()
	var weights: Array[float] = []
	var total: float = 0.0
	for curve: Curve in pack.rotation_weight_curves:
		var w: float = 0.0
		if curve:
			w = maxf(curve.sample(progress), 0.0)
		weights.append(w)
		total += w

	if total <= 0.0:
		return 0.0

	var roll := rng.randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return pack.rotation_angles[i]
	return 0.0



func _make_heartbeat() -> AudioStreamWAV:
	var sample_rate := 44100
	var total_samples := int(sample_rate * 0.4)
	var data := PackedByteArray()
	data.resize(total_samples * 2)  # 16-bit mono = 2 bytes/sample

	for i in total_samples:
		var t := float(i) / sample_rate
		var sample := 0.0

		# "lub" — sharper, higher
		if t < 0.15:
			sample = sin(TAU * 60.0 * t) * exp(-t * 18.0)
		# "dub" — softer, slightly lower, 0.22s later
		elif t >= 0.22:
			var dt := t - 0.22
			sample = sin(TAU * 50.0 * dt) * exp(-dt * 14.0) * 0.7

		var v := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, v)

	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream
