# Competitor reference bar (inspiration only — no asset copy)

Living list owned by **Art Direction**. Derron: pull feel + readability from **skate.**, **Session: Skate Sim**, and **Skater XL**. Do not copy meshes, audio, UI, fonts, or branding. Reference weight, camera, park readability, board/rider silhouette, and feedback timing.

Sister note: `docs/reference/session-feel-ref.md` (Session clip Derron called out).

## How to use

1. Watch with the question “what reads at gameplay camera distance?” not “how do we clone this.”
2. Before building a system from vibes, link a clip (+ timestamp if useful) in the PR, commit, or squad chat.
3. Beta bar stays: clean, concise, very playable — refs guide taste, not scope creep.
4. Art owns this link list; Core Feel owns feel notes; World owns layout notes; Board & Surfacing owns deck/wheel read; Audio & Juice owns punch/SFX timing ideas.

---

## Session: Skate Sim

**Tone:** weighty twin-stick sim; land stick; grind lock; satisfying settle. Closer to real skating than arcade.

| Clip | Link | What we take |
|------|------|----------------|
| Derron primary — satisfying Session clips | https://www.youtube.com/watch?v=NfY46Ho_dEo | Board weight, pop→air→land settle, grind lock, camera that sells impact without spam |
| Official launch trailer (Xbox) | https://www.youtube.com/watch?v=M7GL5RG8GsA | Twin-stick weight transfer readability; real-spot plaza scale; muted 90s palette vs neon arcade |
| Skate Core update trailer | https://www.youtube.com/watch?v=DO7A_pyWRdw | Cleaner core trick loops; how small curb/ledge lines stay readable |
| IGN gameplay trailer | https://www.ign.com/videos/session-skate-sim-gameplay-trailer | Grounded motion; avoid THPS float |

**Owners:** Core Feel (Physics / Controller / Tricks), Audio & Juice. Art: silhouette + material restraint (no plastic shine).

**What we do *not* take:** brand gear, map geometry, SFX banks, UI chrome.

---

## skate. (EA / Full Circle)

**Tone:** Flick-It arcade-sim hybrid; city/plaza flow; playful camera; social park energy; rider readable from afar.

| Clip | Link | What we take |
|------|------|----------------|
| Early Access release-date trailer | https://www.youtube.com/watch?v=p14MSdRtNIo | Plaza flow, object readability in a busy city, playful camera energy |
| Season / world vibe (community + official trailers) | https://www.youtube.com/watch?v=-Mi9EKoBCSg | Long lines through mixed street furniture; silhouette pops in daylight |
| Drop-in / world vibe | https://www.youtube.com/watch?v=DeGXanmlJ_0 | Warm outdoor light, crowd/park social read (mood only) |
| EA Early Access announcement | https://news.ea.com/press-releases/press-releases-details/2025/EA-and-Full-Circle-Reveal-September-16-Early-Access-Release-Date-for-skate-/default.aspx | Context for Flick-It + sandbox plaza goals (text, not assets) |

**Owners:** Core Feel (pop/carve readability), World (plaza flow, vertical transitions later), Art (silhouette at distance, sunny readability).

### P0 — Turning & camera (Derron 2026-09-21)
**skate. is the bar for turn + follow cam** (not Session twin-stick weight for this lane).
- Follow cam: behind-board, yaw with velocity/facing (not stuck or orbit-laggy), gentle look-ahead into turns.
- Turning: stick carve feels continuous like Flick-It arcs — responsive at low speed, stable at high; no sudden snap or mushy delay.
- Owners: **Player Controller** (input→facing + cam), **Skate Physics** (carve/yaw coupling). Cite skate. trailers above when tuning `follow_camera.gd` / turn rates in `player.gd`.


**What we do *not* take:** San Vansterdam layout, Flick-It IP, cosmetics, live-ops UI, parkour scope for beta.

---

## Skater XL

**Tone:** analog-stick trick clarity; ledge/rail lines; simple readable parks; board-first camera.

| Clip | Link | What we take |
|------|------|----------------|
| Newest official map / line skating | https://www.youtube.com/watch?v=HK5sBzPsMGc | Park module readability; bank→ledge→rail line flow; board silhouette vs pale concrete |
| Advanced trick timing (tutorial) | https://www.youtube.com/watch?v=YEhAoHyIW7s | Timing windows for named flatground stubs — motion reference only |
| Contest / multi-map lines (community) | https://www.youtube.com/watch?v=-eQ9FPNmDcA | How short 3-trick lines teach a map; keep Mission Flow light |

**Owners:** Tricks & Combos, Park Designer, Board & Surfacing. Art: deck/wheel contrast, rider read against park fills.

**What we do *not* take:** Easy Day maps, mods, stickers, analog-stick IP, store cosmetics.

---

## Cross-game “take” matrix (beta)

| Concern | Lean toward | Avoid |
|---------|-------------|--------|
| Board weight / land | Session settle | Floaty THPS bounce |
| Trick clarity at speed | skate. / XL readable pops | Tiny unreadable flicks |
| Turning + follow camera | **skate.** behind-board carve cam | Session twin-stick / stuck orbit lag |
| Park teaching | XL simple line parks + Venice aerial | Maximalist city clutter |
| Look | Sunny Venice + Emily identity | Neon cyber, muddy gray rider |
| Juice | Session-like impact honesty | Particle carnival |

---

## Rules

1. **Reference ≠ remix.** No ripped models, SFX, fonts, logos, or map geometry.
2. Link a clip when a PR claims a feel/look target.
3. Expanding this doc = Art Direction; feel patches = Core Feel; layout patches = World.
4. Prefer official / clearly public trailers and widely shared gameplay — no paywalled ripped footage dumps in-repo.

## Changelog

- 2026-09-21 — Art Direction: expanded living list (Session / skate. / Skater XL) + take matrix; wired from style bible.
