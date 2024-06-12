package main

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

	if discr < 0 do return false, 0
	else do return true, (b - M.sqrt_f32(discr)) / a
}

Colorize :: proc(renderer : ^SDL.Renderer, mtl : Material, i, j : i32) {
	shaded_color : color = {
		clamp(mtl.diffuze.r, 0, 1),
		clamp(mtl.diffuze.g, 0, 1),
		clamp(mtl.diffuze.b, 0, 1),
		1
	}
	SDL.SetRenderDrawColor(renderer, expand(shaded_color))
	SDL.RenderDrawPoint(
		renderer,
		i,
		WINDOW_H - j
	)
}

SampleVector :: proc(vec : Vector2) -> Vector2 {
    sample_square : Vector2 = {
        rnd.float32() - 0.5,
        rnd.float32() - 0.5,
    }
    return vec + sample_square
}

RayThrower :: proc(renderer : ^SDL.Renderer, cam : Camera) {
    sp : Sphere = {
        center = {0, 0, -7},
        r = 1,
    }
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
                hit, t := SphereIntersection(sp, ray)
                if hit {
                    at := ray.origin + ray.direction * t
                    n : Vector3 = linalg.vector_normalize(at - sp.center)
                    mtl.diffuze += Intersection_Shader(n, i, j).diffuze
                } else do mtl.diffuze += BG_shader(ray, i, j).diffuze
            }
            mtl.diffuze *= cam.pixel_samples_scale
            Colorize(renderer, mtl, i, j)
        }
        SDL.RenderPresent(renderer)
    }
}

main :: proc() {
    cam : Camera = {
		origin = {0, 0, 0},
		fl = 1.0 / M.tan_f32(DegToRad(55) * 0.5),
		samples = 100,
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
    looooop : for {
        RayThrower(renderer, cam)
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