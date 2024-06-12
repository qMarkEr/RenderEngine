package main

import "core:fmt"
import SDL "vendor:sdl2"
import M "core:math"
import "core:math/linalg"
import rnd "core:math/rand"

SphereIntersection :: proc(sphere : Sphere, ray : Ray) -> (intersected : bool, res : f32) {
	L : Vector3 = sphere.center - ray.origin;
	a : f32 = linalg.dot(ray.direction, ray.direction)
	b : f32 = linalg.dot(ray.direction, L)
	c : f32 = linalg.dot(L, L) - sphere.r * sphere.r;
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

Trace :: proc(ray_ : Ray, spheres : [SPHERE_COUNT]Sphere, depth : i32) -> (Material) {
    black : Material : {diffuze = {0, 0, 0, 1}}
    if depth > MAX_BOUNCE do return black

    hit := ClosestHit(spheres, ray_)
    if hit.did_hit {
        ray : Ray
        if hit.mtl.type == METAL {
            ray = Reflect(ray_, hit.normal, hit.intersection)
            ray.direction = linalg.vector_normalize(ray.direction + RandomUnitVector() * hit.mtl.fuzz)
            if linalg.dot(hit.normal, ray.direction) < 0 do return black
        }
        if hit.mtl.type == LAMBERTARIAN do ray = RandomReflect(ray_, hit.normal, hit.intersection)
        mtl := Trace(ray, spheres, depth + 1)
        mtl.diffuze *= hit.mtl.diffuze * 0.8
        return mtl
    }
    return BG_shader(ray_)
}

RayThrower :: proc(renderer : ^SDL.Renderer, cam : Camera, spheres : [SPHERE_COUNT]Sphere) {
    y_loop : for j in 1..=WINDOW_H {
        x_loop : for i in 0..<WINDOW_W {
            mtl : Material
            antialias : for _ in 0..<cam.samples {
                v : Vector2 = SampleVector({f32(i), f32(j)})
                x, y := ConvertScreenToWorld(v)
                ray : Ray = {
                    direction = {x, y, -cam.fl},
                    origin = cam.origin
                }
                ray.direction = linalg.vector_normalize(ray.direction)
                ray.direction = RotateCam(cam, ray.direction)
                mtl.diffuze += Trace(ray, spheres, 0).diffuze
            }
            mtl.diffuze *= cam.pixel_samples_scale
            Colorize(renderer, mtl, i, j)
            }
        SDL.RenderPresent(renderer)
        // fmt.print("\033[H")
        // fmt.println("Render progress:", M.round(f32(j) / f32(WINDOW_H) * 100.0), "/ 100%", )
    }
}

main :: proc() {
    cam : Camera = {
		origin = {0, 0, 0},
		fl = 1.0 / M.tan_f32(DegToRad(54.9) * 0.5),
		samples = 128,
	}
    spheres : [SPHERE_COUNT]Sphere
    spheres[0] = {
        center = {0, -101, -7},
        r = 100,
        mtl = {diffuze = {0, 1, 1, 1}, fuzz = 1, type = LAMBERTARIAN}
    }
    spheres[1] = {
        center = {0, -0.5, -7},
        r = 0.5,
        mtl = {diffuze = {1, 0, 0, 1}, fuzz = 1, type = LAMBERTARIAN}
        
    }
    spheres[2] = {
        center = {-1, -0.75, -5},
        r = 0.25,
        mtl = {diffuze = {0, 1, 0, 1}, fuzz = 0, type = METAL}
    }
    spheres[3] = {
        center = {2, 0, -9},
        r = 1,
        mtl = {diffuze = {0, 0, 1, 1}, fuzz = 0.4, type = METAL}   
    }
    cam.pixel_samples_scale = 1 / f32(cam.samples)
    SDL.Init(SDL.INIT_EVERYTHING)
    window := SDL.CreateWindow(WINDOW_TITLE, WINDOW_X, WINDOW_Y, WINDOW_W, WINDOW_H, WINDOW_FLAGS)
    renderer := SDL.CreateRenderer(
    	window,
    	-1,
    	SDL.RENDERER_PRESENTVSYNC | SDL.RENDERER_ACCELERATED | SDL.RENDERER_TARGETTEXTURE
	)

	defer { 
		SDL.DestroyWindow(window)
		SDL.Quit()
	}
	event : SDL.Event = ---
	rotate : bool = false
	start_x : f32 = ---
	start_y : f32 = ---
	rendered : = false
    looooop : for {
        if !rendered{
            RayThrower(renderer, cam, spheres)
            rendered = true
        }
        SDL.RenderPresent(renderer)
		for SDL.PollEvent(&event) {
			#partial switch event.type {
				case SDL.EventType.QUIT:
					break looooop

                    case SDL.EventType.MOUSEBUTTONDOWN:
                        if event.button.button == SDL.BUTTON_LEFT do rotate = true
                        start_x = (f32(event.button.x) / f32(WINDOW_W) * 2 - 1)
                        start_y = (f32(event.button.y) / f32(WINDOW_H) * 2 - 1) / ASPECT
                        
                    case SDL.EventType.MOUSEMOTION:
                        if rotate {
                            current_x, current_y := ConvertScreenToWorld({f32(event.motion.x), f32(event.motion.y)})
    
                            cam.angle_y = M.atan2_f32(f32(current_x - start_x), cam.fl)
                            cam.angle_x = M.atan2_f32(f32(current_y - start_y), cam.fl)
                            SDL.SetRenderDrawColor(renderer, 0, 0, 0, 255)
                            SDL.RenderClear(renderer)
                            rendered = false
                        }
                    case SDL.EventType.MOUSEBUTTONUP:
                        if event.button.button == SDL.BUTTON_LEFT do rotate = false

                
				case: // default
			}
		}
	}
}