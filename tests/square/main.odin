package main

import "base:runtime"
import slog "shared:sokol/log"
import sg "shared:sokol/gfx"
import sapp "shared:sokol/app"
import sglue "shared:sokol/glue"
import m "../math"

ATTR_square :: enum u32 {
    position = 0,
    color0,
}

state: struct {
    position: m.vec2,
    velocity: m.vec2,
    pip: sg.Pipeline,
    bind: sg.Bindings,
}

init :: proc "c" () {
    context = runtime.default_context()
    sg.setup({
        environment = sglue.environment(),
        logger = { func = slog.func },
    })

    state.position = {0.0, 0.0}
    state.velocity = {0.01, 0.007}

    vertices := [?]f32 {
        -0.5, -0.5,       1.0, 0.0, 0.0, 1.0,
        0.5, -0.5,       0.0, 1.0, 0.0, 1.0,
        0.5,  0.5,       0.0, 0.0, 1.0, 1.0,
        -0.5,  0.5,       1.0, 1.0, 0.0, 1.0,
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

    state.position.x += state.velocity.x
    state.position.y += state.velocity.y

    if state.position.x > 1.0 || state.position.x < -1.0 {
        state.velocity.x = -state.velocity.x
    }
    if state.position.y > 1.0 || state.position.y < -1.0 {
        state.velocity.y = -state.velocity.y
    }

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

main :: proc () {
    sapp.run({
        init_cb = init,
        frame_cb = frame,
        cleanup_cb = cleanup,
        width = 800,
        height = 600,
        window_title = "Moving Square",
        icon = { sokol_default = true },
        logger = { func = slog.func },
    })
}
