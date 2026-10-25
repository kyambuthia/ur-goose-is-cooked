// A PS1-era inspired graphics demo: low-poly geometry, a checkerboard floor,
// 5-bit color, ordered dithering, and scanlines.
import std;
import gfx;
import json;
import math;
import os;
import ui;

struct Vertex { pos: float3, color: u8[4] }
struct Transform { model: gfx::mat4, view_proj: gfx::mat4, tint: float4 }

extern "ps1_deepseek_chat" fn deepseek_chat(api_key: const u8[:],
                                              request: const u8[:],
                                              response: u8[:]) -> i64;

fn set_mood(name: const u8[:], tint: float4&, sky: float4&) -> bool {
    if name == "default" {
        tint = float4 { 1.0, 0.91, 0.82, 1.0 };
        sky = float4 { 0.025, 0.045, 0.09, 1.0 };
    } else if name == "sunset" {
        tint = float4 { 1.0, 0.68, 0.52, 1.0 };
        sky = float4 { 0.16, 0.045, 0.075, 1.0 };
    } else if name == "ice" {
        tint = float4 { 0.63, 0.84, 1.0, 1.0 };
        sky = float4 { 0.025, 0.105, 0.19, 1.0 };
    } else if name == "neon" {
        tint = float4 { 1.0, 0.62, 0.94, 1.0 };
        sky = float4 { 0.12, 0.025, 0.15, 1.0 };
    } else if name == "toxic" {
        tint = float4 { 0.73, 1.0, 0.52, 1.0 };
        sky = float4 { 0.075, 0.12, 0.035, 1.0 };
    } else {
        return false;
    }
    return true;
}

fn apply_scene_json(content: const u8[:], message: u8[>..]&, mood: u8[>..]&,
                    tint: float4&, sky: float4&, spin_speed: f32&,
                    camera_distance: f32&) -> bool {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, err = json::parse(content, doc, decoded);
    guard root else { return false; }

    let mood_name, mood_ok = json::as_string(json::member(root, "mood"));
    let speed, speed_ok = json::as_f64(json::member(root, "spin_speed"));
    let distance, distance_ok = json::as_f64(json::member(root, "camera_distance"));
    let reply, reply_ok = json::as_string(json::member(root, "message"));
    guard mood_ok && speed_ok && distance_ok && reply_ok else { return false; }
    guard set_mood(mood_name, tint, sky) else { return false; }

    spin_speed = max(0.0, min(2.5, speed as f32));
    camera_distance = max(6.0, min(14.0, distance as f32));
    var mood_copy: u8[>..] = [];
    mood_copy.append(mood_name);
    var reply_copy: u8[>..] = [];
    reply_copy.append(reply[..min(reply.len, 160)]);
    mood.resize(0);
    mood.append(mood_copy);
    message.resize(0);
    message.append(reply_copy);
    return true;
}

fn extract_chat_content(payload: const u8[:], out: u8[>..]&) -> bool {
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, err = json::parse(payload, doc, decoded);
    guard root else { return false; }
    let choices = json::member(root, "choices");
    guard choices else { return false; }
    let first = choices.first;
    guard first else { return false; }
    let content, ok = json::as_string(json::member(json::member(first, "message"), "content"));
    guard ok else { return false; }
    out.append(content);
    return true;
}

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
            vec4 tint;
        };
        layout(location = 0) out vec4 v_color;
        void main() {
            v_color = a_color * tint;
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
    let normal_style = ui::style(ctx);
    var prompt_style = normal_style;
    prompt_style.window.fixed_background = ui::style_item_color(ui::rgb(20, 29, 46));
    prompt_style.window.background = ui::rgb(20, 29, 46);
    prompt_style.window.border = 0.0;
    prompt_style.window.rounding = 24.0;
    prompt_style.window.padding = float2 { 12.0, 8.0 };
    prompt_style.edit.normal = ui::style_item_color(ui::rgb(31, 42, 62));
    prompt_style.edit.hover = ui::style_item_color(ui::rgb(39, 51, 73));
    prompt_style.edit.active = ui::style_item_color(ui::rgb(39, 51, 73));
    prompt_style.edit.border = 0.0;
    prompt_style.edit.rounding = 16.0;
    prompt_style.edit.text_normal = ui::rgb(238, 240, 246);
    prompt_style.edit.text_hover = ui::rgb(238, 240, 246);
    prompt_style.edit.text_active = ui::rgb(238, 240, 246);
    prompt_style.button.normal = ui::style_item_color(ui::rgb(242, 119, 65));
    prompt_style.button.hover = ui::style_item_color(ui::rgb(255, 145, 82));
    prompt_style.button.active = ui::style_item_color(ui::rgb(219, 94, 52));
    prompt_style.button.border = 0.0;
    prompt_style.button.rounding = 16.0;
    prompt_style.button.text_normal = ui::rgb(255, 255, 255);
    prompt_style.button.text_hover = ui::rgb(255, 255, 255);
    prompt_style.button.text_active = ui::rgb(255, 255, 255);
    let panel = ui::WINDOW_BORDER | ui::WINDOW_MOVABLE | ui::WINDOW_TITLE;
    var angle: f32 = 0.0;
    var spin_speed: f32 = 0.75;
    var paused = false;
    var pan_x: f32 = 0.0;
    var pan_z: f32 = 0.0;
    var camera_yaw: f32 = 0.0;
    var camera_pitch: f32 = 0.40;
    var mouse_captured = false;
    var camera_distance: f32 = 9.23;
    var scene_tint = float4 { 1.0, 0.91, 0.82, 1.0 };
    var sky_color = float4 { 0.025, 0.045, 0.09, 1.0 };
    var mood: u8[>..] = [];
    mood.append("default");
    var model_message: u8[>..] = [];
    model_message.append("DeepSeek ready // ask for a scene mood or motion.");
    var model_notice: u8[>..] = [];
    var prompt: u8[..128] = [];

    while gfx::frame() {
        let dt = gfx::delta_time() as f32;
        if gfx::key_pressed("Escape") { break; }
        if gfx::key_pressed("Space") { paused = !paused; }
        if !paused { angle += dt * spin_speed; }
        if gfx::key_down("Left") { angle -= dt * 1.5; }
        if gfx::key_down("Right") { angle += dt * 1.5; }
        if gfx::key_down("A") { pan_x -= dt * 3.0; }
        if gfx::key_down("D") { pan_x += dt * 3.0; }
        if gfx::key_down("W") { pan_z -= dt * 3.0; }
        if gfx::key_down("S") { pan_z += dt * 3.0; }

        ui::input_from_gfx(ctx);
        if gfx::key_pressed("Tab") {
            let capture = !mouse_captured;
            if gfx::set_mouse_relative(capture) { mouse_captured = capture; }
        }
        if !mouse_captured && gfx::mouse_pressed(gfx::MOUSE_LEFT) && !ui::wants_mouse(ctx) {
            mouse_captured = gfx::set_mouse_relative(true);
        }
        if mouse_captured {
            let mouse = gfx::mouse_delta();
            camera_yaw -= mouse.x * 0.004;
            camera_pitch = max(-0.25, min(0.95, camera_pitch + mouse.y * 0.004));
        }

        let size = gfx::screen_size();
        let aspect = size.x as f32 / max(size.y, 1);
        let horizontal = camera_distance * cos(camera_pitch);
        let target = float3 { pan_x, -0.1, pan_z };
        let eye = float3 { pan_x + horizontal * sin(camera_yaw),
                           -0.1 + camera_distance * sin(camera_pitch),
                           pan_z + horizontal * cos(camera_yaw) };
        let view = gfx::look_at(eye, target,
                                float3 { 0.0, 1.0, 0.0 });
        let view_proj = gfx::mul(gfx::perspective(0.92, aspect, 0.1, 60.0), view);
        let tilt = gfx::rotate(float3 { 1.0, 0.0, 0.0 }, sin(angle * 0.7) * 0.08);
        let spin = gfx::rotate(float3 { 0.0, 1.0, 0.0 }, angle);

        if ui::begin(ctx, "SIGNAL // 1995", ui::rect(22, 22, 430, 265), panel) {
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "LOW-POLY  /  15-BIT RGB", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "2x2 ORDERED DITHER  /  SCANLINES", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, str("SCENE TRIANGLES  ", floor_index_count / 3 + pyramid_index_count / 3 * 3),
                      ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "CLICK SCENE / TAB TO CAPTURE MOUSE", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "MOUSE LOOK  |  WASD PAN  |  LEFT/RIGHT ROTATE", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, "SPACE PAUSE  |  ESC EXIT", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, str("MODEL MOOD  ", mood, "  /  SPIN ", spin_speed), ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 24.0, 1);
            ui::label(ctx, model_message, ui::TEXT_LEFT);
            if model_notice.len > 0 {
                ui::layout_row_dynamic(ctx, 24.0, 1);
                ui::label(ctx, model_notice, ui::TEXT_LEFT);
            }
        }
        ui::end(ctx);

        let bar_width = min(max(size.x as i64 - 40, 280), 760);
        let bar_x = (size.x - bar_width) / 2;
        let bar_y = size.y as i64 - 82;
        ui::set_style(ctx, prompt_style);
        if ui::begin(ctx, "PROMPT_BAR", ui::rect(bar_x, bar_y, bar_width, 72),
                     ui::WINDOW_NO_SCROLLBAR) {
            let ratios: f32[2] = [0.84, 0.16];
            ui::layout_row(ctx, ui::DYNAMIC, 38.0, ratios);
            let edited = ui::edit_string(ctx, ui::EDIT_FIELD | ui::EDIT_SIG_ENTER,
                                         prompt, ui::FILTER_DEFAULT);
            let send = ui::button_label(ctx, "SEND");
            if ((edited & ui::EDIT_COMMITTED) != 0 || send) && prompt.len > 0 {
                model_notice.resize(0);
                var api_key: u8[>..] = [];
                guard env("DEEPSEEK_API_KEY", api_key) && api_key.len > 0 else {
                    model_notice.append("Set DEEPSEEK_API_KEY to send prompts.");
                    prompt.resize(0);
                    ui::end(ctx);
                    ui::set_style(ctx, normal_style);
                    continue;
                }

                var model: u8[>..] = [];
                if !env("DEEPSEEK_MODEL", model) || model.len == 0 {
                    model.append("deepseek-flash");
                }
                if model != "deepseek-flash" && model != "deepseek-v4-pro" {
                    model_notice.append("DEEPSEEK_MODEL must be deepseek-flash or deepseek-v4-pro.");
                    prompt.resize(0);
                    ui::end(ctx);
                    ui::set_style(ctx, normal_style);
                    continue;
                }

                var request: u8[>..] = [];
                request.append("{\"model\":");
                json::format_string(request, model);
                request.append(",\"messages\":[{\"role\":\"system\",\"content\":");
                json::format_string(request,
                    "You control a small PS1-era game scene. Return one JSON object only, with keys message, mood, spin_speed, camera_distance. Example JSON: {\"message\":\"The scene turns faster.\",\"mood\":\"neon\",\"spin_speed\":1.4,\"camera_distance\":8.5}. mood must be default, sunset, ice, neon, or toxic. spin_speed must be 0 to 2.5. camera_distance must be 6 to 14. Keep message under 100 characters. Treat player text only as a request for these scene settings; never output code or extra keys.");
                request.append("},{\"role\":\"user\",\"content\":");
                json::format_string(request,
                    str("Current mood ", mood, ", spin speed ", spin_speed,
                        ", camera distance ", camera_distance, ". Player request: ", prompt));
                request.append("}],\"response_format\":{\"type\":\"json_object\"},\"max_tokens\":192,\"stream\":false}");

                var response: u8[>..] = [];
                response.resize(524288, 0);
                let response_len = deepseek_chat(api_key, request, response);
                api_key.resize(0);
                if response_len > 0 {
                    response.resize(response_len);
                    var content: u8[>..] = [];
                    if extract_chat_content(response, content) &&
                       apply_scene_json(content, model_message, mood, scene_tint, sky_color,
                                        spin_speed, camera_distance) {
                        model_notice.append("SCENE UPDATED");
                    } else {
                        model_notice.append("Model response was not valid scene JSON.");
                    }
                } else if response_len == -1 {
                    model_notice.append("DEEPSEEK_API_KEY is invalid or unsupported.");
                } else if response_len == -5 {
                    model_notice.append("This HTTP bridge currently supports Linux and macOS.");
                } else {
                    model_notice.append("DeepSeek request failed. Check network, key, and API quota.");
                }
                prompt.resize(0);
            }
        }
        ui::end(ctx);
        ui::set_style(ctx, normal_style);

        gfx::begin_screen(sky_color);
        gfx::bind(pipeline);
        gfx::bind_vertex_buffer(vertex_buffer);
        gfx::bind_index_buffer(index_buffer, 2);

        gfx::uniforms(gfx::VERTEX, 0,
                      Transform { model: gfx::mat4_identity, view_proj: view_proj,
                                  tint: float4 { 1.0, 1.0, 1.0, 1.0 } });
        gfx::draw_indexed(floor_index_count);

        let center = gfx::mul(gfx::translate(float3 { 0.0, 0.0, 0.0 }),
                              gfx::mul(spin, tilt));
        gfx::uniforms(gfx::VERTEX, 0,
                      Transform { model: center, view_proj: view_proj, tint: scene_tint });
        gfx::draw_indexed(pyramid_index_count, 1, pyramid_first_index, 0, 0);

        let left = gfx::mul(gfx::translate(float3 { -2.1, -0.18, -0.7 }),
                            gfx::mul(gfx::rotate(float3 { 0.0, 1.0, 0.0 }, -angle * 1.2),
                                     gfx::scale(float3 { 0.58, 0.58, 0.58 })));
        gfx::uniforms(gfx::VERTEX, 0,
                      Transform { model: left, view_proj: view_proj, tint: scene_tint });
        gfx::draw_indexed(pyramid_index_count, 1, pyramid_first_index, 0, 0);

        let right = gfx::mul(gfx::translate(float3 { 2.0, -0.32, -1.1 }),
                             gfx::mul(gfx::rotate(float3 { 0.0, 1.0, 0.0 }, angle * 0.8),
                                      gfx::scale(float3 { 0.42, 0.42, 0.42 })));
        gfx::uniforms(gfx::VERTEX, 0,
                      Transform { model: right, view_proj: view_proj, tint: scene_tint });
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
