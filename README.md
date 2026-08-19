# Snake Game - x64 Assembly

A classic Snake game written in **x64 Assembly (NASM)** and C using the native Windows API and SDL.

This project is a learning and experimentation project focused on building a complete small game from the ground up without using a game engine.

The goal is to explore low-level Multiplatform development, graphics rendering, input handling, memory management, and game architecture using Assembly language and C.

---
## Compatibility

### Supported on 64-bit Windows, Linux and MacOS 

| Platform | Status |
| --- | --- |
| Windows 11 x64 | ✅ Supported |
| Windows 10 x64 | ✅ Supported |
| Windows 8 x64 | ✅ Supported |
| Windows Vista x64 | ✅ Supported |
| MacOS x64 | ✅ Supported |
| MacOS (M Series) | ✅ Supported (Rosetta 2) |
| Linux x64 | ✅ Supported |

- DirectX June 2010 is required to play the Win32 version of the game; DirectX is available as a separate download on the [releases page](https://github.com/duhsoares21/thesnakegame/releases).
- Windows version available on both Win32 and SDL; SDL Version does not required a separated DirectX Installation.
- Windows 8 and newer officialy supports Xbox One and Xbox Series X|S Controllers; Windows 7 and older officialy supports Xbox 360 Controllers, but drivers might be required;

The game targets the native Windows, MacOS and Linux x64 environment.

---

## About The Game

This is a modern implementation of the classic Snake game.

## Screenshots

### Main Menu
<img width="600" height="630" alt="20260720-0517-04 5567350" src="https://github.com/user-attachments/assets/e2087251-789c-4a74-b0c2-659702706310" />

### Gameplay
<img width="602" height="682" alt="20260720-0519-29 0391815" src="https://github.com/user-attachments/assets/bca193dc-9333-4e3d-bc29-b4010507c1c0" />

Features:

- Classic Snake gameplay
- Main menu system
- Keyboard input support
- Xbox Controller support through XInput (Win32) and Multiple Controllers supported through SDL (All Platforms)
- Score tracking
- Food generation
- Snake growth mechanics
- Speed progression
- HUD rendering
- Double-buffered rendering
- Native Windows window management (Win32) | SDL Window Management (All Platforms)

The game is built as a native Windows (EXE), MacOS (App) and Linux (AppImage) executable with no external dependencies.

---

## Technical Details

### Language

- **x64 Assembly (NASM)**

### Platform

- Windows, MacOS and Linux x64

### APIs Used

- Win32 API
- GDI
- XInput
- Kernel32
- User32
- SDL

### Rendering

The renderer uses:

- GDI device contexts
- Off-screen rendering buffer
- BitBlt-based double buffering
- SDL Renderer

---

## Architecture

The project is divided into a platform-independent game core written in NASM Assembly and a portable platform layer written in C using SDL.

This separation keeps the game logic independent from the operating system while SDL handles platform-specific functionality.

```
SnakeGame
|
├── Assembly Game Core (NASM)
│   ├── Game state machine
│   ├── Snake logic
│   ├── Food system
│   ├── Collision handling
│   ├── Score and game rules
│   └── Game update loop
|
├── Platform Layer (C)
│   ├── SDL initialization
│   ├── Window management
│   ├── Event processing
│   └── Platform abstraction
|
├── Input System
│   ├── Keyboard input
│   └── Game controller input
|
├── Render System
│   ├── SDL rendering
│   ├── Drawing primitives
│   ├── Text rendering
│   └── HUD rendering
|
├── Audio System
│   └── SDL audio and game sounds
|
└── Platform Targets
    ├── Windows x86-64
    ├── Linux x86-64
    └── macOS x86-64
```

The NASM game core does not directly interact with operating-system APIs. Instead, it communicates with the C platform layer through a small platform API.

The C layer acts as the bridge between the Assembly code and SDL, providing portable services for rendering, input, audio, timing, and window management.

As a result, the same Assembly game logic is shared across Windows, Linux, and macOS, with platform-specific differences largely isolated to the build system and ABI boundary.

---

## Requirements

### Minimum Requirements

- Windows Vista x64 or newer
- MacOS x64 (Intel or M Series)
- Linux x64 (AppImage; Tested on Arch)
- x64 compatible processor

No installation is required.
The executable is standalone.

---

## Building From Source

### Requirements

- JetBrains CLion
- SDL
- A C Compiller
- NASM Assembler
- CMake
- Windows SDK (For Windows)
- Xcode command-line tools (MacOS)

---

## Controls

### Keyboard

| Key | Action |
| --- | --- |
| Enter | Start Game |
| Arrow Keys | Move Snake |
| Escape | Pause |

### Xbox Controller

| Button | Action |
| --- | --- |
| Menu | Start Game / Pause |
| D-Pad | Move Snake |

---

## Why Assembly?

Because I like to suffer, yay! Just kidding. 

Assembly is a passion of mine and I always wanted to learn and do something meaningful with it. So there it is.

## Why C? 

Because I needed a separated layer for Multiplatform support not to mix into the game logic and in pure assembly it would be overly and unnecessarily complex. 

---

## License

This project is available for educational purposes.
Feel free to study, modify, and experiment with the source code.
