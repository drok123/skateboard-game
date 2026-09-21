# Skateboard Game (Godot 4)

A Venice Beach skating prototype with momentum-based riding, flatground tricks, rail grinds, and optional session goals. This is a prototype, with procedural animations and simplified collision physics.

## Run

Import `project.godot` in Godot 4.2 or newer and press F5. This improvement pass was tested with Godot 4.7.2. The default renderer is Forward Plus.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Push | W / Up | Left stick up |
| Brake | S / Down | Left stick down |
| Carve | A/D or Left/Right | Left stick left/right |
| Ollie | Space (press) | A / bottom face button |
| Kickflip / heelflip in air | J / K | Right stick right / left |
| Shuv / tre flip in air | O / P | Right stick up / down |
| Frontside / backside 180 | U / I | Keyboard only |
| Return to spawn | R | Back / Select |
| Show/hide controls | H | Keyboard only |
| Pause | Escape | Standard cancel action |

Release push to coast. Steering is relative to the board. Ollies preserve forward momentum; they do not add free speed. After takeoff, make a fresh trick input and leave enough airtime to complete it. Only one named trick can be committed per airtime. Right-stick gestures currently upgrade an ollie; they do not perform the full Skate-style ground pop gesture.

Approach rails near their top and along their length. A sustained grind scores on exit. Consecutive landings build a line multiplier; repeated tricks earn less. Late, uncaught flips reset the line. R resets the rider and line for another attempt.

## Validation

After the editor has imported assets:

```sh
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_camera.gd
```

The gameplay regression checks acceleration, coasting, braking, ollie momentum, landing, combo expiration, committed tricks, incomplete-flip scoring, grind scoring, and actual-grind objective detection. The camera regression checks obstruction, clear following, and teleport recovery.

## Current limits

This pass improves the existing prototype rather than reproducing a commercial game. Full-body 180s, foot/board IK, richer push/catch animations, ragdoll bails, manuals, grabs, a complete stick-gesture control scheme, and deeper transition physics remain future work. The 180 inputs currently animate the board; they are not a full-body spin simulation. A bail currently clears scoring rather than entering a ragdoll state.

See `docs/skate-reference-review.md` for the review, changes, and next priorities.