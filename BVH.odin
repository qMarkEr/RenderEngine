package main

import "core:math/linalg"

HitNode :: proc(node : ^BVH_node, r : Ray, i : Interval, h : ^HitInfo) -> bool {
    if node.obj_index != -1 {
        did_hit, mul := SphereIntersection(spheres[node.obj_index], r)
        if did_hit && mul < i.end {
            h.did_hit = true
            h.intersection = mul
            isect := r.origin + h.intersection * r.direction
            h.normal = linalg.vector_normalize(isect - spheres[node.obj_index].center)
            h.mtl = spheres[node.obj_index].mtl
            h.uv = SphereUV(spheres[node.obj_index], h.normal)
        }
        return did_hit
    }
    
    if !HitAABB(node.bbox, r, i) do return false
    
    l := HitNode(node.left, r, i, h)
    r := HitNode(node.right, r, {i.start, l ? h.intersection : i.end}, h)

    return l || r
}

DeleteNode :: proc(node : ^BVH_node) {
    if node.obj_index != -1 do free(node)
    if node.left != nil do DeleteNode(node.left)
    if node.right != nil do DeleteNode(node.right)
}


SplitNodes :: proc(root : ^BVH_node, s, e : i32) {
    root.bbox = spheres[s].bbox
    for i in s..<e {
        root.bbox = CreateAABB(root.bbox, spheres[i].bbox)
    }
    span := e - s
    root.obj_index = -1
    if span == 1 {
        root.obj_index = s
        root.left = nil
        root.right = nil
    } else if span == 2 {

        root.left = new(BVH_node)
        root.left.obj_index = s
        root.left.bbox = spheres[s].bbox

        root.right = new(BVH_node)
        root.right.obj_index = s + 1
        root.right.bbox = spheres[s + 1].bbox

    } else {
        axis := LongestAxis(root.bbox)
        SortElements(s, e - 1, axis)
        mid := s + span / 2
        root.left = new(BVH_node)
        root.right = new(BVH_node)
        SplitNodes(root.left, s, mid)
        SplitNodes(root.right, mid, e)
    }
}

LongestAxis :: proc(a : AABB) -> (index : i32) {
    len_x := abs(a.x.end - a.x.start)
    len_y := abs(a.y.end - a.y.start)
    len_z := abs(a.z.end - a.z.start)
    if len_x > len_y do return 0 if len_x > len_z else 2
    else do return 1 if len_y > len_z else 2
}

SortElements :: proc(s, e, axis : i32) {
    if s < e {
        pi := Partition(s, e, axis);
        SortElements(s, pi - 1, axis);
        SortElements(pi + 1, e, axis);
    }
}

Partition :: proc(s, e, axis : i32) -> i32 {
      pivot := spheres[e];
      i := s - 1;
      for j in s..<e {
          if spheres[j].bbox[axis].start < pivot.bbox[axis].start {
              i += 1;
              spheres[i], spheres[j] = spheres[j], spheres[i]
          }
      }
      spheres[i + 1], spheres[e] = spheres[e], spheres[i + 1]
      return i + 1
}