package main

import "base:runtime"
import "core:math"
import "core:fmt"
import "core:time"
import "core:slice"
import sapp "shared:sokol/app"
import sg "shared:sokol/gfx"
import stime "shared:sokol/time"
import sdtx "shared:sokol/debugtext"
import shelpers "shared:sokol/helpers"
import snake_shader "shader"

default_context: runtime.Context

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH*CELL_SIZE
TICK_RATE :: 0.13
Vec2i :: [2]int
MAX_SNAKE_LENGTH :: GRID_WIDTH*GRID_WIDTH

State :: struct {
    snake: [MAX_SNAKE_LENGTH]Vec2i,
    snake_length: int,
    tick_timer: f64,
    move_direction: Vec2i,
    game_over: bool,
    food_pos: Vec2i,

    // Adding a flag to handle key press
    key_pressed: bool,

    // Rendering
    head_pixels: []u32,
    body_pixels: []u32,
    tail_pixels: []u32,
    food_pixels: []u32,

    bind: sg.Bindings,
    pip: sg.Pipeline,
}

state: State

place_food :: proc() {
    occupied: [GRID_WIDTH][GRID_WIDTH]bool

    for i in 0..<state.snake_length {
        occupied[state.snake[i].x][state.snake[i].y] = true
    }

    free_cells := make([dynamic]Vec2i, context.temp_allocator)

    for x in 0..<GRID_WIDTH {
        for y in 0..<GRID_WIDTH {
            if !occupied[x][y] {
                append(&free_cells, Vec2i{x, y})
            }
        }
    }

    if len(free_cells) > 0 {
    // Simple randomization without raylib
        random_cell_index := int(u64(time.now()._nsec) % u64(len(free_cells)))
        state.food_pos = free_cells[random_cell_index]
    }
}

restart :: proc() {
    start_head_pos := Vec2i{GRID_WIDTH / 2, GRID_WIDTH / 2}
    state.snake[0] = start_head_pos
    state.snake[1] = start_head_pos - {0, 1}
    state.snake[2] = start_head_pos - {0, 2}
    state.snake_length = 3
    state.move_direction = {0, 1}
    state.game_over = false
    state.tick_timer = TICK_RATE
    place_food()
}

init :: proc() {
    context = default_context

    sg.setup({
        environment = shelpers.glue_environment(),
        allocator = sg.Allocator(shelpers.allocator(&default_context)),
        logger = sg.Logger(shelpers.logger(&default_context)),
    })

    // Setup sokol-debugtext for text rendering
    sdtx_desc := sdtx.Desc{
        fonts = {
            0 = sdtx.Font_Desc{
                first_char = 32,
                last_char = 128,
            },
        },
    }
    sdtx.setup(sdtx_desc)

    // Initialize our game state
    state.tick_timer = TICK_RATE

    // Create placeholder textures for our sprites
    // In a real game, you'd load these from files
    state.head_pixels = make([]u32, CELL_SIZE * CELL_SIZE)
    state.body_pixels = make([]u32, CELL_SIZE * CELL_SIZE)
    state.tail_pixels = make([]u32, CELL_SIZE * CELL_SIZE)
    state.food_pixels = make([]u32, CELL_SIZE * CELL_SIZE)

    // Create simple colored pixels for the sprites
    for i in 0..<len(state.head_pixels) {
        state.head_pixels[i] = 0xFF00FF00  // Green for head
        state.body_pixels[i] = 0xFF008800  // Darker green for body
        state.tail_pixels[i] = 0xFF005500  // Even darker green for tail
        state.food_pixels[i] = 0xFFFF0000  // Red for food
    }

    // Set up the rendering pipeline and textures
    img_desc := sg.Image_Desc{
        width = CELL_SIZE,
        height = CELL_SIZE,
        pixel_format = .RGBA8,
    }

    // Create all our texture images
    head_img_desc := img_desc
    head_img_desc.data.subimage[0][0] = sg.Range{
        ptr = raw_data(state.head_pixels),
        size = size_of(u32) * len(state.head_pixels),
    }
    head_img := sg.make_image(head_img_desc)

    body_img_desc := img_desc
    body_img_desc.data.subimage[0][0] = sg.Range{
        ptr = raw_data(state.body_pixels),
        size = size_of(u32) * len(state.body_pixels),
    }
    body_img := sg.make_image(body_img_desc)

    tail_img_desc := img_desc
    tail_img_desc.data.subimage[0][0] = sg.Range{
        ptr = raw_data(state.tail_pixels),
        size = size_of(u32) * len(state.tail_pixels),
    }
    tail_img := sg.make_image(tail_img_desc)

    food_img_desc := img_desc
    food_img_desc.data.subimage[0][0] = sg.Range{
        ptr = raw_data(state.food_pixels),
        size = size_of(u32) * len(state.food_pixels),
    }
    food_img := sg.make_image(food_img_desc)

    // Initialize pipeline
    pip_desc := sg.Pipeline_Desc{
        layout = {
            attrs = {
                0 = { format = .FLOAT2 },  // position
                1 = { format = .FLOAT2 },  // texcoord
                2 = { format = .FLOAT4 },  // color
            },
        },
        index_type = .UINT16,
        cull_mode = .BACK,
        colors = {
            0 = { blend = { enabled = true,
            src_factor_rgb = .SRC_ALPHA,
            dst_factor_rgb = .ONE_MINUS_SRC_ALPHA }},
        },
    }

    state.pip = sg.make_pipeline(pip_desc)

    // Set up bindings
    state.bind.images[0] = head_img

    restart()
}

cleanup :: proc() {
    delete(state.head_pixels)
    delete(state.body_pixels)
    delete(state.tail_pixels)
    delete(state.food_pixels)

    sdtx.shutdown()
    sg.shutdown()
}

event :: proc(ev: ^sapp.Event) {
    if ev.type == .KEY_DOWN {
        #partial switch ev.key_code {
        case .UP:
            if state.move_direction.y != 1 {  // Prevent moving backwards
                state.move_direction = {0, -1}
            }
        case .DOWN:
            if state.move_direction.y != -1 {
                state.move_direction = {0, 1}
            }
        case .LEFT:
            if state.move_direction.x != 1 {
                state.move_direction = {-1, 0}
            }
        case .RIGHT:
            if state.move_direction.x != -1 {
                state.move_direction = {1, 0}
            }
        case .ENTER:
            if state.game_over {
                restart()
            }
        case .ESCAPE:
            sapp.quit()
        }
    }
}

frame :: proc() {
// Update game logic
    if !state.game_over {
        state.tick_timer -= sapp.frame_duration()
    }

    if state.tick_timer <= 0 {
        next_part_pos := state.snake[0]
        state.snake[0] += state.move_direction
        head_pos := state.snake[0]

        if head_pos.x < 0 || head_pos.y < 0 || head_pos.x >= GRID_WIDTH || head_pos.y >= GRID_WIDTH {
            state.game_over = true
        }

        for i in 1..<state.snake_length {
            cur_pos := state.snake[i]

            if cur_pos == head_pos {
                state.game_over = true
            }

            state.snake[i] = next_part_pos
            next_part_pos = cur_pos
        }

        if head_pos == state.food_pos {
            state.snake_length += 1
            state.snake[state.snake_length - 1] = next_part_pos
            place_food()
        }

        state.tick_timer = TICK_RATE + state.tick_timer
    }

    // Render frame
    sg.begin_default_pass({
        color = {0.3, 0.2, 0.3, 1.0},
        depth = 1.0,
    }, sapp.width(), sapp.height())

    // Draw elements using sokol-debugtext for simplicity
    sdtx.canvas(f32(sapp.width()), f32(sapp.height()))
    sdtx.font(0)
    sdtx.pos(4, 4)

    // Draw food
    sdtx.color(1.0, 0.0, 0.0, 1.0)  // Red
    food_x := state.food_pos.x * CELL_SIZE
    food_y := state.food_pos.y * CELL_SIZE
    sdtx.printf("F")

    // Draw snake
    for i in 0..<state.snake_length {
        x := state.snake[i].x * CELL_SIZE
        y := state.snake[i].y * CELL_SIZE

        if i == 0 {
            sdtx.color(0.0, 1.0, 0.0, 1.0)  // Green for head
            sdtx.pos(x, y)
            sdtx.printf("H")
        } else if i == state.snake_length - 1 {
            sdtx.color(0.0, 0.33, 0.0, 1.0)  // Dark green for tail
            sdtx.pos(x, y)
            sdtx.printf("T")
        } else {
            sdtx.color(0.0, 0.66, 0.0, 1.0)  // Medium green for body
            sdtx.pos(x, y)
            sdtx.printf("B")
        }
    }

    // Draw game info
    if state.game_over {
        sdtx.color(1.0, 0.0, 0.0, 1.0)  // Red
        sdtx.pos(4, 24)
        sdtx.printf("Game Over!")
        sdtx.color(1.0, 1.0, 1.0, 1.0)  // White
        sdtx.pos(4, 34)
        sdtx.printf("Press Enter to play again")
    }

    score := state.snake_length - 3
    sdtx.color(0.7, 0.7, 0.7, 1.0)  // Gray
    sdtx.pos(4, CANVAS_SIZE - 14)
    sdtx.printf("Score: %v", score)

    sdtx.draw()
    sg.end_pass()
    sg.commit()
}

main :: proc() {
    app_desc := sapp.Desc{
        init_cb = init,
        frame_cb = frame,
        cleanup_cb = cleanup,
        event_cb = event,
        width = WINDOW_SIZE,
        height = WINDOW_SIZE,
        gl_force_gles2 = true,
        window_title = "Snake - Sokol",
    }
    sapp.run(app_desc)
}