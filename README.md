# Goose Starter

A small starter repository for the [Goose programming language](https://aardappel.github.io/goose/).

## Run

With Goose on your `PATH`, run the example directly:

```sh
goose hello.goose
```

To build a native executable:

```sh
goose build hello.goose
./hello
```

## Open a window

Run the resizable graphics window:

```sh
goose window.goose
```

Press Escape or close the window to quit.

## PS1-era graphics demo

Run the low-poly scene with a checkerboard floor, 15-bit color quantization,
ordered dithering, and scanlines:

```sh
export DEEPSEEK_API_KEY="your-deepseek-api-key"
# Optional; defaults to deepseek-flash
export DEEPSEEK_MODEL="deepseek-flash"
goose ps1_demo.goose
```

Click the scene to capture the mouse; move it to look around, and press Tab to release or recapture.
Use WASD to pan, Left/Right to rotate, Space to pause, and Escape to quit.
Enter or Send submits your prompt to the selected model. The model can change the scene mood,
rotation speed, and camera distance. The prompt bar stays at the bottom of the game window.

To use the model controlled prompt bar, players need an API key and an account with a model
provider. This demo currently supports DeepSeek's API, so create a key with
[DeepSeek](https://platform.deepseek.com/),
keep it in `DEEPSEEK_API_KEY`, and have `curl` and a C compiler installed. The model bridge
currently supports Linux and macOS. The supported models
are `deepseek-flash` (default) and `deepseek-v4-pro`; set `DEEPSEEK_MODEL` to choose one. Each
prompt is sent to DeepSeek over HTTPS and may incur provider charges. Avoid entering private or
sensitive information. See the [DeepSeek API quickstart](https://api-docs.deepseek.com/quick_start/agent_integrations/)
for provider details.

See the [Goose tutorial](https://aardappel.github.io/goose/tutorial/) and [language reference](https://aardappel.github.io/goose/reference/) for more.
