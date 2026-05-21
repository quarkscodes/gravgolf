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
