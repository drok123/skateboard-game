# Character Rig — handoff contract (Player Controller / Core Feel)

Owned by **Character Rigging**. Playable path prefers `emily_skater_skinned.glb` (Skin/Hair/Clothing + JOINTS) when present; else stance. Never T-pose.

## Soft secondary — do not fake it

See **[docs/soft-motion-rigging.md](soft-motion-rigging.md)** (Art Direction) and `docs/style-bible.md`.

**Hard rule:** soft secondary motion (hair first, then tasteful soft-body) is **ONLY** after:

1. A live `Skeleton3D` on the playable Emily import, and
2. Material slots for at least **skin / hair / clothing**.

**Never** enable hair springs, soft-body, or jiggle on the unskinned stance GLB. Idle/push AnimationPlayer stubs today are subtle root scale/Y only — not soft secondary.

## Playable / archive assets

| Role | Path | Rule |
|------|------|------|
| **Playable** | `res://assets/characters/emily_skater_stance.glb` | Load this. Narrow stance mesh, upright on board. |
| **T-pose archive** | `res://assets/characters/emily_skater.glb` | Art/rig source only. **Do not load** as playable. |
| **Look ref** | `references/character/emily_venz_look.jpg` | Identity / silhouette |

Runtime loader: `scripts/emily_visual.gd` (`STANCE_GLB` / `TPOSE_GLB` refuse).

## Scenes

| Scene | Path | Notes |
|-------|------|-------|
| **Emily (source of truth)** | `res://scenes/characters/emily.tscn` | Character Rigging-owned. Root `Emily` + `emily_visual.gd` + `BoardSocket`. |
| **Player** | `res://scenes/player.tscn` | Instances Emily under `MeshPivot`. |

## Runtime node paths (Player Controller)

Relative to `Player` (`CharacterBody3D`):

```
Player
├── CollisionShape3D
├── MeshPivot                          ← Physics carve lean (rotation.z)
│   ├── Board                          ← MeshInstance3D deck; Y synced via deck_top_y
│   ├── Rider                          ← lean proxy ONLY; mesh=null, visible=false
│   ├── Emily                          ← instance of scenes/characters/emily.tscn
│   │   ├── EmilyMesh                  ← imported stance GLB root (runtime)
│   │   │   └── [future Skeleton3D]    ← name TBD once skinned export exists
│   │   └── BoardSocket                ← Marker3D at feet/deck contact
│   └── LookTarget
├── PlayerInput
├── AnimationPlayer                    ← TrickClips stubs (idle/push have tracks)
├── TrickSystem
├── SfxOllie
└── SfxLand
```

### Contract names for Controller / Tricks

| Need | Path / name today |
|------|-------------------|
| Character root | `MeshPivot/Emily` |
| Visual mesh | `MeshPivot/Emily/EmilyMesh` |
| Board deck socket | `MeshPivot/Emily/BoardSocket` |
| Lean proxy (hidden) | `MeshPivot/Rider` |
| Board mesh | `MeshPivot/Board` |
| Clip player | `AnimationPlayer` (sibling of `TrickSystem`) |
| Locomotion API | `TrickSystem.play_locomotion("idle"\|"push"\|…)` |

GLB constants (do not diverge):

- Playable: `res://assets/characters/emily_skater_stance.glb`
- Refuse: `res://assets/characters/emily_skater.glb`

## AnimationPlayer stubs (TrickClips)

Created at runtime by `scripts/trick_system.gd` into the Player `AnimationPlayer`.

| Clip | Loop | Tracks today |
|------|------|----------------|
| `idle` | yes | `MeshPivot/Emily:scale` + `position:y` (subtle breathe) |
| `push` | yes | same paths (push squash/sway) |
| `crouch`, `land`, V1 tricks | per `TrickClips.STUB_LENGTHS` | empty library entries; ollie/land/flip also use EmilyMesh Tweens |

Clip names must keep matching `scripts/trick_clips.gd` (`LOCOMOTION` + `V1_TRICKS`).

## Future skinned contract

When Art exports a weighted GLB:

1. Point playable import at the skinned file (or swap `STANCE_GLB` / `skinned_glb_path` after validation).
2. Expect `Skeleton3D` under `EmilyMesh` (exact node name TBD — `emily_visual.gd` already caches via `get_skeleton()`).
3. Prefer `BoneAttachment3D` (or reparent) for board socket → replace `BoardSocket` Marker3D handoff.
4. Prefer character-local or Player `AnimationPlayer` clips authored on bones; keep **TrickClips** names.
5. Material slots: skin, hair, clothing (eyes optional) — then soft motion per `docs/soft-motion-rigging.md`.
6. **No soft secondary until steps 2 + materials land.**

## Explicit non-goals (this milestone)

- Soft hair / soft-body / jiggle on stance mesh
- Fake skeleton or invented bone names
- Loading the white T-pose mannequin as playable
- Blocking Physics lean or TrickSystem score/toast flow

## Risks for Physics lean / TrickSystem

- **Lean:** `player.gd` leans `MeshPivot` + hidden `Rider`. Emily rides under `MeshPivot`, so carve lean still applies. Do not re-parent Emily outside `MeshPivot`.
- **Ollie/land squash:** Physics tweens `MeshPivot.scale`; TrickSystem tweens `EmilyMesh` for trick juice; idle/push animate `MeshPivot/Emily` scale/Y. Nested but intentional — avoid a second idle Tween on `EmilyMesh`.
- **Board Y:** `emily_visual.gd` sets Board Y from `deck_top_y`; Physics pitch/roll on Board rotation only — keep that split.

## Blocked on Art / tools

- Skinned + UV’d Emily export (Blender / DCC not installed on this box)
- Named material slots and hair cards/bones
- Authored trick keyframes on skeleton

Until then: stance-only playable path stays locked.
