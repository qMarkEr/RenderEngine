package main

BG_shader :: proc(ray_: Ray) -> (mtl : Material) {
    a := 0.5 * (ray_.direction.y + 1.0)
	mtl = {
		diffuze=((1 - a) * space_color_bottom + a * space_color_top)
	}
	return
}

Normal_Shader :: proc(point: Vector3) -> (mtl : Material) {
    mtl.diffuze = {
        0.5 * (point.x + 1),
        0.5 * (point.y + 1),
        0.5 * (point.z + 1),
        1
    }
    return
}

// Intersection_Shader :: proc(mtl : ) -> (mtl : Material) {

// }