# Juice Feedback Plan — landing / ollie / grind (v0.1)

Warm Venice daylight mood. Punchy and readable, not neon cyber. Juice follows feel; do not block Squad 1 playable clips.

## Goals

- Make **ollie**, **land**, and **grind** feel weighty with short SFX + camera punch + sparse particles.
- Hook to **future AnimationPlayer signals** once Squad 1 adds skeleton/clips; until then, use physics events already in `player.gd`.
- Stay out of HUD/toast ownership (UI & HUD). Coordinate timing so trick-name toasts and juice land on the same beat when possible.

## Event map

| Event | Fire when (now) | Fire when (clips exist) | SFX placeholder | Camera | Particles |
|-------|-----------------|-------------------------|-----------------|--------|-----------|
| `ollie_pop` | Jump pressed + on floor (`player.gd` jump branch) | `AnimationPlayer` signal `ollie_pop` at pop frame | Short wood/board *tick* + soft whoosh | Tiny upward nudge + 4–6° FOV punch, 60–80 ms | Dust puff at board (sand/concrete tint `#D9C7A0` / `#C8C4BC`) |
| `land_soft` | First frame back on floor, fall speed mild | Signal `land` + impact strength param | Soft thud | Light vertical settle, no shake | Sparse dust ring |
| `land_hard` | On floor after high fall / gap | Same signal, high impact | Deeper thud + short scrape | Hit-stop 30–50 ms + camera shake 0.08–0.14 | Dust + tiny concrete chips (warm gray, not neon) |
| `grind_start` | Enter `grindable` (Squad 1 later) | Signal `grind_lock` | Metal *chirp* | Slight FOV tuck | Sparks along rail (cool metal `#A8ADB2`, low count) |
| `grind_loop` | While grinding | Loop while clip holds | Soft scrape loop (duck under music) | None / micro jitter | Continuous sparse sparks |
| `grind_exit` | Leave grind / ollie out | Signal `grind_exit` | Exit kick + scrape cut | Small kick punch | Spark burst then die |

## Signal contract (for Squad 1)

Emit from AnimationPlayer (or a thin `JuiceBus` Autoload) so juice never reads animation internals:

```
signal juice_event(name: StringName, strength: float, position: Vector3)
```

Names: `ollie_pop`, `land`, `grind_start`, `grind_loop`, `grind_exit`.  
`strength` 0–1 scales SFX volume, shake, and particle count.  
`position` = world contact (board underside / rail point).

Until clips exist: `player.gd` (or a `juice.gd` helper) emits the same signal from physics.

## Camera punch rules

- Own punch on follow cam (`follow_camera.gd`): add `apply_punch(strength, duration)` — offset + FOV only; do not fight follow lerp.
- Max one punch overlapping; harder land wins.
- No color grading flashes, no chromatic aberration, no cyber glows.

## Particles rules

- One shared GPUParticles3D (or CPU) pool under player / world; recycle, do not spawn new systems per trick.
- Colors from style bible: concrete/sand/metal only. No magenta/cyan sparks.
- Cap: ollie ~8–12, soft land ~10, hard land ~18, grind sparks ~6 active.

## SFX placeholders

Paths (create stubs later under `assets/audio/sfx/`):

- `ollie_pop.wav` — short, mid, boardy
- `land_soft.wav` / `land_hard.wav`
- `grind_start.wav` / `grind_loop.ogg` / `grind_exit.wav`

Use `AudioStreamPlayer3D` at board for spatial; keep volumes conservative so HUD toasts stay clear.

## Implementation order

1. **Doc** (this file) + claim — done.
2. `JuiceBus` Autoload + `follow_camera.apply_punch`.
3. Wire `ollie_pop` + floor-land detect in `player.gd` (placeholder beeps OK).
4. Particles for land/ollie with Venice palette.
5. Grind hooks once Squad 1 exposes grindable contact.
6. Retarget emits to AnimationPlayer signals when clips land.

## Out of scope

- Trick state machine guts (Squad 1)
- Park mesh / grindable collision authoring (Squad 2)
- HUD / combo toast visuals (UI & HUD)
- Music bed (later)

## Done when

- Plan exists and Squad 1 knows the `juice_event` names.
- Ollie + land feedback playable with placeholders before final clips.
- Mood matches Art Direction: warm daylight punch, not neon.

## Live hooks (playtest borrow)

Beta: placeholder WAVs at `assets/audio/sfx/ollie_pop.wav` + `land_thud.wav` load onto `SfxOllie`/`SfxLand` at runtime. `sfx_ollie` / `sfx_land(impact)` still emit. Light `FollowCamera.apply_punch` on land. No particles yet.
