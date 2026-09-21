# Board & Surfacing

Procedural street deck. Named materials only — no stickers, no PBR maps. Beta playable first.

**Derron lock** (skate. board-first silhouette, Zoo York-inspired, no asset copy): black grip, white underside + procedural NY mark, silver trucks, **white wheels oversized + outboard** so four disks read at mid camera.

## Node layout

Player path `player.gd` / `TrickSystem` still use `$MeshPivot/Board` (`MeshInstance3D`).

```
MeshPivot
├── Board          MeshInstance3D (deck BoxMesh 0.52 × 0.04 × 1.28)
│                  script: board_visual.gd — lean/pitch rotate this node
│   ├── DeckUnderside
│   ├── NyNLeft / NyNRight / NyNDiag / NyYStem / NyYArmL / NyYArmR
│   ├── GripTape
│   ├── TruckFront / TruckBack
│   └── WheelFL / WheelFR / WheelBL / WheelBR
├── Rider          hidden capsule lean proxy
└── Emily          stance mesh; feet synced to deck top (`deck_top_y`)
```

Trucks, wheels, grip, and NY mark are children of `Board` so they follow carve lean and air pitch. Collision stays the player capsule — board parts are visual only. Footprint matches the current thin deck so Emily stance / BoardSocket stay valid.

`emily_visual._sync_board_deck()` measures **deck mesh** thickness (`deck_thickness()`, `BoxMesh.size.y`, else mesh AABB — not child wheels or graphics) and places the Board so the top face sits at `deck_top_y`.

`board_visual.gd` rebuilds named children in `_ready`.

## Material roles

Named, separate overrides — nothing shared with Emily. Dark grip vs **white wheels / underside** is the mid-distance pop.

| Part | Role | Read |
|------|------|------|
| Deck top (`Mat_deck_top`) | Dark wood rails under grip | albedo `(0.20, 0.14, 0.10)`, roughness 0.90 |
| Deck underside (`Mat_deck_underside`) | White popsicle | albedo `(0.94, 0.94, 0.96)` |
| NY mark (`Mat_underside_mark`) | Procedural dark NY (box strokes) | albedo `0.08` |
| Grip tape (`Mat_grip`) | Black matte, near-full top | albedo `0.05`, roughness 0.96 |
| Trucks (`Mat_truck`) | Silver / cooler metal | `(0.72, 0.74, 0.78)`, metallic 0.82 |
| Wheels (`Mat_wheel`) | White urethane, four disks | albedo **(0.95, 0.95, 0.97)**, roughness 0.80; radius 0.084 / width 0.092, hung outboard |

Wheels must read as four separate disks at gameplay distance: bright white urethane, ~50%+ larger than the charcoal pass, hung outboard of the hangers (skate. board-first + Derron Zoo York inspiration, no asset copy).

Top is black grip only. Underside NY is primitive box strokes (N + Y), not photoreal stickers / gothic lettering.

## Out of scope

- Photoreal stickers / copied gothic NY lettering
- PBR maps, unique per-wheel materials
- Spark / grind **particles** and SFX (Audio & Juice)
- PropKit, park modules, grind lips, HUD, trick logic
- External GLB for the board
