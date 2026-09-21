# Skateboard Game (Godot 4)

A tiny 3D skate-park prototype: ride a simple skateboarder around ramps, a funbox, and ledges.

## Requirements

- [Godot 4.2+](https://godotengine.org/download) (4.x Forward Plus)

## How to open & play

1. Install Godot 4.x from the official site.
2. Open Godot → **Import** → select this folder’s `project.godot` (or drag the folder onto the Project Manager).
3. Press **F5** (or the Play button) to run the main scene.

## Controls

| Action | Keys |
|--------|------|
| Move / push | **W A S D** or **Arrow keys** |
| Ollie / jump | **Space** |

Camera follows the rider automatically.

## Project layout

```
skateboard-game/
├── project.godot          # Godot 4 project config + input map
├── scenes/
│   ├── main.tscn          # Skate park + lighting + camera
│   └── player.tscn        # Skateboarder capsule + board mesh
├── scripts/
│   ├── main.gd            # Builds park primitives at runtime
│   ├── player.gd          # Movement, ollie, board tilt
│   └── follow_camera.gd   # Smooth third-person follow
├── icon.svg
└── README.md
```

## Notes

- First version uses simple BoxMesh / CapsuleMesh primitives and StaticBody3D collision — no external art assets required.
- Park geometry is spawned in `main.gd` so you can tweak sizes/positions in one place.
