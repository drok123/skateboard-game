# Skateboard Game (Godot 4)

A Venice Beach skating prototype with momentum-based riding, flatground tricks, rail grinds, and optional session goals. This is a prototype, with procedural animations and simplified collision physics.

## Run

Import `project.godot` in Godot 4.2 or newer and press F5. This improvement pass was tested with Godot 4.7.2. The default renderer is Forward Plus.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Push | W / Up | X / west face button |
| Brake / reverse | S / Down | B / east face button or left trigger |
| Carve | A/D or Left/Right | Left stick left/right |
| Ollie | Space (press) | A / bottom face button |
| Kickflip / heelflip in air | J / K | Right stick right / left |
| Shuv / tre flip in air | O / P | Right stick up / down |
| Frontside / backside 180 | U / I | Keyboard only |
| Return to spawn | R | Back / Select |
| Show/hide controls | H | Keyboard only |
| Pause | Escape | Standard cancel action |

Tap push for one strong foot stroke or hold it for repeated strokes; release it to coast. Steering is relative to the board and becomes more stable at speed. Hold brake to stop, then continue holding to roll backward at walking pace. Ollies preserve forward momentum; they do not add free speed. After takeoff, make a fresh trick input and leave enough airtime to complete it. Only one named trick can be committed per airtime. Right-stick gestures currently upgrade an ollie; they do not perform the full Skate-style ground pop gesture.

Approach rails near their top and along their length. A sustained grind scores on exit. Consecutive landings build a line multiplier; repeated tricks earn less. Late, uncaught flips reset the line. R resets the rider and line for another attempt.

## Validation

After the editor has imported assets:

```sh
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_camera.gd
godot --headless --path . --script tools/test_emily_animation.gd
godot --headless --path . --script tools/test_venice_park.gd
```

The suites cover push cadence, coasting, braking/reverse, ollie momentum, landing, tricks, grind scoring, camera obstruction, the 18-bone rider poses and foot contact, Venice surface depths, landmarks, and mission zones.

## Current limits

This pass improves the existing prototype rather than reproducing a commercial game. Emily now has procedural bone-level cruise, push, carve, pop, tuck, catch, land and grind motion plus deck foot IK. Her source GLB has only 18 bones, no toes and crude proximity weights, so deformation remains more rigid than a production character. Full-body 180s, ragdoll bails, manuals, grabs, a complete ground-to-air stick gesture system and deeper transition physics remain future work.

The animation timing, control ideas and continuous Venice surface were adapted from the user's private `drok123/skater-test` repository. No commercial animation clips or extracted game assets are included.

See `docs/skate-reference-review.md` for the review, changes, and next priorities.
