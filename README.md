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
goose ps1_demo.goose
```

Click the scene to capture the mouse; move it to look around, and press Tab to release or recapture.
Use WASD to pan, Left/Right to rotate, Space to pause, and Escape to quit.

See the [Goose tutorial](https://aardappel.github.io/goose/tutorial/) and [language reference](https://aardappel.github.io/goose/reference/) for more.
