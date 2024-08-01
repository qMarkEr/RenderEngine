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
spheres : [SPHERE_COUNT]Sphere
window : ^SDL.Window
renderer : ^SDL.Renderer
frame : [WINDOW_W + 1][WINDOW_H + 1]color

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

SphereIntersection :: proc(sphere : Sphere, ray : Ray) -> (intersected : bool, res : f32) {
	L : Vector3 = sphere.center - ray.origin;
	a : f32 = linalg.dot(ray.direction, ray.direction)
	b : f32 = linalg.dot(ray.direction, L)
	c : f32 = linalg.dot(L, L) - sphere.r * sphere.r
	discr := b * b - a * c
    root := (b - M.sqrt_f32(discr)) / a
	if discr < 0 || root < 0 do return false, 0
	else do return true, root
}

ClosestHit :: proc(objs : [SPHERE_COUNT]Sphere, ray : Ray) -> (hit : HitInfo) {
    max_mul : f32 = 10000
    for obj in objs {
        did_hit, mul := SphereIntersection(obj, ray)
        if did_hit {
            if mul < max_mul {
                hit.did_hit = did_hit
                hit.intersection = ray.origin + mul * ray.direction
                hit.normal = linalg.vector_normalize(hit.intersection - obj.center)
                hit.mtl = obj.mtl
                max_mul = mul
            }
        }
    }
    return
}

Trace :: proc(ray_ : Ray, spheres : [SPHERE_COUNT]Sphere, depth : i32) -> color {
    if depth > MAX_BOUNCE do return {0, 0, 0, 1}

    hit := ClosestHit(spheres, ray_)
    if hit.did_hit {
        ray : Ray
        if hit.mtl.type == METAL {
            ray = Reflect(ray_, hit.normal, hit.intersection)
            ray.direction = linalg.vector_normalize(ray.direction + RandomUnitVector() * hit.mtl.fuzz)
            if linalg.dot(hit.normal, ray.direction) < 0 do return {0, 0, 0, 1}
        }

        if hit.mtl.type == LAMBERTARIAN do ray = RandomReflect(ray_, hit.normal, hit.intersection)

        if hit.mtl.type == DIELECTRIC {
            kr := Fresnel(ray_.direction, hit.normal, hit.mtl.IOR)
            refr, refl : color
            if kr < 1 { 
                refr_ray : Ray = Refract(ray_.direction, hit.normal, hit.intersection, hit.mtl.IOR)
                refr = Trace(refr_ray, spheres, depth + 1)
            }
            refl_ray : Ray = Reflect(ray_, hit.normal, hit.intersection)
            refl = Trace(refl_ray, spheres, depth + 1)
            return (refl * kr + refr * (1 - kr)) 
        }
        return Trace(ray, spheres, depth + 1) * hit.mtl.diffuze
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
            
            frame[i][WINDOW_H - j] += Trace(ray, spheres, 0)
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
            origin = {-1, 2, 0},
            focus_distance = 7.34,
            fl = 35,
            angle_y = DegToRad(10),
            angle_x = DegToRad(20),
            samples = 256,
            apperture = 8
        }

        cam.w = 2 * M.tan_f32(DegToRad(cam.fl * 0.5)) * cam.focus_distance
        cam.h = 2 * M.tan_f32(DegToRad(cam.fl * 0.5)) * cam.focus_distance

        cam.defocus_disk = { 
            0.02,
            0.02
        }

        cam.delta_u = cam.w / f32(WINDOW_W)
        cam.delta_v = cam.w / f32(WINDOW_H) / ASPECT

        // spheres : [SPHERE_COUNT]Sphere
        spheres[0] = {
            center = {0, -101, -7},
            r = 100,
            mtl = {diffuze = {0.1, 0.1, 0.1, 1}, fuzz = 1, type = LAMBERTARIAN, IOR = 1.5}
        }
        spheres[1] = {
            center = {0, -0.5, -7},
            r = 0.5,
            mtl = {diffuze = {0, 0, 0, 1}, fuzz = 1, type = DIELECTRIC, IOR = 1.5}
        }
        spheres[2] = {
            center = {-1, -0.75, -5},
            r = 0.25,
            mtl = {diffuze = {1, 0, 0, 1}, fuzz = 0, type = LAMBERTARIAN}
        }
        spheres[3] = {
            center = {2, 0, -9},
            r = 1,
            mtl = {diffuze = {0.8, 0.6, 0.2, 1}, fuzz = 0, type = METAL}
        }
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
	event : SDL.Event = ---
	rotate : bool = false
	start_x : f32 = ---
	start_y : f32 = ---
	rendered : = false
    samples : i32 = 1
    moved := false

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
            // fmt.println(SDL.GetTicks() - start_time)
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
                        moved = true
                    }
                    start_x = (f32(event.button.x) / f32(WINDOW_W) * 2 - 1)
                    start_y = (f32(event.button.y) / f32(WINDOW_H) * 2 - 1) / ASPECT
                    
                case SDL.EventType.MOUSEMOTION:
                    if rotate {
                        current_x, current_y := ConvertScreenToWorld({f32(event.motion.x), f32(event.motion.y)})

                        cam.angle_y += M.atan2_f32(f32(current_x - start_x), cam.focus_distance)
                        cam.angle_x += M.atan2_f32(f32(current_y - start_y), cam.focus_distance)
                        rendered = false
                        moved = true
                    }
                case SDL.EventType.MOUSEBUTTONUP:
                    if event.button.button == SDL.BUTTON_LEFT do rotate = false

                case SDL.EventType.MOUSEWHEEL:
                    ChangeFl(f32(event.wheel.y * 2))
                    fmt.println(cam.fl)
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
        }
	}
}