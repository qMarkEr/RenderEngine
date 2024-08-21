package main

import rnd "core:math/rand"
import "core:math/linalg"

BasicScene :: proc() -> (spheres : [4]Sphere) {
    spheres[3] = {
        center = {0, -5001, -7},
        r = 5000,
        mtl = {diffuze = {0.1, 0.1, 0.1, 1}, fuzz = 1, type = LAMBERTARIAN, IOR = 1.5},
    }
    spheres[3].bbox = CreateAABB(
        spheres[3].center - spheres[3].r,
        spheres[3].center + spheres[3].r
    )
    spheres[0] = {
        center = {0, -0.5, -7},
        r = 0.5,
        mtl = {diffuze = {0, 0, 0, 1}, fuzz = 1, type = DIELECTRIC, IOR = 1.5}
    }
    spheres[0].bbox = CreateAABB(
        spheres[0].center - spheres[0].r,
        spheres[0].center + spheres[0].r
    )
    spheres[1] = {
        center = {-1, -0.75, -5},
        r = 0.25,
        mtl = {diffuze = {1, 0, 0, 1}, fuzz = 0, type = LAMBERTARIAN},
        isMoving = false,
        // center1 = {-1, -0.75, -5},
        // center2 = {-1, -0.5, -5}
    }
    spheres[1].bbox = CreateAABB(
        spheres[1].center - spheres[1].r,
        spheres[1].center + spheres[1].r
    )
    // spheres[2].center = spheres[2].center2 - spheres[2].center1
    spheres[2] = {
        center = {2, 0, -9},
        r = 1,
        mtl = {diffuze = {0.8, 0.6, 0.2, 1}, fuzz = 0, type = METAL}
    }
    spheres[2].bbox = CreateAABB(
        spheres[2].center - spheres[2].r,
        spheres[2].center + spheres[2].r
    )
    return 
}

ALotOfSpheres :: proc() -> (spheres : [SPHERE_COUNT]Sphere) {
    side_spheres := i32(linalg.sqrt(f32(SPHERE_COUNT - 1)))
    prev_r_x : f32 = -10
    prev_c_x : f32 = -10

    prev_r_z : f32 = -100
    prev_c_z : f32 = -100
    for i in 0..<side_spheres {
        for j in 0..<side_spheres {
            spheres[i * side_spheres + j] = {
                r = rnd.float32_range(0.25, 3),
                mtl = {
                    fuzz = clamp(rnd.float32_range(-1, 1), 0, 1),
                    type = u8(rnd.uint32() % 3),
                    IOR = 1.5
                }
            }

            if spheres[i * side_spheres + j].mtl.type == DIELECTRIC do spheres[i * side_spheres + j].mtl.diffuze = {1, 1, 1, 1}
            else do spheres[i * side_spheres + j].mtl.diffuze = {rnd.float32(), rnd.float32(), rnd.float32(), 1}
            
            if i != 0 {
                prev_c_z = spheres[(i - 1) * side_spheres + j].center.z
                prev_r_z = spheres[(i - 1) * side_spheres + j].r
            }
            if j != 0 {
                prev_c_x = spheres[i * side_spheres + (j - 1)].center.x
                prev_r_x = spheres[i * side_spheres + (j - 1)].r
            }
            delta : f32 = rnd.float32_range(-2, 2) + 6
            spheres[i * side_spheres + j].center = {
                (prev_r_x + prev_c_x) + spheres[i * side_spheres + j].r + delta,
                -1 + spheres[i * side_spheres + j].r,
                -((prev_r_z - prev_c_z) + spheres[i * side_spheres + j].r + delta)
            }
            spheres[i * side_spheres + j].bbox = CreateAABB(
                spheres[i * side_spheres + j].center - spheres[i * side_spheres + j].r,
                spheres[i * side_spheres + j].center + spheres[i * side_spheres + j].r
            )
        }
        prev_c_x = -10
        prev_r_x = -10
    }
    spheres[SPHERE_COUNT - 1] = {
        center = {0, -5001, -7},
        r = 5000,
        mtl = {diffuze = {0.1, 0.1, 0.1, 1}, fuzz = 1, type = LAMBERTARIAN, IOR = 1.5},
    }
    spheres[SPHERE_COUNT - 1].bbox = CreateAABB(
        spheres[SPHERE_COUNT - 1].center - spheres[SPHERE_COUNT - 1].r,
        spheres[SPHERE_COUNT - 1].center + spheres[SPHERE_COUNT - 1].r
    )
    return
}