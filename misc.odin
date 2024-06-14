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

Colorize :: proc(renderer : ^SDL.Renderer, mtl : Material, i, j : i32) {
	shaded_color : color = {
		clamp(LinearToGamma(mtl.diffuze.r), 0, 1),
		clamp(LinearToGamma(mtl.diffuze.g), 0, 1),
		clamp(LinearToGamma(mtl.diffuze.b), 0, 1),
		1
	}
	SDL.SetRenderDrawColor(renderer, expand(shaded_color))
	SDL.RenderDrawPoint(
		renderer,
		i,
		WINDOW_H - j
	)
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

Rotate_x :: proc(angle : f32, vec : Vector3) -> Vector3 {
	c := M.cos_f32(angle)
	s := M.sin_f32(angle)
	m := matrix[3, 3]f32 {
		1, 0, 0,
		0, c, -s,
		0, s, c
	}
	res := vec * m
	return res
}

Rotate_y :: proc (angle : f32, vec : Vector3) -> Vector3 {
	c := M.cos_f32(angle)
	s := M.sin_f32(angle)
	m := matrix[3, 3]f32 {
		c, 0, s,
		0, 1, 0,
		-s, 0, c
	}
	res := vec * m
	return res
}


RotateCam :: proc (cam : Camera, dir : Vector3) -> (res : Vector3) {
	res = dir
	res = Rotate_x(cam.angle_x, res)
	res = Rotate_y(cam.angle_y, res)
	return
}

Reflect :: proc(ray : Ray, normal, intersection : Vector3) -> Ray {
	dir : = linalg.vector_normalize(ray.direction - 2 * normal * linalg.dot(ray.direction, normal))
	new : Ray = {origin = intersection + normal * SHADOW_BIAS, direction = dir}
	return new
}

RandomReflect :: proc(ray_ : Ray, normal, intersection : Vector3) -> (res : Ray) {
	res.origin = intersection  + normal * SHADOW_BIAS
	res.direction = normal + RandomUnitVector()
	if CloseToZero(res.direction) do res.direction = normal
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

SampleVector :: proc(vec : Vector2) -> Vector2 {
    sample_square : Vector2 = {
        rnd.float32() - 0.5,
        rnd.float32() - 0.5,
    }
    return vec + sample_square
}

// ------ misc ----

CloseToZero :: proc(v : Vector3) -> bool {
	s : f32 = 1e-8;
	return (abs(v.x) < s) && (abs(v.y) < s) && (abs(v.z) < s);
}

RandomUnitVector :: proc() -> Vector3 {
	rand_vec : Vector3 = {rnd.float32_normal(0.5, 1), rnd.float32_normal(0.5, 1), rnd.float32_normal(0.5, 1)}
	return linalg.vector_normalize(rand_vec)
}

RandomOnDisk :: proc() -> Vector2 {
	for {
		rand_vec : Vector2 = {rnd.float32_normal(0.5, 1), rnd.float32_normal(0.5, 1)}
		if linalg.length(rand_vec) < 1 do return rand_vec
	}
}