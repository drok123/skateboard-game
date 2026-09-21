# Props & Obstacles — Modular Kit

Scenes: `res://scenes/parks/modules/*.tscn`  
Scripts: `res://scripts/parks/modules/*.gd`  
Shared helper: `PropKit` (`prop_kit.gd`)

Metal is one hue (`COLOR_METAL` `#A8ADB2`). Grindable lips use `mat_grind_metal()` (metallic 0.78 / roughness 0.28); visual-only rails stay `mat_metal_visual()` (metallic 0.32 / roughness 0.62). See `docs/board_surfacing.md`.

## Street (place first)
| Scene | Defaults | Groups |
|-------|----------|--------|
| `stairs_set` | 3 steps × 3 m wide, optional hubba + handrail | `deck`, hubba lip `grindable` |
| `ledge` | 7 × 0.45 × 0.55; `is_hubba` for taller | `deck` + top `grindable` |
| `flatbar` | 5 m @ 0.45 high | `grindable` |
| `bank_qp` | 4 m wide, 1.2 m, 30° | `deck` |

## Bowl / perimeter
| Scene | Defaults | Groups |
|-------|----------|--------|
| `coping_edge` | 2 m segment | `deck`, `coping`, metal `grindable` |
| `bowl_segment` | r=5, depth=2.4, 90° arc, 8 slices | `bowl`, `deck` |
| `planter_round` | r=1.5 curb + palms | curb `deck`/`grindable` |
| `perimeter_wall` | 4 m × 1.1 m, rail **not** grindable by default | `deck` |

Instance, set `@export`s, rotate/position. Collision is StaticBody3D boxes/cylinders built in `_ready()`.
