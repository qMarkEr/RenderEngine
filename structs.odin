package main

color :: distinct [4]f32
Vector4 :: [4]f32
Vector3 :: [3]f32
Vector3i :: [3]i32
Vector2 :: [2]f32
Vector2i :: [2]i32

Sphere :: struct {
	center : Vector3,
	r : f32,
	mtl : Material
}

Ray :: struct {
	direction : Vector3,
	origin : Vector3
}

Camera :: struct {
	delta_u, delta_v : f32,
	w, h : f32,
	origin : Vector3,
	fl : f32,
	angle_x : f32,
	angle_y : f32,
	samples : i32,
	pixel_samples_scale : f32,
	defocus_disk : Vector2,
	focus_distance : f32,
	apperture : f32
}

Material :: struct {
	diffuze : color,
	fuzz : f32,
	IOR : f32,
	transmission : f32,
	metallic : f32
}

HitInfo :: struct {
	did_hit : bool,
	intersection, 
	normal : Vector3,
	mtl : Material
}