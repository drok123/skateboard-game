# Props & Obstacles — Modular Kit

Scenes: `res://scenes/parks/modules/*.tscn`  
Scripts: `res://scripts/parks/modules/*.gd`  
Shared helper: `PropKit` (`prop_kit.gd`)

## Street (place first)
| Scene | Defaults | Groups |
|-------|----------|--------|
| `stairs_set` | 3 steps × 3 m wide, optional hubba + handrail | `deck`, hubba lip `grindable` |
| `ledge` | 7 × 0.45 × 0.55; `is_hubba` for taller | `deck` + top `grindable` |
| `flatbar` | 5 m @ 0.45 high | `grindable` |
| `manual_pad` | 3.5×2.2×0.28 low pad; optional lip | `deck` + lip `grindable` |
| `bank_qp` | 4 m wide, 1.2 m, 30° | `deck` |

## Bowl / perimeter
| Scene | Defaults | Groups |
|-------|----------|--------|
| `coping_edge` | 2 m segment | `deck`, `coping`, metal `grindable` |
| `bowl_segment` | r=5, depth=2.4, 90° arc, 8 slices | `bowl`, `deck` |
| `planter_round` | r=1.5 curb + palms | curb `deck`/`grindable` |
| `perimeter_wall` | 4 m × 1.1 m, rail **not** grindable by default | `deck` |

Instance, set `@export`s, rotate/position. Collision is StaticBody3D boxes/cylinders built in `_ready()`.
