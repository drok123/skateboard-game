# Soft secondary motion — notes for Character Rigging

Source of truth also in `docs/style-bible.md`. Beta rule: **materials + silhouette first; soft motion only after a skinned Emily.**

## Goal

Athletic / stylish natural secondary motion — readable at skate camera distance. Not exaggerated, not comedic.

## When to enable

1. Stance/T-pose replaced by skinned Emily with AnimationPlayer clips.
2. Material slots exist: at least skin, hair, clothing (eyes optional).
3. Playable silhouette already pops on pale Venice concrete.

## Priority order

1. **Hair** — long wavy mass must sway on carve lean, ollie pop, and land. Keep volume (center part, shoulder width); never thin into a noodle. Prefer bones/spring bones or a few hair colliders over dense cloth.
2. **Soft body (tasteful)** — light chest / soft-tissue secondary only if it stays athletic and subtle under sportswear. Cap amplitude; damp hard on land impacts.
3. **Clothing** — optional later (hem / strap). Skip until hair is good.

## Amplitude / feel

| Event | Hair | Soft body |
|-------|------|-----------|
| Push / carve | Small follow lag | Minimal |
| Ollie pop | Upward settle then fall | Tiny |
| Land soft | Quick damp | Near zero |
| Land hard | Short settle, no bounce loop | Clamp |

No autonomous idle bounce that fights the stance pose.

## Do not

- Ship soft motion on the unskinned single-mesh stance GLB.
- Exaggerate for “juice” — Audio & Juice owns punch/particles.
- Let soft motion break foot–board contact or silhouette readability.
- Use neon / wet-look shaders for soft regions.

## Handoff paths

- Look ref: `references/character/emily_venz_look.jpg`
- Playable visual: `scripts/emily_visual.gd` → `assets/characters/emily_skater_stance.glb`
- T-pose source (rig only): `assets/characters/emily_skater.glb` — never the playable mesh
- Style bible: `docs/style-bible.md`
