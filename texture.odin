package main

import stb "vendor:stb/image"
import "core:math/linalg"
import rnd "core:math/rand"

ReadFromFile :: proc(fname : cstring) -> (bdata : []byte, w, h, channels : i32) {
	fdata := stb.loadf(fname, &w, &h, &channels, 3)
	total : i32 = w * h * channels
	bdata  = make([]byte, total)
	for i in 0..<total {
		if fdata[i] == 0 do bdata[i] = 0
		else if fdata[i] == 1 do bdata[i] = 255.0
		else do bdata[i] = u8(linalg.floor(fdata[i] * 256.0))
	}
	return
}

GetPixel :: proc(t : Texture, w, h, channels : i32, uv : Vector2) -> color {
	scale :: 1.0 / 255.0
	if t.image_data == nil do return t.albedo
	i, j : i32 = i32(uv.x * f32(w)), i32((1.0 - uv.y) * f32(h))
	i, j = clamp(0, i, w - 1), clamp(0, j, h - 1)
	c : color = {
		f32(t.image_data[j * channels * w + i * channels]) * scale,
		f32(t.image_data[j * channels * w + i * channels + 1]) * scale,
		f32(t.image_data[j * channels * w + i * channels + 2]) * scale,
		1
	}
	return c
}

GeneratePerlin :: proc(scale : u8) -> (t : Noize) {
	for i in 0..<256 do t.rand[i] = RandomVectorRange(-1, 1)
	Permute(&t.x)
	Permute(&t.y)
	Permute(&t.z)
	t.gen = true
	t.scale = scale
	return
}

Permute :: proc(array : ^[256]i32) {
	for i in 0..<256 do array[i] = i32(i)
	for i in 0..<256 {
		index := rnd.int31() % 256
		array[i], array[index] = array[index], array[i]
	}
}

GetPerlinPixel :: proc(t : Noize, p_ : Vector3) -> f32 {
	p := p_ * f32(t.scale)
	u, v, w := p.x - linalg.floor(p.x), p.y - linalg.floor(p.y), p.z - linalg.floor(p.z)

	i, j, k := i32(linalg.floor(p.x)), i32(linalg.floor(p.y)), i32(linalg.floor(p.z))
	c : [2][2][2]Vector3
	for di in 0..<2 {
		for dj in 0..<2 {
			for dk in 0..<2 {
				c[di][dj][dk] = t.rand[
					t.x[(i + i32(di)) & 255] ~
					t.x[(j + i32(dj)) & 255] ~
					t.x[(k + i32(dk)) & 255]]
			}
		}	
	}
	return Trilinear(c, u, v, w)
}

Trilinear :: proc(c : [2][2][2]Vector3, u, v, w : f32) -> (res : f32) {
	uu, vv, ww := u * u * (3 - 2 * u), v * v * (3 - 2 * v), w * w * (3 - 2 * w)
	for i in 0..<2 {
		for j in 0..<2 {
			for k in 0..<2 {
				weight : Vector3 = {u - f32(i), v - f32(j), w - f32(k)}
				res += (f32(i) * uu + (1 - f32(i)) * (1 - uu)) * 
					   (f32(j) * vv + (1 - f32(j)) * (1 - vv)) *
					   (f32(k) * ww + (1 - f32(k)) * (1 - ww)) *
					   linalg.dot(c[i][j][k], weight)
			}
		}	
	}
	return
}

Falloff :: proc(n, dir : Vector3) -> f32 {
	dot := linalg.dot(-n, dir)
	return dot
}

Turbulence :: proc(t : Noize, p : Vector3, d : i32) -> (res : f32) {
	temp := p
	weight : f32 = 1
	for i in 0..<d {
		res += weight * GetPerlinPixel(t, temp)
		weight *= 0.5
		temp *= 2
	}
	return
}

Marble :: proc(t : Noize, p : Vector3) -> (color) {
	return {.5, .5, .5, 1} * (1.0 + linalg.sin(p.y * f32(t.scale) + 10 * Turbulence(t, p, 7)))
}