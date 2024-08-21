package main


ExpandInterval :: proc(i : Interval, delta : f32) -> Interval {
    pad := delta / 2.0
    return {i.start - pad, i.end + pad}
}

Overlaps :: proc(a, b : Interval) -> bool {
    return true
}

AABBFromPoints :: proc(a, b : Vector3) -> (res : AABB) {
    res.x = { a.x, b.x } if a.x > b.x else { b.x, a.x }
    res.y = { a.y, b.y } if a.y > b.y else { b.y, a.y }
    res.z = { a.z, b.z } if a.z > b.z else { b.z, a.z }
    return
}

AABBFromAABB :: proc(a, b : AABB) -> (res : AABB) {
    res.x = CreateInterval(a.x, b.x)
    res.y = CreateInterval(a.y, b.y)
    res.z = CreateInterval(a.z, b.z)
    return
}

CreateAABB :: proc{AABBFromPoints, AABBFromAABB}

CreateInterval :: proc(a, b : Interval) -> (res : Interval) {
    res.start = a.start if a.start > b.start else b.start
    res.end = a.end if a.end < b.end else b.end
    return
}

HitAABB :: proc(aabb: AABB, r : Ray, ray_t : Interval) -> bool {
    i := ray_t
    for axis in 0..<3 {
        ax := aabb[axis]
        adinv := 1.0 / r.direction[axis]

        t0, t1 := (ax.start - r.origin[axis]) * adinv, (ax.end - r.origin[axis]) * adinv

        if t0 < t1 {
            if t0 > i.start do i.start = t0
            if t1 < i.end do i.end = t1
        } else {
            if t1 > i.start do i.start = t1
            if t0 < i.end do i.end = t0
        }
        if i.end <= i.start do return false
    }
    return true
}