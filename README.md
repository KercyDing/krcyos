# 🌱 KrcyOS

A toy RISC-V kernel built with Zig for OS exploration.

## Motivation

To understand computer architecture and operating systems.

## Prerequisites

- **Zig** (>=0.16.0)
- **QEMU** (`qemu-system-riscv64` >=11.0.0)
- (you might) **[Only](https://github.com/KercyDing/only)** 

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
```

That's it. Should be a piece of cake.

## Why not Rust?
Simply put, I prefer Zig over Rust. For me, Rust isn't explicit enough at the kernel level, even though 90% of my projects are written in Rust :)
