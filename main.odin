package main

import "core:fmt"
import SDL "vendor:sdl2"
import M "core:math"
import "core:math/linalg"
import rnd "core:math/rand"
import "core:thread"
import "core:time"
import "core:sync"

cam : Camera
spheres := BasicScene()
window : ^SDL.Window
renderer : ^SDL.Renderer
frame : [WINDOW_W + 1][WINDOW_H + 1]color
root_node : BVH_node
sphere_count : i32 = len(spheres)

Interpolate :: proc(renderer : ^SDL.Renderer, a_, b_ : Vector2i) {
	a := a_
    b := b_
    dx : i32 = abs(b.x - a.x)
    sx : i32 = a.x < b.x ? 1 : -1
    dy : i32 = -abs(b.y - a.y)
    sy : i32 = a.y < b.y ? 1 : -1
    error := dx + dy
    
    for {
		SDL.RenderDrawPoint(renderer, a.x, a.y)
        if a.x == b.x && a.y == b.y do break
        e2 := 2 * error
        if e2 >= dy {
            if a.x == b.x do break
            error += dy
            a.x += sx
		}
        if e2 <= dx {
            if a.y == b.y do break
            error += dx
            a.y += sy
		}
	}
}

DrawAxis :: proc(renderer : ^SDL.Renderer, x_end : Vector3 , cam : Camera) {

	start : Vector3 : {0, 0, 0}

	proj := matrix[4, 4]f32 {
		cam.fl / 10,           0,  0, 0,
		          0, cam.fl / 10,  0, 0,
		          0,           0,  1, 0,
		          0,           0,  0, 1
	}

	proj = Rotate_y_proj(-cam.angle_y, proj)
	proj = Rotate_x_proj(-cam.angle_x, proj)

	world_cam_m := linalg.matrix4_inverse(proj)

	proj_x : Vector3 = ConvertFromProj(ConvertToProj(x_end) * proj)
	proj_x = linalg.normalize(proj_x) / AXIS_LENGTH
	NDC_start := ConvertToNDC({start.x, start.y})
	NDC_start.x += AXIS_OFFSET
	NDC_start.y += AXIS_OFFSET

	NDC_x := ConvertToNDC({proj_x.x, proj_x.y})

	NDC_x.x += AXIS_OFFSET
	NDC_x.y += AXIS_OFFSET

	SDL.SetRenderDrawColor(renderer, u8(255 * x_end.x), u8(255 * x_end.y), u8(255 * x_end.z), 255)
	Interpolate(renderer, ConvertNDCToRaster(NDC_start), ConvertNDCToRaster(NDC_x))
}


DrawBBox :: proc(a : AABB) {
    sss : Vector3 = {a.x.start, a.y.start, a.z.start}
    eee : Vector3 = {a.x.end, a.y.end, a.z.end}

    ses : Vector3 = {a.x.start, a.y.end, a.z.start}
    ess : Vector3 = {a.x.end, a.y.start, a.z.start}
    sse : Vector3 = {a.x.start, a.y.start, a.z.end}

    see : Vector3 = {a.x.start, a.y.end, a.z.end}
    ese : Vector3 = {a.x.end, a.y.start, a.z.end}
    ees : Vector3 = {a.x.end, a.y.end, a.z.start}

    DrawLineForAABB(sss, ses)
    DrawLineForAABB(sss, ess)
    DrawLineForAABB(sss, sse)

    DrawLineForAABB(eee, ees)
    DrawLineForAABB(eee, ese)
    DrawLineForAABB(eee, see)

    DrawLineForAABB(ese, sse)
    DrawLineForAABB(ese, ess)

    DrawLineForAABB(ses, see)
    DrawLineForAABB(ses, ees)

    DrawLineForAABB(see, sse)
    DrawLineForAABB(ees, ess)
}

DrawBVH :: proc(node : ^BVH_node) {
    if node == nil do return

    DrawBBox(node.bbox)
    DrawBVH(node.left)
    DrawBVH(node.right)
}

DrawLineForAABB :: proc(point_a, point_b : Vector3) {
    proj := matrix[4, 4]f32 {
		cam.w * 0.5,        0,            0,                  0,
		0,            cam.h * 0.5,        0,                  0,
		0,            0,             -SDL.sqrtf(cam.focus_distance),    0,
		-cam.origin.x, -cam.origin.y, cam.origin.z + cam.focus_distance, 1
	}

	proj = Rotate_y_proj(cam.angle_y, proj)
	proj = Rotate_x_proj(cam.angle_x, proj)

	world_cam_m := linalg.matrix4_inverse(proj)

	proj_x : Vector3 = ConvertFromProj(ConvertToProj(point_a) * proj)
    proj_y : Vector3 = ConvertFromProj(ConvertToProj(point_b) * proj)
	NDC_start := ConvertToNDC({proj_x.x / proj_x.z, proj_x.y / proj_x.z})
	NDC_end := ConvertToNDC({proj_y.x / proj_y.z, proj_y.y / proj_y.z})

    s := ConvertNDCToRaster(NDC_end)
    e := ConvertNDCToRaster(NDC_start)
    SDL.SetRenderDrawColor(renderer, 255, 0, 0, 255)
    SDL.RenderDrawLine(renderer, e.x, e.y, s.x, s.y)
}

SphereIntersection :: proc(sphere : Sphere, ray : Ray) -> (intersected : bool, res : f32) {
    s_c : Vector3 = sphere.center if !sphere.isMoving else SphereCenter(ray.time, sphere)
	L : Vector3 = s_c - ray.origin;
	a : f32 = linalg.dot(ray.direction, ray.direction)
	b : f32 = linalg.dot(ray.direction, L)
	c : f32 = linalg.dot(L, L) - sphere.r * sphere.r
	discr := b * b - a * c
    root := (b - M.sqrt_f32(discr)) / a
	if discr < 0 || root < 0 do return false, 0
	else do return true, root
}

ClosestHit :: proc(ray : Ray) -> (hit : HitInfo) {
    _ = HitNode(&root_node, ray, {-999, 99999}, &hit)
    return
}
Trace :: proc(ray_ : Ray, depth : i32) -> color {
    if depth > MAX_BOUNCE do return {0, 0, 0, 1}

    hit := ClosestHit(ray_)
    if hit.did_hit {
        ray : Ray
        ray.time = ray_.time
        intersection := ray_.origin + hit.intersection * ray_.direction
        if hit.mtl.type == METAL {
            ray = Reflect(ray_, hit.normal, intersection)
            ray.direction = linalg.vector_normalize(ray.direction + RandomUnitVector() * hit.mtl.fuzz)
            if linalg.dot(hit.normal, ray.direction) < 0 do return {0, 0, 0, 1}
        }

        if hit.mtl.type == LAMBERTARIAN {
            ray = RandomReflect(ray_, hit.normal, intersection)
            scale : f32 = 5
            x, y, z : i32 = i32(linalg.floor(intersection.x * scale)), i32(linalg.floor(intersection.y * scale)), i32(linalg.floor(intersection.z * scale))
            coords : bool = (x + y + z) % 2 == 0
            if coords do hit.mtl.diffuze = {.1, .1, .1, 0}
            else do hit.mtl.diffuze = {.3, .3, .3, 0}
        }

        if hit.mtl.type == DIELECTRIC {
            kr := Fresnel(ray_.direction, hit.normal, hit.mtl.IOR)
            refr, refl : color
            if kr < 1 { 
                refr_ray : Ray = Refract(ray_.direction, hit.normal, intersection, hit.mtl.IOR)
                refr = Trace(refr_ray, depth + 1)
            }
            refl_ray : Ray = Reflect(ray_, hit.normal, intersection)
            refl = Trace(refl_ray, depth + 1)
            return (refl * kr + refr * (1 - kr))
        }
        return Trace(ray, depth + 1) * hit.mtl.diffuze
    }
    return BG_shader(ray_)
}

RayThrower :: proc(t : ^thread.Thread) {
    x_S := BUCKET_SIZE * (i32(t.user_index) % SIDE)
    x_E := BUCKET_SIZE * (i32(t.user_index) % SIDE + 1)
    y_S := BUCKET_SIZE * (i32(t.user_index) / SIDE) + 1
    y_E := BUCKET_SIZE * (i32(t.user_index) / SIDE + 1)
    y_loop : for j in y_S..=y_E {
        x_loop : for i in x_S..<x_E {
            v : Vector2 = SampleVector({f32(i), f32(j)})
            x, y := v.x * cam.delta_u - cam.w * 0.5, v.y * cam.delta_v - cam.h * 0.5 / ASPECT
            ray : Ray = {
                direction = ({x, y, - cam.focus_distance}),
                origin = cam.origin
            }
            offset := RandomOnDisk() * cam.defocus_disk
            ray.origin.xy += offset
            ray.direction.xy -= offset
            ray.direction = linalg.vector_normalize(ray.direction)
            ray.direction = RotateCam(cam, ray.direction)
            ray.time = rnd.float32()
            frame[i][WINDOW_H - j] += Trace(ray, 0)
        }
    }

}

MultitheadRayThrower :: proc(threadPool : ^[dynamic]^thread.Thread) {
    for i in 0..<THREADS {
        thr := thread.create(RayThrower)
            if thr != nil {
            thr.init_context = context
            thr.user_index = i

            append(threadPool, thr)

            thread.start(thr)
        }
    }
    for len(threadPool) > 0 {
        for i := 0; i < len(threadPool); {
            t := threadPool[i]
            if thread.is_done(t) {
                thread.destroy(t)
                ordered_remove(threadPool, i)
            } else {
                i += 1
            }
        }
    }
}

main :: proc() {
    {
        cam = {
            origin = {0, 0, 11},
            focus_distance = 17.63,
            fl = 35,
            angle_y = DegToRad(0),
            angle_x = DegToRad(0),
            samples = 256,
            apperture = 8
        }

        cam.w = 2 * M.tan_f32(DegToRad(cam.fl * 0.5)) * cam.focus_distance
        cam.h = 2 * M.tan_f32(DegToRad(cam.fl * 0.5)) * cam.focus_distance

        cam.defocus_disk = { 
            0.1,
            0.1
        }

        cam.delta_u = cam.w / f32(WINDOW_W)
        cam.delta_v = cam.w / f32(WINDOW_H) / ASPECT

        cam.pixel_samples_scale = 1 / f32(cam.samples)
        SDL.Init(SDL.INIT_EVERYTHING)
        window = SDL.CreateWindow(WINDOW_TITLE, WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H, WINDOW_FLAGS)
        renderer = SDL.CreateRenderer(
            window,
            -1,
            SDL.RENDERER_PRESENTVSYNC | SDL.RENDERER_ACCELERATED | SDL.RENDERER_TARGETTEXTURE
        )
        }
        defer { 
            SDL.DestroyWindow(window)
            SDL.Quit()
        }
        // side_spheres := i32(linalg.sqrt(f32(SPHERE_COUNT - 1)))
        // prev_r_x : f32 = -10
        // prev_c_x : f32 = -10

        // prev_r_z : f32 = -100
        // prev_c_z : f32 = -100
        // for i in 0..<side_spheres {
        //     for j in 0..<side_spheres {
        //         spheres[i * side_spheres + j] = {
        //             r = rnd.float32_range(0.25, 3),
        //             mtl = {
        //                 fuzz = clamp(rnd.float32_range(-1, 1), 0, 1),
        //                 type = u8(rnd.uint32() % 3),
        //                 IOR = 1.5
        //             }
        //         }

        //         if spheres[i * side_spheres + j].mtl.type == DIELECTRIC do spheres[i * side_spheres + j].mtl.diffuze = {1, 1, 1, 1}
        //         else do spheres[i * side_spheres + j].mtl.diffuze = {rnd.float32(), rnd.float32(), rnd.float32(), 1}
                
        //         if i != 0 {
        //             prev_c_z = spheres[(i - 1) * side_spheres + j].center.z
        //             prev_r_z = spheres[(i - 1) * side_spheres + j].r
        //         }
        //         if j != 0 {
        //             prev_c_x = spheres[i * side_spheres + (j - 1)].center.x
        //             prev_r_x = spheres[i * side_spheres + (j - 1)].r
        //         }
        //         delta : f32 = rnd.float32_range(-2, 2) + 6
        //         spheres[i * side_spheres + j].center = {
        //             (prev_r_x + prev_c_x) + spheres[i * side_spheres + j].r + delta,
        //             -1 + spheres[i * side_spheres + j].r,
        //             -((prev_r_z - prev_c_z) + spheres[i * side_spheres + j].r + delta)
        //         }
        //         spheres[i * side_spheres + j].bbox = CreateAABB(
        //             spheres[i * side_spheres + j].center - spheres[i * side_spheres + j].r,
        //             spheres[i * side_spheres + j].center + spheres[i * side_spheres + j].r
        //         )
        //     }
        //     prev_c_x = -10
        //     prev_r_x = -10
        // }
        // spheres[SPHERE_COUNT - 1] = {
        //     center = {0, -5001, -7},
        //     r = 5000,
        //     mtl = {diffuze = {0.1, 0.1, 0.1, 1}, fuzz = 1, type = LAMBERTARIAN, IOR = 1.5},
        // }
        // spheres[SPHERE_COUNT - 1].bbox = CreateAABB(
        //     spheres[SPHERE_COUNT - 1].center - spheres[SPHERE_COUNT - 1].r,
        //     spheres[SPHERE_COUNT - 1].center + spheres[SPHERE_COUNT - 1].r
        // )
        // spheres[0] = {
        //     center = {0, -0.5, -7},
        //     r = 0.5,
        //     mtl = {diffuze = {0, 0, 0, 1}, fuzz = 1, type = DIELECTRIC, IOR = 1.5}
        // }
        // spheres[0].bbox = CreateAABB(
        //     spheres[0].center - spheres[0].r,
        //     spheres[0].center + spheres[0].r
        // )
        // spheres[1] = {
        //     center = {-1, -0.75, -5},
        //     r = 0.25,
        //     mtl = {diffuze = {1, 0, 0, 1}, fuzz = 0, type = LAMBERTARIAN},
        //     isMoving = false,
        //     // center1 = {-1, -0.75, -5},
        //     // center2 = {-1, -0.5, -5}
        // }
        // spheres[1].bbox = CreateAABB(
        //     spheres[1].center - spheres[1].r,
        //     spheres[1].center + spheres[1].r
        // )
        // // spheres[2].center = spheres[2].center2 - spheres[2].center1
        // spheres[2] = {
        //     center = {2, 0, -9},
        //     r = 1,
        //     mtl = {diffuze = {0.8, 0.6, 0.2, 1}, fuzz = 0, type = METAL}
        // }
        // spheres[2].bbox = CreateAABB(
        //     spheres[2].center - spheres[2].r,
        //     spheres[2].center + spheres[2].r
        // )
        SplitNodes(&root_node, 0, sphere_count)
        defer { DeleteNode(&root_node) }
        // for i in 0..<SPHERE_COUNT {
        //     root_node.bbox = CreateAABB(root_node.bbox, spheres[i].bbox)
        // }
    // DrawAxis(renderer, {0, 0, 1}, cam)
    // DrawAxis(renderer, {0, 1, 0}, cam)
    // DrawAxis(renderer, {1, 0, 0}, cam)
    SDL.RenderPresent(renderer)
	event : SDL.Event = ---
	rotate : bool = false
	start_x : f32 = ---
	start_y : f32 = ---
	rendering : = false
    samples : i32 = 1
    moved := false
    fps : f32 = 0
    threadPool := make([dynamic]^thread.Thread, 0, THREADS)
    defer delete(threadPool)
    looooop : for {
        if samples != cam.samples {
            start_time := SDL.GetTicks()
            MultitheadRayThrower(&threadPool)
            for i in 0..=WINDOW_W {
                for j in 0..=WINDOW_H {
                    c : color = {
                        clamp(LinearToGamma(frame[i][j].r / f32(samples)), 0, 1),
                        clamp(LinearToGamma(frame[i][j].g / f32(samples)), 0, 1),
                        clamp(LinearToGamma(frame[i][j].b / f32(samples)), 0, 1),
                        1
                    }
                    SDL.SetRenderDrawColor(renderer, expand(c))
                    SDL.RenderDrawPoint(
                        renderer,
                        i32(i),
                        i32(j)
                    )
                }
            }
            samples += 1
            ProgressBar(samples)
            SDL.RenderPresent(renderer)
            fps += 1000.0 / f32(SDL.GetTicks() - start_time)
            fmt.println("fps:", 1000.0 / f32(SDL.GetTicks() - start_time), "avg:", fps / f32(samples - 1))
    }
    //     DrawAxis(renderer, {0, 0, 1}, cam)
    //     DrawAxis(renderer, {0, 1, 0}, cam)
    //     DrawAxis(renderer, {1, 0, 0}, cam)
        // for i in 0..<SPHERE_COUNT {
        //     DrawBBox(spheres[i].bbox)
        // }
        // DrawBVH(&root_node)
        SDL.RenderPresent(renderer)
		for SDL.PollEvent(&event) {
			#partial switch event.type {
				case SDL.EventType.QUIT:
					break looooop
                    
                case SDL.EventType.MOUSEBUTTONDOWN:
                    if event.button.button == SDL.BUTTON_LEFT do rotate = true
                    if event.button.button == SDL.BUTTON_MIDDLE {
                        ChangeFocalDistance(event.button.x, event.button.y)
                        // fmt.println(cam.focus_distance)
                        moved = true
                    }
                    start_x = (f32(event.button.x) / f32(WINDOW_W) * 2 - 1)
                    start_y = (f32(event.button.y) / f32(WINDOW_H) * 2 - 1) / ASPECT
                    
                case SDL.EventType.MOUSEMOTION:
                    if rotate {
                        current_x, current_y := ConvertScreenToWorld({f32(event.motion.x), f32(event.motion.y)})

                        cam.angle_y += M.atan2_f32(f32(current_x - start_x), cam.focus_distance)
                        cam.angle_x += M.atan2_f32(f32(current_y - start_y), cam.focus_distance)
                        moved = true
                    }
                case SDL.EventType.MOUSEBUTTONUP:
                    if event.button.button == SDL.BUTTON_LEFT do rotate = false

                case SDL.EventType.MOUSEWHEEL:
                    ChangeFl(f32(event.wheel.y * 2))
                    moved = true

                case SDL.EventType.KEYDOWN:
                    #partial switch event.key.keysym.sym {
                        case SDL.Keycode.w:
                            move_direction : Vector3 = {0, 0, 0.5}
                            cam.origin -= RotateCam(cam, move_direction)
                            moved = true
                            break
                        case SDL.Keycode.s:
                            move_direction : Vector3 = {0, 0, 0.5}
                            cam.origin += RotateCam(cam, move_direction)
                            moved = true
                            break
                        case SDL.Keycode.a:
                            move_direction : Vector3 = {0.5, 0, 0}
                            cam.origin -= RotateCam(cam, move_direction)
                            moved = true
                            break
                        case SDL.Keycode.d:
                            move_direction : Vector3 = {0.5, 0, 0}
                            cam.origin += RotateCam(cam, move_direction)
                            moved = true
                            break
                        case SDL.Keycode.SPACE:
                            move_direction : Vector3 = {0, 0.5, 0}
                            cam.origin += RotateCam(cam, move_direction)
                            moved = true
                            break
                        case SDL.Keycode.LSHIFT:
                            move_direction : Vector3 = {0, 0.5, 0}
                            cam.origin -= RotateCam(cam, move_direction)
                            moved = true
                            break
                        case:
                    }
                    
				case: // default
			}
		}
        if moved {
            for i in 0..=WINDOW_W {
                for j in 0..=WINDOW_H {
                    frame[i][j] = 0
                }
            }
            samples = 1
            moved = false
            rendering = false
        }
	}
}