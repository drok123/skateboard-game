# Beta playability checklist

Owner: QA Playtest  
Bar: **clean, concise, very playable** — if it doesn’t feel like skating, it fails.

Re-run this pass when a squad lands work. Failures become concrete bugs filed to the owning squad (via Beta Command / Grok Bot or that squad’s channel).

---

## Pass / fail

| # | Check | Pass when | Own if fail |
|---|--------|-----------|-------------|
| 1 | **Emily visible** | Rider reads as Emily (skinned, not T-pose / capsule / mannequin) in play | Character Rigging · Art Direction |
| 2 | **Push** | Hold move → board builds speed; release coasts with friction that feels like skating | Skate Physics · Player Controller |
| 3 | **Ollie** | Space pops board off ground with readable height; land sticks without rubber-banding | Tricks & Combos · Skate Physics |
| 4 | **Carve** | Turn while rolling tracks the board; bowls / banks hold a carve line | Skate Physics · Player Controller |
| 5 | **Venice flow** | Plaza → snake/flow → clover → stairs reads as one skateable line; no soft-locks or invisible walls that kill speed | Park Designer · Props & Obstacles |
| 6 | **Grindables** | Flatbar / ledge / coping tagged `grindable` accept a grind approach; no stuck rails or phantom collision | Skate Physics · Props & Obstacles |
| 7 | **G1 Warm-up street** | Can clear (or clearly attempt) plaza + flatbar / stairs A hubba; goal never blocks free skate | Mission Flow · Park Designer |
| 8 | **G2 Bowl pump** | Enter snake/flow, exit toward street bank with speed still readable | Mission Flow · Park Designer |
| 9 | **G3 Hero loop** | Bank → snake → clover full carve; lip near SE palms reachable | Mission Flow · Park Designer |
| 10 | **G4 Stair gap** | Approach stairs B with speed, clear gap, land flat (no early step land) | Mission Flow · Park Designer |
| 11 | **HUD toast** | One goal line + short hint; clear shows a brief next/free-skate toast; readable on Venice concrete | UI & HUD |
| 12 | **Crash-free 5 min** | Continuous session ≥5 min: push, ollie, carve, at least one grind attempt, goal advance or free skate — no hard crash, freeze, or soft-lock | All (note last action + scene) |

---

## How to run

1. Open `project.godot` in Godot 4.x → Play (`F5`).
2. Spawn west entrance; skate without forcing goals first, then walk G1→G4.
3. Mark each row **pass** / **fail**. Failures only: one sentence repro + expected + owning squad.
4. File bugs through Beta Command / Grok Bot (or the squad channel). Keep titles concrete (“G2 exit loses all speed into street bank”, not “feel bad”).

## Out of scope this beta

Career, unlocks, strict trick-name detection, combo meters, multiplayer.
