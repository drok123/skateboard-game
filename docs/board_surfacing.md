# Board & Surfacing

Procedural street deck. Named materials only — no stickers, no PBR maps. Beta playable first.

## Node layout

Player path `player.gd` / `TrickSystem` still use `$MeshPivot/Board` (`MeshInstance3D`).

```
MeshPivot
├── Board          MeshInstance3D (deck BoxMesh 0.52 × 0.04 × 1.28)
│                  script: board_visual.gd — lean/pitch rotate this node
│   ├── DeckUnderside / UndersideNY
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

Named, separate overrides — nothing shared with Emily. Dark grip vs **white wheels / underside** is the mid-distance pop.

| Part | Role | Read |
|------|------|------|
| Deck top (`Mat_deck_top`) | Dark wood rails under grip | albedo `(0.20, 0.14, 0.10)`, roughness 0.90 |
| Deck underside (`Mat_deck_underside`) | White popsicle + dark NY block | albedo `(0.94, 0.94, 0.96)`; mark `0.08` |
| Grip tape (`Mat_grip`) | Dark matte strip on top | albedo `0.07`, roughness 0.96 |
| Center stripe / logo plate (`Mat_stripe`) | Warm cream contrast | `(0.88, 0.82, 0.70)` |
| Logo mark (`Mat_logo_mark`) | Charcoal block on the plate | albedo `0.10` |
| Trucks (`Mat_truck`) | Silver / cooler metal | `(0.62, 0.64, 0.68)`, metallic 0.72 |
| Wheels (`Mat_wheel`) | White urethane, four disks | albedo **(0.95, 0.95, 0.97)**, roughness 0.80; radius 0.082 / width 0.090 |

Wheels must read as four separate disks at gameplay distance: bright white urethane (skate. board-first + Derron Zoo York inspiration, no asset copy), not charcoal.

Top graphic is primitive boxes only (grip + stripe + modest logo block). Not photoreal stickers.

## Out of scope

- Photoreal stickers / gothic NY lettering (simple dark block only)
- PBR maps, unique per-wheel materials
- Spark / grind **particles** and SFX (Audio & Juice)
- PropKit, park modules, grind lips, HUD, trick logic
- External GLB for the board
