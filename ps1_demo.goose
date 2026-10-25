// A PS1-era inspired graphics demo: low-poly geometry, a checkerboard floor,
// 5-bit color, ordered dithering, and scanlines.
import std;
import gfx;
import math;
import os;
import ui;

struct Vertex { pos: float3, color: u8[4] }
struct Transform { model: gfx::mat4, view_proj: gfx::mat4 }

fn add_triangle(verts: Vertex[>..]&, indices: u16[>..]&, a: float3, b: float3, c: float3,
                color: u8[4]) {
    let base = verts.len as u16;
    verts.push(Vertex { pos: a, color: color });
    verts.push(Vertex { pos: b, color: color });
    verts.push(Vertex { pos: c, color: color });
    indices.append([base, base + 1, base + 2]);
}

fn add_pyramid(verts: Vertex[>..]&, indices: u16[>..]&) {
    let top = float3 { 0.0, 1.35, 0.0 };
    let a = float3 { -0.9, -0.65, 0.9 };
    let b = float3 { 0.9, -0.65, 0.9 };
    let c = float3 { 0.9, -0.65, -0.9 };
    let d = float3 { -0.9, -0.65, -0.9 };

    add_triangle(verts, indices, top, a, b, [255, 92, 72, 255]);
    add_triangle(verts, indices, top, b, c, [255, 192, 80, 255]);
    add_triangle(verts, indices, top, c, d, [96, 224, 190, 255]);
    add_triangle(verts, indices, top, d, a, [112, 144, 255, 255]);
    add_triangle(verts, indices, a, d, c, [54, 62, 104, 255]);
    add_triangle(verts, indices, a, c, b, [54, 62, 104, 255]);
}

fn main() {
    guard gfx::open("1995 // POLYGON DREAMS", 960, 640, gfx::WINDOW_RESIZABLE) else {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }

    var verts: Vertex[>..] = [];
    var indices: u16[>..] = [];

    // A chunky tiled floor gives the scene a classic console-era horizon.
    for z in 18 {
        let z0 = (z as f32 - 9.0) * 0.8;
        let z1 = z0 + 0.8;
        for x in 18 {
            let x0 = (x as f32 - 9.0) * 0.8;
            let x1 = x0 + 0.8;
            let color: u8[4] = if (x + z) % 2 == 0 {
                [22, 48, 78, 255]
            } else {
                [14, 32, 56, 255]
            };
            let p00 = float3 { x0, -0.95, z0 };
            let p10 = float3 { x1, -0.95, z0 };
            let p11 = float3 { x1, -0.95, z1 };
            let p01 = float3 { x0, -0.95, z1 };
            add_triangle(verts, indices, p00, p10, p11, color);
            add_triangle(verts, indices, p00, p11, p01, color);
        }
    }

    let floor_index_count = indices.len;
    let pyramid_first_index = indices.len;
    add_pyramid(verts, indices);
    let pyramid_index_count = indices.len - pyramid_first_index;

    let vertex_buffer = gfx::vertex_buffer(bytes_of(verts));
    let index_buffer = gfx::index_buffer(bytes_of(indices));
    let vertex_shader = embed_shader("vert", """
        layout(location = 0) in vec3 a_pos;
        layout(location = 1) in vec4 a_color;
        layout(set = 1, binding = 0) uniform Transform {
            mat4 model;
            mat4 view_proj;
        };
        layout(location = 0) out vec4 v_color;
        void main() {
            v_color = a_color;
            gl_Position = view_proj * model * vec4(a_pos, 1.0);
        }
        """);
    let fragment_shader = embed_shader("frag", """
        layout(location = 0) in vec4 v_color;
        layout(location = 0) out vec4 result;
        void main() {
            vec2 pixel = floor(gl_FragCoord.xy / 2.0);
            float dither = mod(pixel.x + pixel.y, 2.0) * 0.5;
            float scanline = mod(floor(gl_FragCoord.y / 2.0), 2.0);
            vec3 color = floor(v_color.rgb * 31.0 + dither) / 31.0;
            color *= 1.0 - scanline * 0.12;
            result = vec4(color, 1.0);
        }
        """);
    var desc = gfx::PipelineDesc { depth_test: true, depth_write: true };
    desc.formats[1] = gfx::VERTEX_UBYTE4_NORM;
    let pipeline = gfx::pipeline(vertex_shader, fragment_shader, desc);

    var ctx = ui::create(16.0);
    guard ctx.id != 0 else {
        write_stderr(str("ui: ", ui::error(), "\n"));
        gfx::close();
        return;
    }
    let panel = ui::WINDOW_BORDER | ui::WINDOW_MOVABLE | ui::WINDOW_TITLE;
    var angle: f32 = 0.0;
    var paused = false;

    while gfx::frame() {
        let dt = gfx::delta_time() as f32;
        if gfx::key_pressed("Escape") { break; }
        if gfx::key_pressed("Space") { paused = !paused; }
        if !paused { angle += dt * 0.75; }
        if gfx::key_down("Left") { angle -= dt * 1.5; }
        if gfx::key_down("Right") { angle += dt * 1.5; }

        let size = gfx::screen_size();
        let aspect = size.x as f32 / max(size.y, 1);
        let view = gfx::look_at(float3 { 0.0, 3.5, 8.5 }, float3 { 0.0, -0.1, 0.0 },
                                float3 { 0.0, 1.0, 0.0 });
        let view_proj = gfx::mul(gfx::perspective(0.92, aspect, 0.1, 60.0), view);
        let tilt = gfx::rotate(float3 { 1.0, 0.0, 0.0 }, sin(angle * 0.7) * 0.08);
        let spin = gfx::rotate(float3 { 0.0, 1.0, 0.0 }, angle);

        ui::input_from_gfx(ctx);
        if ui::begin(ctx, "SIGNAL // 1995", ui::rect(22, 22, 340, 170), panel) {
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "LOW-POLY  /  15-BIT RGB", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "2x2 ORDERED DITHER  /  SCANLINES", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, str("SCENE TRIANGLES  ", floor_index_count / 3 + pyramid_index_count / 3 * 3),
                      ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "LEFT / RIGHT ROTATE  |  SPACE PAUSE  |  ESC EXIT", ui::TEXT_LEFT);
        }
        ui::end(ctx);

        gfx::begin_screen(float4 { 0.025, 0.045, 0.09, 1.0 });
        gfx::bind(pipeline);
        gfx::bind_vertex_buffer(vertex_buffer);
        gfx::bind_index_buffer(index_buffer, 2);

        gfx::uniforms(gfx::VERTEX, 0,
                      Transform { model: gfx::mat4_identity, view_proj: view_proj });
        gfx::draw_indexed(floor_index_count);

        let center = gfx::mul(gfx::translate(float3 { 0.0, 0.0, 0.0 }),
                              gfx::mul(spin, tilt));
        gfx::uniforms(gfx::VERTEX, 0, Transform { model: center, view_proj: view_proj });
        gfx::draw_indexed(pyramid_index_count, 1, pyramid_first_index, 0, 0);

        let left = gfx::mul(gfx::translate(float3 { -2.1, -0.18, -0.7 }),
                            gfx::mul(gfx::rotate(float3 { 0.0, 1.0, 0.0 }, -angle * 1.2),
                                     gfx::scale(float3 { 0.58, 0.58, 0.58 })));
        gfx::uniforms(gfx::VERTEX, 0, Transform { model: left, view_proj: view_proj });
        gfx::draw_indexed(pyramid_index_count, 1, pyramid_first_index, 0, 0);

        let right = gfx::mul(gfx::translate(float3 { 2.0, -0.32, -1.1 }),
                             gfx::mul(gfx::rotate(float3 { 0.0, 1.0, 0.0 }, angle * 0.8),
                                      gfx::scale(float3 { 0.42, 0.42, 0.42 })));
        gfx::uniforms(gfx::VERTEX, 0, Transform { model: right, view_proj: view_proj });
        gfx::draw_indexed(pyramid_index_count, 1, pyramid_first_index, 0, 0);

        gfx::end_pass();
        ui::render(ctx);
    }

    ui::destroy(ctx);
    gfx::release(pipeline);
    gfx::release(index_buffer);
    gfx::release(vertex_buffer);
    gfx::close();
}
