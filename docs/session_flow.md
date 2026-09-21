# Venice session flow (v1 — light)

Owner: Mission Flow · Coordinates with Park Designer (zones) + Props (tagged props) · Depends on Squad 1 skate feel

## Intent

One session = skate Venice and learn its lines. No career, unlocks, or menus beyond start / retry / done. Goals are optional prompts that teach movement; ignore them and free-skate is always fine.

## Session loop

1. **Spawn** south street entrance (`SpawnPoint` facing north/+Z into plaza).
2. **Active goal** (one at a time) — soft objective, not a gate.
3. **Checkpoint** = player did the named action in the right zone (zone marker + optional prop group).
4. **Clear** → brief HUD ping → next goal, or free skate if last.
5. **Bail / OOB** → soft reset to last spawn or zone start; no score wipe for v1.

Fail is cheap. Never soft-lock.

## Goals (map to teach lines)

| ID | Name | Teach | Success (v1) | Zone / props |
|----|------|-------|--------------|--------------|
| G1 | Warm-up | push / grind | Slide or near plaza `Flatbar` / `StairsA` hubba / `Ledge` (not planter/coping) | Street plaza |
| G2 | Bowl pump | pump / carve | Dwell snake ≥1s, exit to street at ≥3.5 speed | Flow bowls W |
| G3 | Hero loop | transfer + carve | Visited snake, dwell clover ≥1.8s | Clover SE |
| G4 | Stair gap | speed + air | Arm in `zone_stairs_b` at ≥4.5, land outside with speed | Stairs B |

Order: G1 → G2 → G3 → G4. Skipping allowed; HUD can show “free skate” after any clear.

## Detection (wired in `scripts/session_flow.gd`)

- Zone `Area3D` markers from Park Designer: `zone_street`, `zone_snake`, `zone_clover`, `zone_stairs_b`.
- Prop groups already planned: `grindable`, `coping`, `bowl`, `deck`.
- v1 success can be **zone enter + time in zone** or **grindable contact**; don’t wait on perfect trick events until Squad 1 feels good.
- Stair gap: enter approach volume with min speed, then land in flat volume past stairs without step collision.

## HUD (ask UI & HUD when ready)

- One line: current goal name + short hint (“grind the flatbar”).
- Clear → “Nice — next: Bowl pump” (2 s).
- No combo meters or star ratings in this pass.

## Out of scope (this pass)

- Career / XP / unlocks / multiplayer
- Strict trick name detection
- Timed heat / police / fatigue
- Blocking goals that force a line

## Done when

- Doc matches Park Designer’s four teach lines.
- Each goal names a zone + one clear success signal.
- `SessionFlow` node boots from `main.gd`; HUD shows one objective line.
- Zone Area3Ds use `collision_mask = 2` (player layer). Soft clears only — no gates.

## Playtest notes

- Skip / free skate: goals never block movement; clearing advances the HUD line.
- Grind contact prefers slide collisions on `grindable`; street proximity fallback while Squad 1 grind feel catches up.

## Beta pass

- HUD copy shortened (title — one action).
- G1 ignores planter/coping; plaza grind props only.
- G2/G3/G4 thresholds eased slightly for reliable clears without sticky clover.
