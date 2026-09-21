# Board & Surfacing

Procedural street deck. Named materials only — no stickers, no PBR maps. Beta playable first.

Art Direction callouts (do not invent a second hue):

## Node layout

Player path `player.gd` / `TrickSystem` still use `$MeshPivot/Board` (`MeshInstance3D`).

```
MeshPivot
├── Board          MeshInstance3D (deck BoxMesh 0.52 × 0.04 × 1.28)
│                  script: board_visual.gd — lean/pitch rotate this node
│   ├── DeckUnderside
│   ├── TruckFront / TruckBack
│   └── WheelFL / WheelFR / WheelBL / WheelBR
├── Rider          hidden capsule lean proxy
└── Emily          stance mesh; feet synced to deck top (`deck_top_y`)
```

Trucks and wheels are children of `Board` so they follow carve lean and air pitch. Collision stays the player capsule — board parts are visual only. Footprint matches the current thin deck so Emily stance / BoardSocket stay valid.

`emily_visual._sync_board_deck()` measures **deck mesh** thickness (`deck_thickness()`, `BoxMesh.size.y`, else mesh AABB — not child wheels) and places the Board so the top face sits at `deck_top_y`.

`board_visual.gd` rebuilds named children in `_ready`.

## Material roles

Named, separate overrides — nothing shared with Emily. Still dark overall vs pale Venice concrete.

| Part | Role | Read |
|------|------|------|
| Deck top (`Mat_deck_top`) | Dark wood, **slightly lighter** than underside (flip orientation) | albedo `(0.20, 0.14, 0.10)`, roughness 0.90 |
| Deck underside (`Mat_deck_underside`) | Solid dark wood, **no graphics** | albedo `(0.12, 0.08, 0.06)`, roughness 0.92 |
| Trucks (`Mat_truck`) | Cooler metal, lighter than wheels | `(0.50, 0.54, 0.58)`, metallic 0.68, roughness 0.42 |
| Wheels (`Mat_wheel`) | Dark charcoal rubber, matte disks | albedo **0.14** (range 0.12–0.18), roughness 0.92 |

Wheels must read as four separate disks at gameplay distance: charcoal, not white, not neon, slightly darker than trucks.

## Park metal (same hue)

PropKit `COLOR_METAL` `#A8ADB2` only — roughness/metallic is the tell, not a second color. No park-module geometry edits.

| Use | Helper | Metallic | Roughness |
|-----|--------|----------|-----------|
| Grindable lips (coping / flatbar / hubba) | `mat_grind_metal()` | **0.78** (higher) | **0.28** (lower) |
| Visual-only rails / legs | `mat_metal_visual()` / `mat_for(COLOR_METAL)` | **0.32** (lower) | **0.62** (higher) |

`add_box` / `add_cylinder` pick grind metal when the body is `grindable` **and** the color is `COLOR_METAL`.

## Out of scope

- Underside graphics / brand marks / stickers
- Photoreal textures, normal maps, unique per-wheel materials
- Spark / grind **particles** and SFX (Audio & Juice)
- Park mesh / collision / `grindable` group membership (World)
- HUD, trick logic
- External GLB for the board
