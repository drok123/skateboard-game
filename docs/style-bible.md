# Style Bible — skateboard-game (v0.1)

Keep the prototype playable. Art follows feel; do not block Squad 1/2 on polish.

## North star

**Bright Venice Beach skate day.** Warm sun, pale concrete, sand, ocean air, palms. The rider is Emily-coded: athletic, confident, long wavy hair that reads in motion.

References (box paths):
- Character look: `references/character/emily_venz_look.jpg`
- Mesh: `references/character/emily_skater.glb` (single static mesh today — no skin, no clips)
- Park mood: `references/park/venice_beach_skatepark_aerial.jpg`

## World palette

| Role | Hex (approx) | Use |
|------|----------------|-----|
| Concrete base | `#C8C4BC` | Bowls, decks, street pads |
| Concrete cool shadow | `#8E959A` | Bowl interiors, undersides |
| Coping / metal | `#A8ADB2` | Coping rings, rails, fence |
| Sand | `#D9C7A0` | Beach fringe, warm fill light bounce |
| Ocean / sky cool | `#6BA3C2` → `#B8D4E8` | Horizon, ambient sky |
| Palm green | `#3F6B45` | Accents only — vertical punctuation |
| Sun key | warm white ~5500–6500K | Directional from low side for long bowl shadows |

Lighting: one strong key (golden-hour lean OK), soft sky fill, mild AO in bowls so depth reads. Avoid muddy mid-gray overall.

## Skater — Emily match rules

**Lock these (identity):**
1. Athletic lean proportions — slim, toned, long limbs; not bulky, not doll-like.
2. Long wavy hair silhouette — center part, volume at shoulders, length past chest; hair must stay readable in third-person at skate speed.
3. Warm sun-kissed skin; honey/ash blonde with darker roots (not flat platinum).
4. Face vibe: symmetrical, high cheekbones, calm/confident — readable at medium camera distance.

**Translate, don’t photocopy:**
- The look photo is beach/lifestyle. Game outfit should still feel like *her* (athletic, coastal SoCal) but work for skating: mobility, silhouette contrast against concrete, no tiny straps that vanish at distance.
- Prefer high-contrast clothing blocks against pale park (dark top / mid shorts, or similar) so the rider pops in Venice light.
- Board: clean street deck, readable underside graphics optional later; keep first pass simple and dark/wood so it doesn’t fight the rider.

**Materials on `emily_skater.glb` (when Squad 1 imports):**
- Separate material slots ASAP: skin, hair, eyes, clothing, board (do not leave one `material`).
- Skin: slight subsurface / soft specular; avoid plastic shine.
- Hair: opaque cards or thick strands with soft specular; prioritize silhouette over strand count.
- Clothing: matte fabrics; small roughness variation beats noisy normals at this scale.
- Keep texel density modest; prototype first, beauty second.

## Soft secondary motion (post-rig)

Once Core Feel has a skinned rider, add light natural soft motion (athletic / stylish, not exaggerated). Hair sway and subtle body secondary motion only — tasteful, readable at skate speed. Do not ship jiggle before the skeleton exists; materials + silhouette come first.

## Silhouette readability (non-negotiable)

- Rider + board must read as one clear shape against concrete at gameplay camera distance.
- Hair mass is part of the character outline — do not thin it into a noodle.
- Avoid camouflage: no concrete-gray clothing, no sand-colored full fits.
- Motion: carve lean and crouch should change the outline; keep limbs thick enough to track in air tricks.
- Do not add busy accessories that break the outline until core clips land.

## What NOT to do

- Do not photoreal-overbuild materials before the skeleton and trick clips exist.
- Do not dark / rainy / neon night for Venice v0 — stay sunny beach concrete.
- Do not cel-outline or heavy comic stylization unless the user asks; keep lightly stylized realism that matches the refs.
- Do not hide the board under the rider; feet–board contact must stay clear for feel debugging.
- Do not block playable prototypes waiting on final textures.

## Hand-offs

| Owner | Needs from this bible |
|-------|------------------------|
| Squad 1 (Core Feel) | Hair/body silhouette targets; material slot list; board contrast; soft-motion only after skin |
| Squad 2 (World) | Concrete/sand/ocean palette; palm as accent; sunny key light |
| UI & HUD | High-contrast toasts over pale concrete; avoid pale-on-pale |
| Audio & Juice | Warm daylight mood; juice should feel punchy, not cyber-neon |

## Done when

- One-page bible exists (this file).
- Import of `emily_skater.glb` uses named materials aimed at Emily identity.
- Venice blockout lighting matches the sunny palette above without waiting on final art.
