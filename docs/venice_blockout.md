# Venice Beach Skatepark — Blockout Spec (Park Designer)

Reference aerial: `references/park/venice_beach_skatepark_aerial.jpg`  
Repo: https://github.com/drok123/skateboard-game  
Owner: Park Designer · Coordinates with Props & Obstacles + Mission Flow

## Goal

Replace the tiny procedural park in `scripts/main.gd` with a **readable Venice-inspired blockout**: bowls + street, coping, stairs/ledges/rails, palm planters, perimeter. Teach movement through **flow lines**, not decoration. Primitives / CSG OK for v1.

## Scale (from people + perimeter in the aerial)

| Cue | Real-world read | Game unit (meters) |
|-----|-----------------|--------------------|
| Adult standing at rail | ~1.7 m tall | 1.7 |
| Perimeter wall + rail | ~waist–chest (~1.1–1.3 m) | **wall 1.1**, rail 0.2 on top |
| Palm trunk height (visual) | tall beach palms | decorative cylinders ~8–12 m |
| Overall park footprint | real park ~40–50 m across | **playable pad 48 × 40** (X × Z) |
| Deck / flat height | top of bowls | **Y = 0** deck |
| Bowl floor | deep pools below deck | **Y = −2.4 to −3.2** (clover deepest) |

**Player spawn:** street flat near south entrance, facing north (+Z) into the park: `(-6, 1.2, -16)`.

Compress slightly vs real Venice so a single camera follow stays readable; keep relative proportions of bowls vs street.

## North / orientation (in-game map)

Camera-friendly top-down (**Z+ = north**). Remap vs Derron aerials: **bowls NORTH, street SOUTH**.

```
                    Z+  (north — bowl cluster)
    ┌──────────────────────────────────────────┐
    │  PERIMETER WALL + RAIL (all sides)       │
    │                                          │
    │  SNAKE BOWLS (NW/N)     ★ CLOVER (NE)    │
    │     hips + shallow         deep hero     │
    │                                          │
    │         bank street → bowls (z ≈ 0)      │
    │                      ○ palm cluster (E)  │
    │                                          │
    │  W STREET PLAZA (south)              E   │
    │  [A] [B] [ManualPad] [ledge] [flatbar]   │
    │  [bank2 SW]  [Ledge2 SE]    ○ ○ palms SE │
    │                                          │
    └──────────────────────────────────────────┘
                    Z−  (south — street / entrance)
         Entrance gap on south near spawn (−6, −16)
```

## Zones

### A — Perimeter & sand apron
- Low concrete wall ring matching kidney/organic outline (v1: rounded rect or 8–12 segment polygon is fine).
- Thin metal rail on top (thin boxes or cylinders) — **not grindable** in v1 (visual only) so players don’t leave the park on a rail grind.
- Outside wall: wide sand apron (~12 m beyond walls) + thin OOB berm just outside wall — do not bury the deck (kill volume / soft reset later).

### B — Street plaza (south)
Teach: push, carve, ollie onto ledges, stair gaps, flatbar grind approaches.

| Piece | Approx size (m) | Notes |
|-------|-----------------|-------|
| Flat deck | continuous with park | light grey concrete |
| Stairs A (3-set) | 3.0 wide × 3 risers × 0.18 | + parallel hubba ledge |
| Stairs B (4–5 set) | 3.5 wide | + handrail (metal) down one side |
| Long ledge / planter | 6–8 × 0.45 × 0.55 | grindable top edge |
| Flatbar | 5 × 0.12 × 0.12 @ 0.45 high | grindable |
| Small bank / QP | 4 wide, ~1.2 high, ~30° | feeds back to flat |
| ManualPad *(extra)* | 3.5 × 2.2 × 0.28 | mid plaza, grind lip |
| Ledge2 *(extra)* | 5.0 × 0.4 × 0.5 | SE street line |
| StreetBank2 *(extra)* | 3.5 wide, ~1.0 high | far SW turnaround |

**Aerial density (beta):** Cap new plaza extras at **2 ledges/pads + 1 bank**. Prefer readable gaps over filling every flat. SessionFlow names stay: `StairsA`, `StairsB`, `LongLedge`, `Flatbar`.

**Sand apron:** Wide beach plane (~12 m beyond walls) + thin OOB sand berm just outside perimeter — do not bury the deck lip.

**North bowls:** Still `_place_simple_bowl` only (no `bowl_segment` shards, no coping spam). Third smaller snake pocket NW; clover radius slightly larger; transfer banks `PlazaToSnakeBank` / `SnakeToCloverBank` / `CloverHip` widened for silhouette.

### Competitor readability (inspiration only — no level copy)

Layout taste for plaza lines (see `docs/reference/competitor-feel-look.md`):
- **skate.** plaza/city flow: https://www.youtube.com/watch?v=-Mi9EKoBCSg (Season 1) — clear plaza lines readable at distance
- **Skater XL** park lines: https://www.youtube.com/watch?v=HK5sBzPsMGc — simple ledge/rail teaching lines, readable parks

Beta leans **XL-simple teaching lines + Venice aerial geometry** — avoid maximalist city clutter. Aerials in `docs/reference/venice/` stay primary for Venice shapes.

### C — Flow / snake bowls (north)
Teach: pump, carve walls, hip transfers, keep speed without ollie.

- 2–3 linked kidney/oval depressions, depth **−1.6 to −2.2**.
- Transitions: use rotated boxes / CSG torus slices / stacked wedges approximating quarter-pipes.
- Hips where walls meet — leave a clear transfer line toward the clover.

### D — Clover / peanut bowl (northeast)
Hero feature. Teach: drop-in, full carve loops, coping rides (when grind exists).

- Irregular peanut / rounded clover footprint ~12 × 10 m.
- Depth **−3.0** floor, coping dark metal ring on deck lip (**grindable** group).
- 1–2 shallow “hips” toward snake bowls for line continuity.

### E — Palm planters
- **East:** one raised circular planter (~3 m radius) with 4–5 palm trunks (collision on planter curb only).
- **Southeast street edge:** three separate circular planters, one palm each.
- Planter curbs = low ledges (optional light grind).

## Teach lines (for Mission Flow)

1. **Warm-up street:** spawn → push across plaza → ollie flatbar → land → stairs hubba.
2. **Bowl pump:** drop snake → carve two hips → exit to street bank.
3. **Hero loop:** street bank → snake → transfer into clover → full carve → lip out near SE palms.
4. **Stair gap:** approach stairs B with speed from QP, clear the set, land flat.

## Godot scene breakdown

```
res://scenes/parks/venice_beach.tscn          # root park (instance into Main)
res://scenes/parks/modules/                   # Props owns these later
  bowl_segment.tscn
  coping_edge.tscn
  stairs_set.tscn
  ledge.tscn
  flatbar.tscn
  manual_pad.tscn
  planter_round.tscn
  perimeter_wall.tscn
  bank_qp.tscn
res://scripts/parks/venice_beach.gd           # optional: zone markers, spawn points
res://docs/venice_blockout.md                 # this file
```

**Main wiring**
- `main.tscn` instances `venice_beach.tscn` under `$Park` (or replace `_build_park()` with a call that instances the packed scene).
- Keep `WorldEnvironment` beach-sky tint; sun from aerial’s late-day angle (long shadows toward +X/+Z-ish).
- Groups: `grindable`, `coping`, `deck`, `bowl`, `out_of_bounds`.

**Collision rules (v1)**
- All ride surfaces: `StaticBody3D` + shapes.
- Coping / ledge tops / flatbar: thin collision + `grindable` group for Physics later.
- Bowl interiors: prefer continuous collision (CSG or many wedges) — no invisible walls inside the bowl.

**Materials (temp)** — live in `PropKit` from style bible
- Deck: pale concrete `#C8C4BC`
- Bowl cool: `#8E959A`
- Coping/rails: metal `#A8ADB2`
- Sand: `#D9C7A0`
- Palm frond accent: `#3F6B45`
- Planter soil: darker brown

## Props kit request (Props & Obstacles)

Build modular, collision-friendly primitives first:
1. `stairs_set` (param: step_count, width)
2. `ledge` / `hubba`
3. `flatbar`
4. `bank_qp`
5. `coping_edge` (segment length)
6. `bowl_segment` (arc angle, radius, depth) — even fake with wedges
7. `planter_round` + palm trunk mesh
8. `perimeter_wall` segment

## Out of scope (this pass)

- Exact real-world survey mesh
- Character / animations (Squad 1)
- Final art pass / graffiti (Squad 3)
- Heavy career meta (Mission Flow keeps goals light)

## Done when

- Venice zones readable from aerial comparison (bowls N, street S, palms, perimeter).
- Player can push street, drop a bowl, and return without falling through.
- Spawn + camera stay inside bounds.
- Grindable edges tagged for Physics.

## QA readability (post-8f83c61 fail)
- Bowls: **dark pit cylinders + 4 inward BankQp transitions** (no vertical wall-slab rings).
- Two snake bowls + one clover only; no hip filler boxes.
- Orange sand apron vs cream deck; berm strips removed (read as edge slabs).
- Fewer perimeter segments (`seg` 12 m) to cut white wall spam.
