# Board & Surfacing

Procedural street deck. Named materials only — no stickers, no PBR maps. Beta playable first.

## Node layout

Player path `player.gd` / `TrickSystem` still use `$MeshPivot/Board` (`MeshInstance3D`).

```
MeshPivot
├── Board          MeshInstance3D (deck BoxMesh 0.52 × 0.04 × 1.28)
│                  script: board_visual.gd — lean/pitch rotate this node
│   ├── DeckUnderside
│   ├── GripTape / CenterStripe / LogoBlock / LogoMark
│   ├── TruckFront / TruckBack
│   └── WheelFL / WheelFR / WheelBL / WheelBR
├── Rider          hidden capsule lean proxy
└── Emily          stance mesh; feet synced to deck top (`deck_top_y`)
```

Trucks, wheels, and the top graphic are children of `Board` so they follow carve lean and air pitch. Collision stays the player capsule — board parts are visual only. Footprint matches the current thin deck so Emily stance / BoardSocket stay valid.

`emily_visual._sync_board_deck()` measures **deck mesh** thickness (`deck_thickness()`, `BoxMesh.size.y`, else mesh AABB — not child wheels or graphics) and places the Board so the top face sits at `deck_top_y`.

`board_visual.gd` rebuilds named children in `_ready`.

## Material roles

Named, separate overrides — nothing shared with Emily. Still dark overall vs pale Venice concrete; the **graphic** is the mid-distance pop.

| Part | Role | Read |
|------|------|------|
| Deck top (`Mat_deck_top`) | Dark wood, slightly lighter than underside | albedo `(0.20, 0.14, 0.10)`, roughness 0.90 |
| Deck underside (`Mat_deck_underside`) | Solid dark wood, **no graphics** | albedo `(0.12, 0.08, 0.06)`, roughness 0.92 |
| Grip tape (`Mat_grip`) | Dark matte strip on top | albedo `0.07`, roughness 0.96 |
| Center stripe / logo plate (`Mat_stripe`) | Warm cream contrast | `(0.88, 0.82, 0.70)` |
| Logo mark (`Mat_logo_mark`) | Charcoal block on the plate | albedo `0.10` |
| Trucks (`Mat_truck`) | Cooler metal, lighter than wheels | `(0.50, 0.54, 0.58)`, metallic 0.68 |
| Wheels (`Mat_wheel`) | Dark charcoal rubber, four disks | albedo **0.14**, roughness 0.92 |

Wheels must read as four separate disks at gameplay distance: charcoal, not white, not neon, slightly darker than trucks.

Top graphic is primitive boxes only (grip + stripe + modest logo block). Not photoreal stickers.

## Out of scope

- Underside graphics / brand marks / photoreal stickers
- PBR maps, unique per-wheel materials
- Spark / grind **particles** and SFX (Audio & Juice)
- PropKit, park modules, grind lips, HUD, trick logic
- External GLB for the board
