package main

import "base:intrinsics"
import "base:runtime"
import stbi "vendor:stb/image"
import sapp "shared:sokol/app"
import shelpers "shared:sokol/helpers"
import sg "shared:sokol/gfx"
import "core:log"
import "core:math/linalg"
import "core:math"

to_radians :: linalg.to_radians

default_context: runtime.Context

Mat4 :: matrix[4, 4]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

ROTATION_SPEED :: 90

Globals :: struct {
    shader: sg.Shader,
    pipeline: sg.Pipeline,
    vertex_buffer: sg.Buffer,
    index_buffer: sg.Buffer,
    image: sg.Image,
    image2: sg.Image,
    sampler: sg.Sampler,
    rotation: f32,
    camera: struct {
        position: Vec3,
        target: Vec3,
        look: Vec2,
    }
}
g: ^Globals

main :: proc() {
    context.logger = log.create_console_logger()
    default_context = context
    sapp.run({
        width = 800,
        height  = 600,
        window_title = "yo",
        allocator = sapp.Allocator(shelpers.allocator(&default_context)),
        logger = sapp.Logger(shelpers.logger(&default_context)),
        init_cb = init_cb,
        frame_cb =frame_cb,
        cleanup_cb = cleanup_cb,
        event_cb = event_cb,
    })
}


init_cb :: proc "c" () {
    context = default_context

    sg.setup({
        environment = shelpers.glue_environment(),
        allocator = sg.Allocator(shelpers.allocator(&default_context)),
        logger = sg.Logger(shelpers.logger(&default_context)),
    })

    sapp.show_mouse(false)
    sapp.lock_mouse(true)

    g = new (Globals)

    g.camera = {
        position =  { 0, 0, 2 },
        target = { 0, 0, 1 },
    }

    g.shader = sg.make_shader(main_shader_desc(sg.query_backend()))
    g.pipeline = sg.make_pipeline({
        shader = g.shader,
        layout = {
            attrs = {
                ATTR_main_pos = { format = .FLOAT3 },
                ATTR_main_col = { format = .FLOAT4 },
                ATTR_main_uv = { format = .FLOAT2 }
            }
        },
        index_type = .UINT16,
        depth =  {
            write_enabled = true,
            compare = .LESS_EQUAL
        }
    })

    Vertex_Data :: struct {
        pos: Vec3,
        col: sg.Color,
        uv: Vec2,
    }

    WHITE :: sg.Color { 1, 1, 1, 1 }

    vertices := []Vertex_Data {
        { pos = { -0.5, -0.5, 0 }, col = WHITE, uv = { 0, 0 } },
        { pos = { 0.5, -0.5, 0 }, col = WHITE, uv = { 1, 0 } },
        { pos = { -0.5, 0.5, 0 }, col = WHITE, uv = { 0, 1 } },
        { pos = { 0.5, 0.5, 0 }, col = WHITE, uv = { 1, 1 } },
    }

    g.vertex_buffer = sg.make_buffer({
        data = sg_range(vertices)
    })

    indices := []i16 {
        0, 1, 2,
        2, 1, 3
    }

    g.index_buffer = sg.make_buffer({
        type = .INDEXBUFFER,
        data = sg_range(indices)
    })
    g.image = load_image("Plaster_17.png")
    g.image2 = load_image("Plaster_04.png")

    g.sampler = sg.make_sampler({ })
}

load_image :: proc(filename: cstring) -> sg.Image {
    w, h : i32
    pixels := stbi.load(filename, &w, &h, nil, 4)

    image := sg.make_image({
        width = w,
        height = h,
        pixel_format = .RGBA8,
        data = {
            subimage = {
                0 = {
                    0 = {
                        ptr = pixels,
                        size = uint(w * h * 4)
                    }
                }
            }
        }
    })
    stbi.image_free(pixels)

    return image
}
frame_cb :: proc "c" () {
    context = default_context

    if key_down[.ESCAPE] {
        sapp.quit()
        return
    }

    dt := f32(sapp.frame_duration())

    update_camera(dt)

    g.rotation += linalg.to_radians(ROTATION_SPEED * dt)

    projection := linalg.matrix4_perspective_f32(70, sapp.widthf() / sapp.heightf(), 0.0001, 1000)
    v := linalg.matrix4_look_at_f32(g.camera.position, g.camera.target, { 0, 1, 0 })

    Object :: struct {
        pos: Vec3,
        rot: Vec3,
        img: sg.Image,
    }
    objects := []Object {
        { { 0, 0, 0 }, { 0, 0, 0 }, g.image2 },
        { { 1, 0, 0 }, { 0, 0, 0 }, g.image2 },
        { { 2, 0, 0 }, { 0, 0, 0 }, g.image2 },
        { { 0, 0, 2 }, { 0, 0, 0 }, g.image2 },
        { { 1, 0, 2 }, { 0, 0, 0 }, g.image2 },
        { { 2, 0, 2 }, { 0, 0, 0 }, g.image2 },
        { { 0, -0.5, 0.5 }, { 90, 0, 0 }, g.image },
        { { 1, -0.5, 0.5 }, { 90, 0, 0 }, g.image },
        { { 2, -0.5, 0.5 }, { 90, 0, 0 }, g.image },
        { { 0, -0.5, 1.5 }, { 90, 0, 0 }, g.image },
        { { 1, -0.5, 1.5 }, { 90, 0, 0 }, g.image },
        { { 2, -0.5, 1.5 }, { 90, 0, 0 }, g.image },
    }

    sg.begin_pass({ swapchain = shelpers.glue_swapchain() })

    sg.apply_pipeline(g.pipeline)
    binding := sg.Bindings({
        vertex_buffers = g.vertex_buffer,
        index_buffer = g.index_buffer,
        images = { IMG_tex = g.image },
        samplers =  { SMP_smp = g.sampler },
    })

    for obj in objects {
        m := linalg.matrix4_translate_f32(obj.pos) * linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(obj.rot.y), to_radians(obj.rot.x), to_radians(obj.rot.z))
        b := binding

        b.images[IMG_tex] = obj.img

        sg.apply_bindings(b)
        sg.apply_uniforms(UB_Vs_Params, sg_range(&Vs_Params {
            mvp = projection * v * m
        }))
        sg.draw(0, 6, 1)
    }
    sg.end_pass()
    sg.commit()
    mouse_move = { }
}

cleanup_cb :: proc "c" () {
    context = default_context
    sg.destroy_image(g.image)
    sg.destroy_image(g.image2)
    sg.dealloc_sampler(g.sampler)
    sg.dealloc_buffer(g.vertex_buffer)
    sg.dealloc_buffer(g.index_buffer)
    sg.destroy_pipeline(g.pipeline)
    sg.destroy_shader(g.shader)

    free(g)
    sg.shutdown()
}

mouse_move: Vec2
key_down: #sparse[sapp.Keycode]bool

event_cb :: proc "c" (ev: ^sapp.Event) {
    context = default_context
    //log.debug(ev.type)

    #partial switch ev.type {
    case .MOUSE_MOVE:
        mouse_move += { ev.mouse_dx, ev.mouse_dy }
    case.KEY_DOWN:
        key_down[ev.key_code] = true
    case .KEY_UP:
        key_down[ev.key_code] = false
    }
}

MOVE_SPEED :: 3
LOOK_SENSITIVITY :: 0.2

update_camera :: proc(dt: f32) {
    move_input: Vec2

    if key_down[.W] do move_input.y = 1
    else if key_down[.S] do move_input.y = -1
    if key_down[.A] do move_input.x = -1
    else if key_down[.D] do move_input.x = 1

    look_input : Vec2 = -mouse_move * LOOK_SENSITIVITY
    g.camera.look += look_input
    g.camera.look.x = math.wrap(g.camera.look.x, 360)
    g.camera.look.y = math.clamp(g.camera.look.y, -90, 90)

    look_mat := linalg.matrix4_from_yaw_pitch_roll_f32(to_radians(g.camera.look.x), to_radians(g.camera.look.y), 0)
    forward := (look_mat * Vec4 { 0, 0, -1, 1 }).xyz
    right := (look_mat * Vec4 { 1, 0, 0, 1 }).xyz

    move_dir := forward * move_input.y + right * move_input.x

    motion := linalg.normalize0(move_dir) * MOVE_SPEED * dt
    g.camera.position += motion

    g.camera.target = g.camera.position + forward

}

sg_range :: proc {
    sg_range_from_struct,
    sg_range_from_slice,
}

sg_range_from_struct :: proc(s: ^$T) -> sg.Range where intrinsics.type_is_struct(T) {
    return  { ptr = s, size = size_of(T) }
}

sg_range_from_slice :: proc(s: []$T) -> sg.Range {
    return  { ptr = raw_data(s), size = len(s) * size_of(s[0]) }
}