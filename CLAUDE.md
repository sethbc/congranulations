# Congranulations

Granular synthesis script for the [monome norns](https://monome.org/docs/norns/) platform.

## Architecture

Norns scripts are bilingual — Lua for UI/control, SuperCollider for audio synthesis.

```
congranulations/
├── congranulations.lua        # Main script (entry point, UI, params, controls)
├── lib/
│   ├── Engine_Congranulations.sc  # SuperCollider granular engine (CroneEngine subclass)
│   └── congranulations_engine.lua # Lua wrapper for engine commands
└── README.md
```

**Main script must match directory name** — `congranulations.lua` in `congranulations/`.

## Key APIs

- `engine.*` — SuperCollider engine commands
- `softcut.*` — 6-voice sample playback/recording (2 mono buffers, 5:49 each)
- `screen.*` — 128x64 OLED display
- `params` — Parameter management and persistence
- `clock` — Timing and sequencing
- `enc(n, d)` / `key(n, z)` — Hardware input (3 encoders, 3 keys)

## Script Lifecycle

```lua
function init() end      -- Setup (load engine, create params, init state)
function key(n, z) end   -- Key press/release (n=1-3, z=0/1)
function enc(n, d) end   -- Encoder turn (n=1-3, d=delta)
function redraw() end    -- Screen draw (called on demand via screen.update)
function cleanup() end   -- Teardown
```

## SuperCollider Engine Pattern

```supercollider
Engine_Congranulations : CroneEngine {
  // SynthDefs, commands, alloc/free
}
```

Engine commands are exposed to Lua via `engine.command_name(args)`.

## Code Style

- Lua 5.3 (norns ships Lua 5.3)
- SuperCollider for engine code
- 2-space indentation
- `snake_case` for Lua variables and functions
- `PascalCase` for SC classes
- Local by default — avoid globals
- Use `include("lib/filename")` (no `.lua` extension) for library imports

## Run

Scripts are installed to `~/dust/code/` on norns and selected from the menu.
For development, use maiden (web IDE) or scp to push files.

## Reference Projects

- [glut](https://github.com/artfwo/glut) — foundational granular engine
- [granchild](https://github.com/schollz/granchild) — granular sequencer
- [mangl](https://github.com/justmat/mangl) — 7-track granular player
