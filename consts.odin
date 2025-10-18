package main

import SDL "vendor:sdl2"
import "core:os"

BG_COLOR_TOP : int = 0xEE964B //  0x000000
FG_COLOR_1 : int = 0x75DDDD
FG_COLOR_2 : int = 0x508991
FG_COLOR_3 : int = 0x172A3A
BG_COLOR_BOTTOM : int =  0xF95738 //0x423E37 

SPHERE_COUNT :: 37

grad := ".'`^\",:;Il!i><~+_-?][}{1)(|tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"

color_mult :: 255
space_color_top : color = {0.7, 0.2, 0.1, 1} // hex_to_rgba(0x75DDDD)
space_color_bottom : color = {0.1, 0.1, 0.1, 1} //  hex_to_rgba(0xFFFFFF)

WINDOW_TITLE :: "backrooms"
WINDOW_X : i32 = SDL.WINDOWPOS_CENTERED
WINDOW_Y : i32 = SDL.WINDOWPOS_CENTERED

WINDOW_W : i32 : 640
WINDOW_H : i32 : 640
BUCKET_SIZE :: WINDOW_W / SIDE
SIDE :: 16
ASPECT : f32 : f32(WINDOW_W) / f32(WINDOW_H) //* 0.6

WINDOW_FLAGS  :: SDL.WINDOW_SHOWN

SHADOW_BIAS :: 0.0001
AXIS_OFFSET :: 0.35
AXIS_LENGTH :: 10
MAX_BOUNCE : i32 = 4
THREADS := SIDE * SIDE //os.processor_core_count()
LAMBERTARIAN :: 0
METAL :: 1
DIELECTRIC :: 2
EMISSIVE :: 3

vup : Vector3 : {0, 1, 0}

MARS :: "C:\\Users\\marker_\\Documents\\Projects\\RenderEngine\\assets\\mars.jpg"
MILKYWAY :: "C:\\Users\\marker_\\Documents\\Projects\\RenderEngine\\assets\\milyway.jpeg"
DIMUS :: "C:\\Users\\marker_\\Documents\\Projects\\RenderEngine\\assets\\dimus.jpg"