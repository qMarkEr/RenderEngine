package main

import "core:fmt"
import SDL "vendor:sdl2"
import M "core:math"
import "core:math/linalg"
import rnd "core:math/rand"
import "core:thread"
import "core:time"
import "core:sync"
import stb "vendor:stb/image"


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

	SDL.SetRenderDrawColor(renderer, u8(color_mult * x_end.x), u8(color_mult * x_end.y), u8(color_mult * x_end.z), color_mult)
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
    SDL.SetRenderDrawColor(renderer, color_mult, 0, 0, color_mult)
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
        c : color 
        if hit.mtl.diffuze.bytes == 0 && hit.mtl.diffuze2.gen == true do c = Marble(hit.mtl.diffuze2, hit.normal)
        else do c = GetPixel(hit.mtl.diffuze, hit.mtl.diffuze.w, hit.mtl.diffuze.h, hit.mtl.diffuze.bytes, hit.uv)
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
        }

        if hit.mtl.type == DIELECTRIC {
            kr := Fresnel(ray_.direction, hit.normal, hit.mtl.IOR)
            refr, refl : color
            if kr < 1 { 
                refr_ray : Ray = Refract(ray_.direction, hit.normal, intersection, hit.mtl.IOR)
                refr = Trace(refr_ray, depth + 1) * c
            }
            refl_ray : Ray = Reflect(ray_, hit.normal, intersection)
            refl = Trace(refl_ray, depth + 1)
            return (refl * kr + refr * (1 - kr))
        }
        if hit.mtl.type == EMISSIVE {
            return hit.mtl.diffuze.albedo
        }
        return Trace(ray, depth + 1) * c + hit.mtl.emission * hit.mtl.diffuze.albedo
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

    window = SDL.CreateWindow(WINDOW_TITLE, WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H, WINDOW_FLAGS)
    renderer = SDL.CreateRenderer(
        window,
        -1,
        SDL.RENDERER_PRESENTVSYNC | SDL.RENDERER_ACCELERATED | SDL.RENDERER_TARGETTEXTURE
    )
    SDL.SetHint(SDL.HINT_RENDER_SCALE_QUALITY, "0"); // Nearest neighbor filtering
    SDL.RenderSetLogicalSize(renderer, WINDOW_W, WINDOW_H);
    SDL.RenderSetIntegerScale(renderer, true);
    defer { 
        SDL.DestroyWindow(window)
        SDL.Quit()
    }

    cam = {
        origin = {0, 0, 0},
        focus_distance = 17.63,
        fl = 35,
        angle_y = DegToRad(0),
        angle_x = DegToRad(0),
        samples = 1024,
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
    
    SplitNodes(&root_node, 0, sphere_count)
    defer DeleteNode(&root_node) 

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
        // fmt.print("\033[H")
        if samples != cam.samples {
            start_time := SDL.GetTicks()
            MultitheadRayThrower(&threadPool)
            for i in 0..=WINDOW_H {
                for j in 0..=WINDOW_W {
                    c : color = {
                        clamp(LinearToGamma(frame[j][i].r / f32(samples)), 0, 1),
                        clamp(LinearToGamma(frame[j][i].g / f32(samples)), 0, 1),
                        clamp(LinearToGamma(frame[j][i].b / f32(samples)), 0, 1),
                        1
                    }
                    bw := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
                    // c.r = bw
                    // c.g = bw
                    // c.b = bw
                    // index : i32 = i32(linalg.floor((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * (color_mult - 2)))
                    // fmt.print(rune(grad[index]))
                    SDL.SetRenderDrawColor(renderer, expand(c))
                    SDL.RenderDrawPoint(
                        renderer,
                        i32(j),
                        i32(i)
                    )
                }
                // fmt.println()
            }
            samples += 1
            // ProgressBar(samples)
            SDL.RenderPresent(renderer)
            fps += 1000.0 / f32(SDL.GetTicks() - start_time)
            // break looooop
           fmt.println("fps:", 1000.0 / f32(SDL.GetTicks() - start_time), "avg:", fps / f32(samples - 1))
        }
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