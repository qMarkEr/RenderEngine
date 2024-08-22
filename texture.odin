package main

import stb "vendor:stb/image"
import "core:math/linalg"

ReadFromFile :: proc(fname : cstring) -> (bdata : []byte, w, h, channels : i32) {
	fdata := stb.loadf(PATH, &w, &h, &channels, 3)
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
	i, j : i32 = i32(uv.x * f32(w)), i32(uv.y * f32(h))
	i, j = clamp(0, i, w - 1), clamp(0, j, h - 1)
	c : color = {
		f32(t.image_data[j * channels * w + i * channels]) * scale,
		f32(t.image_data[j * channels * w + i * channels + 1]) * scale,
		f32(t.image_data[j * channels * w + i * channels + 2]) * scale,
		1
	}
	return c
}