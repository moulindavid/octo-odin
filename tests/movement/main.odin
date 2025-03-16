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

    key_pressed: bool,
    pass_action: sg.Pass_Action,
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

init :: proc "c" () {
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

    state.pass_action = {
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.3, 0.2, 0.3, 1.0 } },
        },
    }

    state.tick_timer = TICK_RATE

    restart()
}

cleanup :: proc "c" () {
    sdtx.shutdown()
    sg.shutdown()
}

event :: proc "c" (ev: ^sapp.Event) {
    context = default_context

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

frame :: proc "c" () {
    context = default_context
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

    width, height := sapp.width(), sapp.height()
    sg.begin_pass(sg.Pass{action = state.pass_action})

    sdtx.canvas(f32(width), f32(height))
    sdtx.origin(0, 0)
    sdtx.font(0)

    sdtx.color3f(1.0, 0.0, 0.0)  // Red
    food_x := state.food_pos.x * CELL_SIZE / 4
    food_y := state.food_pos.y * CELL_SIZE / 4
    sdtx.pos(f32(food_x), f32(food_y))
    sdtx.puts("F")

    for i in 0..<state.snake_length {
        x := state.snake[i].x * CELL_SIZE / 4
        y := state.snake[i].y * CELL_SIZE / 4

        if i == 0 {
            sdtx.color3f(0.0, 1.0, 0.0)  // Green for head
            sdtx.pos(f32(x), f32(y))
            sdtx.puts("H")
        } else if i == state.snake_length - 1 {
            sdtx.color3f(0.0, 0.33, 0.0)  // Dark green for tail
            sdtx.pos(f32(x), f32(y))
            sdtx.puts("T")
        } else {
            sdtx.color3f(0.0, 0.66, 0.0)  // Medium green for body
            sdtx.pos(f32(x), f32(y))
            sdtx.puts("B")
        }
    }

    if state.game_over {
        sdtx.color3f(1.0, 0.0, 0.0)  // Red
        sdtx.pos(4, 24)
        sdtx.puts("Game Over!")
        sdtx.color3f(1.0, 1.0, 1.0)  // White
        sdtx.pos(4, 34)
        sdtx.puts("Press Enter to play again")
    }

    score := state.snake_length - 3
    sdtx.color3f(0.7, 0.7, 0.7)  // Gray
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
        window_title = "Snake - Sokol",
    }
    sapp.run(app_desc)
}