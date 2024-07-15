package main

BG_shader :: proc(ray_: Ray) -> color {
    a := 0.5 * (ray_.direction.y + 1.0)
	return ((1 - a) * space_color_bottom + a * space_color_top)
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