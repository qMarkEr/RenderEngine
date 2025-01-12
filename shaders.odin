package main

BG_shader :: proc(ray_: Ray) -> color {
    a := 0.5 * (ray_.direction.y + 1.0)
    black : color = {0, 0, 0, 1}
	return  {0.7, 0.7, .7, 1} // ((1 - a) * space_color_bottom + a * space_color_top)
}

Normal_Shader :: proc(point: Vector3) -> (mtl : Material) {
    mtl.diffuze.albedo = {
        0.5 * (point.x + 1),
        0.5 * (point.y + 1),
        0.5 * (point.z + 1),
        1
    }
    return
}

// Intersection_Shader :: proc(mtl : ) -> (mtl : Material) {

// }