class_name ShapeEntity
extends MeshInstance3D

# baseline scale equal to 1 UNIT for polygons
const baseline_scale: int = 100
const baseline_vector: Vector2 = Vector2(100, 100)

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
	var result := 0.0
	var num_vertices := mesh_vertices.size()

	for q in range(num_vertices):
		var p = (q - 1 + num_vertices) % num_vertices
		result += mesh_vertices[q].cross(mesh_vertices[p])
	
	return abs(result) * 0.5 

	
func get_translated_vectorarray() -> PackedVector2Array:
	var projected_pos_scaled = Vector2(self.position.x, self.position.z) * baseline_scale
	return self.get_points_2d() \
		* Transform2D(0, Vector2.ONE, 0, -projected_pos_scaled) \
		* Transform2D(0, Vector2.ONE / baseline_scale, 0, Vector2.ZERO) 


func get_intersection_shape(other_entity: ShapeEntity) -> Variant: # PackedVector2Array | NULL
	var my_shape_translated_points = self.get_translated_vectorarray()
	var other_shape_translated_points = other_entity.get_translated_vectorarray()
	
	var intersection_shapes: Array[PackedVector2Array] = Geometry2D.intersect_polygons(my_shape_translated_points, other_shape_translated_points)
	if intersection_shapes.size() > 0:
	
		return intersection_shapes[0] 
	else:
		return null


func get_intersection_area(other_entity: ShapeEntity) -> float:
	var intersection_shape = get_intersection_shape(other_entity)
	if intersection_shape == null:
		return 0
	
	return get_area_2d_of(intersection_shape)


func get_xor_shape(other_entity: ShapeEntity) -> Variant: # PackedVector2Array | NULL
	var my_shape_translated_points = self.get_translated_vectorarray()
	var other_shape_translated_points = other_entity.get_translated_vectorarray()
	
	var xor_shapes: Array[PackedVector2Array] = Geometry2D.clip_polygons(other_shape_translated_points, my_shape_translated_points)
	if xor_shapes.size() > 0:
		#var projected_pos_scaled = Vector2(other_entity.position.x, other_entity.position.z) * baseline_scale
		return xor_shapes[0] #* Transform2D(0, Vector2.ONE, 0, -projected_pos_scaled)
	else:
		return null


func get_xor_area(other_entity: ShapeEntity) -> float:
	var xor_shape = get_xor_shape(other_entity)
	if xor_shape == null:
		return 0
	
	return get_area_2d_of(xor_shape)


func calculate_score_base(other_entity: ShapeEntity) -> float:
	var i_area = self.get_intersection_area(other_entity)
	var x_area = self.get_xor_area(other_entity)
	print("score:", i_area, ",", x_area)
	return i_area / (i_area + x_area)
