# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

GravGolf is a 3D space golf game built in **Godot 4.6** using GDScript. Players hit a golf ball across procedurally generated planets with custom gravity. The long-term vision includes multiplayer, procedurally generated holes, and a golf cart with 6-axis movement.

## Running the Game

Open the project in the Godot editor and press **F5** (Run Project) or use the editor's play button. There is no CLI build command — all running, testing, and scene editing is done through the Godot editor GUI.

To run the game from the command line (headless or otherwise):
```
godot --path /home/gix/repos/gravgolf
```

## Project Settings

- **Physics engine**: Jolt Physics (3D)
- **Default gravity**: 0 — all gravity is custom/planet-driven
- **Renderer**: Forward Plus, Double Precision
- **Resolution**: 1920×1080, fullscreen (`mode=3`)
- **Git LFS**: `.scn` and `.tscn` files are tracked via Git LFS

## Architecture

### File Layout

- `game.gd` / `game.scn` — root scene; captures mouse, handles pause (Escape key)
- `scenes/` — packed scenes (`.tscn`): `ball`, `planet`, `player`, `craft_racer`, `camera_pivot`
- `scripts/` — GDScript files mirroring the scene hierarchy:
  - `scripts/planet/` — planet generation system
  - `scripts/player/` — player craft and camera

### Planet Generation Pipeline

Planet meshes are built at runtime (and optionally baked) through four cooperating classes:

1. **`PlanetData`** (`scripts/planet/planet_data.gd`) — `Resource` that holds all planet parameters: radius, resolution, noise layers (`PlanetNoise[]`), and biomes (`PlanetBiome[]`). Emits `changed` whenever any nested property mutates so the planet auto-regenerates in the editor.

2. **`PlanetNoise`** (`scripts/planet/planet_noise.gd`) — One noise layer. Supports `use_first_layer_as_mask` so detail layers only appear on land (not oceans).

3. **`PlanetBiome`** (`scripts/planet/planet_biome.gd`) — Maps a latitude range to a `GradientTexture1D`. Biomes are ordered south-to-north by `start_height`.

4. **`PlanetMeshFace`** (`scripts/planet/planet_mesh_face.gd`) — One of 6 cube faces projected onto a sphere. Builds vertex/index arrays, computes smooth normals, uploads a biome texture as shader parameter, and calls `create_trimesh_collision()` for physics. Uses `call_deferred` for mesh updates.

5. **`Planet`** (`scripts/planet/planet.gd`) — `@tool` `StaticBody3D`. Drives regeneration by iterating its `PlanetMeshFace` children. Has a **"Bake Planet"** editor button that duplicates the node, strips generation scripts, and saves a static `.scn` to `assets/baked_planets/`.

The biome texture is a 2D image where each row is one biome's gradient; the shader samples it with `UV = (height_along_gradient, biome_index)`.

### Player

- **`player.gd`** — `RigidBody3D` spaceship. 6-DOF input (pitch/yaw/roll via left stick, throttle via triggers). Applies rotation via `basis.rotated()` in `_process` and thrust in `_integrate_forces`.
- **`camera_pivot.gd`** — Follows the player with slerp-interpolated basis and supports camera pitch from the right stick.

### Ball

`scenes/ball.tscn` — `RigidBody3D` with a `SphereShape3D` (radius 0.1), high bounce (`0.9`), and mass `0.1`. No script yet.

## Input Map (Gamepad)

| Action | Axis |
|---|---|
| `throttle_up` | Right trigger (axis 5) |
| `throttle_down` | Left trigger (axis 4) |
| `yaw_left/right` | Left stick X (axis 0) |
| `pitch_up/down` | Left stick Y (axis 1) |
| `roll_left/right` | Right stick X (axis 2) |
| `camera_pitch_up/down` | Right stick Y (axis 3) |

## Key Patterns

- All planet scripts use `@tool` so the planet regenerates live in the editor when `PlanetData` properties change.
- `PlanetData` and its nested resources connect `changed` signals recursively, so any deeply-nested property change propagates up and triggers full regeneration automatically.
- Mesh and collision updates in `PlanetMeshFace` are deferred (`call_deferred`) to avoid firing mid-physics-step.
- The `StaticBody3D` collision children from `create_trimesh_collision()` are freed before each regeneration to prevent accumulation.

## GDScript Standards

### Static Typing

- **Always use explicit static types.** Every `var`, `@export`, and `@onready` declaration must have an explicit type annotation. Every function parameter and return type must be annotated (use `-> void` for functions that return nothing).
- Use typed array syntax: `Array[TypeName]` not plain `Array` where the element type is known.
- Use packed array types (`PackedVector3Array`, `PackedInt32Array`, etc.) for performance-critical vertex/index data.
- Type loop variables: `for item: Type in collection:`.

### Naming Conventions

| Type | Convention | Example |
|---|---|---|
| File names | snake_case | `yaml_parser.gd` |
| Class names | PascalCase | `class_name YAMLParser` |
| Node names | PascalCase | `Camera3D`, `Player` |
| Functions | snake_case | `func load_level():` |
| Variables | snake_case | `var particle_effect` |
| Signals | snake_case, past tense | `signal door_opened` |
| Constants | CONSTANT_CASE | `const MAX_SPEED = 200` |
| Enum names | PascalCase | `enum Element` |
| Enum members | CONSTANT_CASE | `EARTH, WATER, AIR, FIRE` |

- Prepend a single underscore to private functions and private variables: `var _counter`, `func _recalculate_path():`.
- Convert PascalCase class names to snake_case for file names (e.g., `YAMLParser` → `yaml_parser.gd`).
- Use singular names for enum types. Write each member on its own line.

### Code Order

Organize GDScript files in this sequence:

1. `@tool`, `@icon`, `@static_unload` annotations
2. `class_name`
3. `extends`
4. Documentation comments (`##`)
5. Signals
6. Enums
7. Constants
8. Static variables
9. `@export` variables
10. Regular variables
11. `@onready` variables
12. `_static_init()`
13. Remaining static methods
14. Overridden built-in virtual methods (`_init`, `_enter_tree`, `_ready`, `_process`, `_physics_process`, others)
15. Overridden custom methods
16. Remaining public methods, then private methods
17. Inner classes

Public before private throughout. Properties and signals precede methods. Virtual callbacks precede the class's own interface.

### Formatting

- **Indentation:** Use tabs, not spaces. Each indent level adds one tab beyond the containing block. Continuation lines (line wraps) use two tab levels.
  - Exception: array/dictionary/enum continuation lines use one tab level.
- **Trailing commas:** Add a trailing comma on the last element of multiline arrays, dictionaries, and enums. Omit trailing commas in single-line lists.
- **Blank lines:** Two blank lines between top-level functions and class definitions. One blank line to separate logical sections inside a function.
- **Line length:** Keep lines under 100 characters; aim for under 80 when practical.
- **One statement per line.** No `if condition: statement` on a single line. Ternary operators are the exception.
- **Multiline conditions:** Use parentheses (not backslashes), two indent levels, and place `and`/`or` at the start of continuation lines.
- **Parentheses:** Omit unnecessary parentheses in `if`/`while` conditions.
- **Boolean operators:** Use `and`, `or`, `not` instead of `&&`, `||`, `!`.
- **Whitespace:** One space around operators and after commas. No space between a function name and its `(`. No vertical alignment of assignments with extra spaces.
- **Quotes:** Double quotes by default. Single quotes only when they reduce escapes.
- **Comments:** Start `#` comments with a single space. No space before commented-out code. Prefer comments on their own line over inline; inline comments are fine for short notes.
- **Numbers:** Always include leading and trailing zeros in floats (`0.5` not `.5`, `13.0` not `13.`). Lowercase hex letters (`0xfb8c0b`). Use underscores as separators in large literals (`1_234_567_890`).

### Member and Local Variables

- Don't declare member variables that are only used inside a single method; make them local instead.
- Declare local variables as close as possible to their first use.
