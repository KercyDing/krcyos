# 🌱 KrcyOS

A toy RISC-V kernel built with Zig for OS exploration.

> Github: [URL](https://github.com/KercyDing/krcyos.git)

<p align="left">
  <img src="assets/demo_1.webp" height="500" style="border-radius: 10px;">
  &nbsp;
  <img src="assets/demo_2.webp" height="500" style="border-radius: 10px;">
</p>

## Motivation

*Just for fun.*

## Prerequisites

- **[Zig](https://ziglang.org/download)** (pinned to `0.16.0`)
- **[QEMU](https://www.qemu.org/download)** (>=11.0.0, if you don't have a real board)
- **[Only](https://github.com/KercyDing/only)** (task runner if you like)

> Skill issue? Click [here](https://google.com/).

## Getting Started

### Clone the toy
```bash
git clone https://code.kercy666.com/Kercy/krcyos.git
# if you prefer github:
# git clone https://github.com/KercyDing/krcyos.git
cd krcyos
# ...
```

### Simply run it
```bash
zig build run
# or:
# only run qemu
```

If you have a real board:
```bash
zig build run -Dboard=real_board
# or:
# only run real
```

Then flash to your board.

> Press `Ctrl+A` + `X` to exit qemu.

### What's more
Try another log level:
```bash
zig build run -Dlog=debug
# or:
# only run qemu debug
```

Run unit tests:
```bash
zig build test
# or:
# only test
```

That's it.

## Why not C/Rust?
No reason. Zig worth.
