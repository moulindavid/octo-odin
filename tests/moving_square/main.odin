package main

import "base:runtime"
import slog "shared:sokol/log"
import sg "shared:sokol/gfx"
import sapp "shared:sokol/app"
import sglue "shared:sokol/glue"
import "core:math/linalg"
import "core:log"
import m "../math"

Vec2 :: [2]f32

ATTR_square :: enum u32 {
    position = 0,
    color0,
}


state: struct {
    position: m.vec2,
    pip: sg.Pipeline,
    bind: sg.Bindings,
    movement_speed: f32,
}

init :: proc "c" () {
    context = runtime.default_context()
    sg.setup({
        environment = sglue.environment(),
        logger = { func = slog.func },
    })

    state.position = {0.0, 0.0}
    state.movement_speed = 0.2

    vertices := [?]f32 {
        -0.3, -0.3,       1.0, 1.0, 1.0, 1.0,
        0.3, -0.3,       1.0, 1.0, 1.0, 1.0,
        0.3,  0.3,       1.0, 1.0, 1.0, 1.0,
        -0.3,  0.3,       1.0, 1.0, 1.0, 1.0,
    }
    state.bind.vertex_buffers[0] = sg.make_buffer({
        data = { ptr = &vertices, size = size_of(vertices) },
    })

    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    state.bind.index_buffer = sg.make_buffer({
        type = .INDEXBUFFER,
        data = { ptr = &indices, size = size_of(indices) },
    })

    state.pip = sg.make_pipeline({
        shader = sg.make_shader(square_shader_desc(sg.query_backend())),
        layout = {
            buffers = {
                0 = { stride = 24 },
            },
            attrs = {
                ATTR_square.position = { format = .FLOAT2 },
                ATTR_square.color0 = { format = .FLOAT4 },
            },
        },
        index_type = .UINT16,
        cull_mode = .NONE,
        depth = {
            write_enabled = false,
            compare = .ALWAYS,
        },
    })
}

frame :: proc "c" () {
    context = runtime.default_context()
    frame_time := sapp.frame_duration()
    move_input: Vec2


    if key_down[.W] do move_input.y += 0.1
    if key_down[.S] do move_input.y -= 0.1
    if key_down[.A] do move_input.x -= 0.1
    if key_down[.D] do move_input.x += 0.1

    if move_input.x != 0 && move_input.y != 0 {
        length := linalg.sqrt(move_input.x * move_input.x + move_input.y * move_input.y)
        if length > 0 {
            move_input.x /= length
            move_input.y /= length
        }
    }

    state.position.x += move_input.x * state.movement_speed * f32(frame_time * 60.0)
    state.position.y += move_input.y * state.movement_speed * f32(frame_time * 60.0)

    state.position.x = max(-0.7, min(0.7, state.position.x))
    state.position.y = max(-0.7, min(0.7, state.position.y))

    translation := m.translate({state.position.x, state.position.y, 0.0})

    vs_params := Vs_Params{
        mvp = translation,
    }

    pass_action := sg.Pass_Action{
        colors = {
            0 = { load_action = .CLEAR, clear_value = { 0.1, 0.1, 0.1, 1.0 } },
        },
    }

    sg.begin_pass({ action = pass_action, swapchain = sglue.swapchain() })
    sg.apply_pipeline(state.pip)
    sg.apply_bindings(state.bind)
    sg.apply_uniforms(UB_vs_params, { ptr = &vs_params, size = size_of(vs_params) })
    sg.draw(0, 6, 1)
    sg.end_pass()
    sg.commit()
}

cleanup :: proc "c" () {
    context = runtime.default_context()
    sg.shutdown()
}

key_down: #sparse[sapp.Keycode]bool

event_cb :: proc "c" (ev: ^sapp.Event) {
    context = runtime.default_context()

    #partial switch ev.type {
    case .KEY_DOWN:
        key_down[ev.key_code] = true
    case .KEY_UP:
        key_down[ev.key_code] = false
    }
}

main :: proc () {
    sapp.run({
        init_cb = init,
        frame_cb = frame,
        cleanup_cb = cleanup,
        event_cb = event_cb,
        width = 800,
        height = 600,
        window_title = "Moving Square",
        icon = { sokol_default = true },
        logger = { func = slog.func },
    })
}