import std;
import gfx;
import os;
import ui;

fn main() {
    guard gfx::open("Goose: first window", 900, 600, gfx::WINDOW_RESIZABLE) else {
        write_stderr(str("gfx: ", gfx::error(), "\n"));
        return;
    }

    var ctx = ui::create(18.0);
    guard ctx.id != 0 else {
        write_stderr(str("ui: ", ui::error(), "\n"));
        gfx::close();
        return;
    }
    let panel = ui::WINDOW_BORDER | ui::WINDOW_MOVABLE | ui::WINDOW_TITLE;

    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        ui::input_from_gfx(ctx);

        if ui::begin(ctx, "Welcome", ui::rect(48, 48, 380, 150), panel) {
            ui::layout_row_dynamic(ctx, 32.0, 1);
            ui::label(ctx, "Hello from Goose!", ui::TEXT_LEFT);
            ui::layout_row_dynamic(ctx, 26.0, 1);
            ui::label(ctx, "Move this panel, resize the window, or press Escape to quit.",
                      ui::TEXT_LEFT);
        }
        ui::end(ctx);

        gfx::begin_screen(float4 { 0.08, 0.11, 0.16, 1.0 });
        gfx::end_pass();
        ui::render(ctx);
    }

    ui::destroy(ctx);
    gfx::close();
}
