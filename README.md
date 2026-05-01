# 🌱 KrcyOS

A toy RISC-V kernel built with Zig for OS exploration.

## Motivation

To understand computer architecture and operating systems.

## Prerequisites

- **[Zig](https://ziglang.org/download/#release-0.16.0)** (>=0.16.0)
- **[QEMU](https://www.qemu.org/download)** (>=11.0.0, if you don't have a real board)
- **[Only](https://github.com/KercyDing/only)** (task runner if you like)

## Getting Started

### Clone the toy
```bash
git clone https://codeberg.org/Kercy/krcyos.git
# if you prefer github:
# git clone https://github.com/KercyDing/krcyos.git
cd krcyos
# ...
```

### Simply run it
```bash
zig build run
# or:
# zig build run -Dboard=qemu_virt
```

If you have a real board:
```bash
zig build run -Dboard=real_board
```

Then flash to your board.

> That's it. Should be a piece of cake.

## Why not Rust?
Simply put, I prefer Zig over Rust.

For me, Rust isn't explicit enough at the kernel level, even though 90% of my projects are written in Rust :)
