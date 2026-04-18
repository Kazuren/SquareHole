class_name ShapeEntity
extends MeshInstance3D

# baseline width equal to 1 UNIT for polygons
const baseline_width: int = 100

@onready var collisionShape2D: CollisionShape2D = $%CollisionShape2D

func get_shape() -> ConvexPolygonShape2D:
	if collisionShape2D.shape is not ConvexPolygonShape2D:
		push_error("USE POLYGON STUPID")
	
	return collisionShape2D.shape

func get_area(mesh_vertices: PackedVector2Array) -> float:
	var result := 0.0
	var num_vertices := mesh_vertices.size()

	for q in range(num_vertices):
		var p = (q - 1 + num_vertices) % num_vertices
		result += mesh_vertices[q].cross(mesh_vertices[p])
	
	return abs(result) * 0.5 / (baseline_width**2)
	
func get_translated_vectorarray(array: PackedVector2Array) -> PackedVector2Array:
	var newVectorArray: PackedVector2Array = PackedVector2Array()
	
	for v: Vector2 in array:
		newVectorArray.append(v + Vector2(self.position.x, self.position.z) * baseline_width)
	
	return newVectorArray

func intersect(other_entity: ShapeEntity) -> float:
	var my_shape = self.get_shape()
	var other_shape = other_entity.get_shape()
	
	var my_shape_translated_points = self.get_translated_vectorarray(my_shape.points)
	var other_shape_translated_points = other_entity.get_translated_vectorarray(other_shape.points)
	
	var intersection_shapes: Array[PackedVector2Array] = Geometry2D.intersect_polygons(my_shape_translated_points, other_shape_translated_points)
	
	return get_area(intersection_shapes[0])
