package main

import M "core:math"
import SDL "vendor:sdl2"
import "core:math/linalg"
import rnd "core:math/rand"

// -------- COLOR ------------

hex_to_rgba :: proc(hex : int) -> color { 
	return {
		f32(hex >> 16) / 255.0,
		f32((hex & 0x00FF00) >> 8) / 255.0,
		f32(hex & 0x0000FF) / 255.0,
		1.0
	}
}

expand :: proc (c : color) -> (r, g, b, a : u8) {
	return u8(M.round(c.r * 255)),
		   u8(M.round(c.g * 255)),
		   u8(M.round(c.b * 255)),
		   u8(M.round(c.a * 255))
}

LinearToGamma :: proc(comp : f32) -> f32 {
	if comp > 0 do return M.sqrt_f32(comp)
	return 0
}

// ------- CONVERSION ----------

ConvertToProj :: proc(a : Vector3) -> Vector4 {
	return {a.x, a.y, a.z, 1}
}

ConvertFromProj :: proc(a : Vector4) -> Vector3 {
	return {a.x, a.y, a.z}
}

DegToRad :: proc(angle : f32) -> f32 {
	return angle / 180.0 * SDL.M_PI
}

ConvertNDCToRaster :: proc(a : Vector2) -> Vector2i {
	return {
			i32(M.floor_f32(a.x * f32(WINDOW_W))),
			i32(M.floor_f32((1.0 - a.y) * f32(WINDOW_H)))
		}
}

ConvertToNDC :: proc(a : Vector2) -> Vector2 {
	return {
			a.x / 1.0 + 0.5,
    		a.y / (1.0 / ASPECT) + 0.5
		}
}

ConvertScreenToWorld :: proc(v: Vector2) -> (f32, f32) {
	return (f32(v.x) / f32(WINDOW_W) * 2 - 1), (f32(v.y) / f32(WINDOW_H) * 2 - 1) / ASPECT
}

// ------- TRANSFORMATION -------

Reflect :: proc(ray : Ray, normal, intersection : Vector3) -> Ray {
	dir : = linalg.vector_normalize(ray.direction - 2 * normal * linalg.dot(ray.direction, normal))
	new : Ray = {origin = intersection, direction = dir}
	return new
}

RandomReflect :: proc(ray_ : Ray, normal, intersection : Vector3) -> (res : Ray) {
	rand_vec : Vector3 = {rnd.float32(), rnd.float32(), rnd.float32()}
	res.direction = linalg.vector_normalize(rand_vec)
	res.origin = intersection  + normal * SHADOW_BIAS
	if linalg.dot(res.direction, normal) < 0 do res.direction *= -1
	return res
}

Rotate_y_proj :: proc (angle : f32, m_ : matrix[4, 4]f32) -> matrix[4, 4]f32 {
	c : f32 = f32(M.cos_f32(angle))
	s : f32 = f32(M.sin_f32(angle))
	m := matrix[4, 4]f32 {
		c, 0, s, 0,
		0, 1, 0, 0,
		-s, 0, c, 0,
		0, 0, 0, 1
	}
	return m_ * m
}

Rotate_x_proj :: proc (angle : f32, m_ : matrix[4, 4]f32) -> matrix[4, 4]f32 {
	c : f32 = f32(M.cos_f32(angle))
	s : f32 = f32(M.sin_f32(angle))
	m := matrix[4, 4]f32 {
		1, 0, 0, 0,
		0, c, -s, 0,
		0, s, c, 0,
		0, 0, 0, 1
	}
	return m_ * m
}