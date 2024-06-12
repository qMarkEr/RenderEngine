package main

import "core:fmt"
import SDL "vendor:sdl2"
import M "core:math"
import "core:math/linalg"
import rnd "core:math/rand"

SphereIntersection :: proc(sphere : Sphere, ray : Ray) -> (intersected : bool, res : f32) {
	L : Vector3 = sphere.center - ray.origin;
	a : f32 = 1
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
    if depth > MAX_BOUNCE {
        m : Material = {diffuze = {0, 0, 0, 1}}
        return m
    }

    hit := ClosestHit(spheres, ray_)
    if hit.did_hit {
        ray : Ray
        if hit.mtl.type == METAL do ray = Reflect(ray_, hit.normal, hit.intersection)
        if hit.mtl.type == LAMBERTARIAN do ray = RandomReflect(ray_, hit.normal, hit.intersection)
        mtl := Trace(ray, spheres, depth + 1)
        mtl.diffuze *= hit.mtl.diffuze
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
                mtl.diffuze += Trace(ray, spheres, 0).diffuze
            }
            mtl.diffuze *= cam.pixel_samples_scale
            Colorize(renderer, mtl, i, j)
        }
        fmt.print("\033[H")
        fmt.println("Render progress:", M.round(f32(j) / f32(WINDOW_H) * 100.0), "/ 100%", )
    }
}

main :: proc() {
    cam : Camera = {
		origin = {0, 0, 0},
		fl = 1.0 / M.tan_f32(DegToRad(55) * 0.5),
		samples = 128,
	}
    spheres : [SPHERE_COUNT]Sphere
    spheres[0] = {
        center = {-1.1, 0, -7},
        r = 1,
        mtl = {diffuze = {0.3, 0.3, 0.3, 1}, emissive = 0, type = METAL}
        
    }
    spheres[1] = {
        center = {1, 0, -7},
        r = 1,
        mtl = {diffuze = {1, 0, 1, 1}, emissive = 0, type = LAMBERTARIAN}
        
    }
    spheres[2] = {
        center = {0, -101, -7},
        r = 100,
        mtl = {diffuze = {0, 1, 0, 1}, emissive = 0, type = LAMBERTARIAN}
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
    rendered := false
    looooop : for {
        if !rendered{
            RayThrower(renderer, cam, spheres)
            fmt.print("\033[H")
            rendered = true
        }
        SDL.RenderPresent(renderer)
		for SDL.PollEvent(&event) {
			#partial switch event.type {
				case SDL.EventType.QUIT:
					break looooop
				case: // default
			}
		}
	}
}