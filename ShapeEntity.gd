class_name ShapeEntity
extends MeshInstance3D

var shape_scale: float = 1.0:
	set(value):
		shape_scale = value
		self.scale = Vector3.ONE * shape_scale

var shape_rotation_degrees: float = 0.0:
	set(value):
		shape_rotation_degrees = value
		self.rotation.y = deg_to_rad(-value) # negative so positive input = CW from top-down view

@onready var collisionShape2D: CollisionShape2D = $%CollisionShape2D


func get_shape_2d() -> ConvexPolygonShape2D:
	if collisionShape2D.shape is not ConvexPolygonShape2D:
		push_error("USE POLYGON STUPID")
	
	return collisionShape2D.shape


func get_points_2d() -> PackedVector2Array:
	return self.get_shape_2d().points


func get_area_2d() -> float:
	return get_area_2d_of(self.get_points_2d())


static func get_area_2d_of(mesh_vertices: PackedVector2Array) -> float:
	return abs(get_signed_area_2d_of(mesh_vertices))


static func get_signed_area_2d_of(mesh_vertices: PackedVector2Array) -> float:
	# Signed shoelace: outer boundaries and holes have opposite sign,
	# so summing multiple polygons from clip/exclude operations handles holes correctly.
	var result := 0.0
	var num_vertices := mesh_vertices.size()

	for q in range(num_vertices):
		var p = (q - 1 + num_vertices) % num_vertices
		result += mesh_vertices[q].cross(mesh_vertices[p])

	return result * 0.5


static func get_area_2d_of_many(shapes: Array[PackedVector2Array]) -> float:
	var total := 0.0
	for shape in shapes:
		total += get_signed_area_2d_of(shape)
	return abs(total)


func get_translated_vectorarray() -> PackedVector2Array:
	var projected_pos_scaled = Vector2(self.position.x, self.position.z)
	return self.get_points_2d() \
		* Transform2D(0, Vector2.ONE * shape_scale, 0, Vector2.ZERO) \
		* Transform2D(deg_to_rad(-shape_rotation_degrees), Vector2.ONE, 0, Vector2.ZERO) \
		* Transform2D(0, Vector2.ONE, 0, -projected_pos_scaled)


func get_points_local_transformed() -> PackedVector2Array:
	# Scale + rotation only, no translation. Use together with a node
	# positioned at the entity's world position for a properly-oriented shape.
	return self.get_points_2d() \
		* Transform2D(0, Vector2.ONE * shape_scale, 0, Vector2.ZERO) \
		* Transform2D(deg_to_rad(-shape_rotation_degrees), Vector2.ONE, 0, Vector2.ZERO)


func get_intersection_shape(other_entity: ShapeEntity) -> Variant: # PackedVector2Array | NULL
	var my_shape_translated_points = self.get_translated_vectorarray()
	var other_shape_translated_points = other_entity.get_translated_vectorarray()
	
	var intersection_shapes: Array[PackedVector2Array] = Geometry2D.intersect_polygons(my_shape_translated_points, other_shape_translated_points)
	if intersection_shapes.size() > 0:
		return intersection_shapes[0] 
	else:
		return null


func get_intersection_area(other_entity: ShapeEntity) -> float:
	var my_points = self.get_translated_vectorarray()
	var other_points = other_entity.get_translated_vectorarray()
	return get_area_2d_of_many(Geometry2D.intersect_polygons(my_points, other_points))


func get_enemy_uncovered_shapes(other_entity: ShapeEntity) -> Array[PackedVector2Array]:
	# parts of the enemy (other) NOT covered by the player (self)
	var my_points = self.get_translated_vectorarray()
	var other_points = other_entity.get_translated_vectorarray()
	return Geometry2D.clip_polygons(other_points, my_points)


func get_player_excess_shapes(other_entity: ShapeEntity) -> Array[PackedVector2Array]:
	# parts of the player (self) that extend beyond the enemy (other)
	# only returned when there's an actual overlap, no "floating" red on full misses
	if get_intersection_shape(other_entity) == null:
		return []
	var my_points = self.get_translated_vectorarray()
	var other_points = other_entity.get_translated_vectorarray()
	return Geometry2D.clip_polygons(my_points, other_points)


func get_xor_area(other_entity: ShapeEntity) -> float:
	# for scoring: full symmetric difference (enemy uncovered + player excess)
	# signed sum correctly handles annular results (outer CCW + hole CW) that
	# exclude_polygons returns when one shape fully contains the other
	return get_area_2d_of_many(Geometry2D.exclude_polygons(
		other_entity.get_translated_vectorarray(),
		self.get_translated_vectorarray()
	))


enum ScoreFormula { LINEAR, CURVED }


# CURVED seems to feel more fun
func calculate_score_base(other_entity: ShapeEntity, formula: ScoreFormula = ScoreFormula.CURVED) -> float:
	var i_area = self.get_intersection_area(other_entity)
	var x_area = self.get_xor_area(other_entity)

	var raw: float = i_area / (i_area + x_area)

	match formula:
		ScoreFormula.LINEAR:
			return raw
		ScoreFormula.CURVED:
			return pow(raw, 0.7)
		_:
			return raw
