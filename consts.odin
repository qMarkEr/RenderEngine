package main

import SDL "vendor:sdl2"
import "core:os"

BG_COLOR_TOP : int = 0xEE964B //  0x000000
FG_COLOR_1 : int = 0x75DDDD
FG_COLOR_2 : int = 0x508991
FG_COLOR_3 : int = 0x172A3A
BG_COLOR_BOTTOM : int =  0xF95738 //0x423E37 

SPHERE_COUNT :: 4

space_color_top : color = hex_to_rgba(0x75DDDD)
space_color_bottom : color = hex_to_rgba(0xFFFFFF)

WINDOW_TITLE :: "backrooms"
WINDOW_X : i32 = SDL.WINDOWPOS_CENTERED
WINDOW_Y : i32 = SDL.WINDOWPOS_CENTERED

WINDOW_W : i32 : 720
WINDOW_H : i32 : 720
BUCKET_SIZE :: WINDOW_W / SIDE
SIDE :: 10
ASPECT : f32 : f32(WINDOW_W) / f32(WINDOW_H)

WINDOW_FLAGS  :: SDL.WINDOW_SHOWN

SHADOW_BIAS :: 0.0001
AXIS_OFFSET :: 0.35
AXIS_LENGTH :: 10
MAX_BOUNCE :: 50
THREADS := SIDE * SIDE //os.processor_core_count()
LAMBERTARIAN :: 0
METAL :: 1
DIELECTRIC :: 2

vup : Vector3 : {0, 1, 0}