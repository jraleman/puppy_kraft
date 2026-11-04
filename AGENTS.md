# AGENTS.md - Puppy Kraft

This is a Godot 4.7 game folder, hosted two directories above in
`godot-base`. It is not a standalone Godot project. Read `DESIGN.md` and
`TODO.md`; shared guidance lives in `..\..\..\AGENTS.md`.

## Boundaries

- Extend the shared `GameShell` and inherit its scene. The host owns menus,
  settings, pause, results, achievements, store and sharing.
- Keep every game-specific change here. Never add a game-name branch to the host
  or a runtime dependency on another game.
- `puppy_kraft_options.gd` is constants-only and safe to preload before autoloads.
  Advertise only implemented options, inputs and features.
- `sim` is node-free. Advance the body at exactly 60 Hz. Input adapters supply
  plain frames; the 3D view never supplies collision or gameplay decisions.
- Generation depends only on the seed, version and cell coordinates. Preserve
  `PK1` forever when adding later generators.
- Scent indexes use chunk revisions, not mesh dirtiness that remeshing clears.
  Edit terrain through `world_grid.set_block`. Sniff input/state is transient;
  menus cancel it and saves do not latch it.
- Bark frames carry ordered press/release edges, buffered across sub-tick
  render frames. Reset both adapter and model queues around menus/rebinding.
  Charge/tap state is transient; energy, rest delay and Ruff cooldown are not.
- `sim/needs.gd` implements only the bark budget. Missing optional energy/rest/
  cooldown save fields get legacy defaults; present malformed values fail.
  Do not advertise the remaining survival needs or future bark interactions.
- Save only edits against generated terrain. Reject unreadable or newer saves
  explicitly, never replace them with a fresh world. Write a temporary file,
  then rename over the slot; ignore unfinished temporary files when loading.
- Keep three fixed world paths and merge future state without discarding it.
  Do not rename the host's permanent user directory before title clearance.
- Use Compatibility rendering, isolated viewports, batched vertex-coloured
  meshes and a bounded remesh queue. Respect reduced motion and intense effects.

## Validation

From this folder:

```powershell
godot --headless --path ..\.. --import
godot --path ..\.. -- --game=puppy_kraft
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/blocks_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/puppy_body_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/abilities_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/needs_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/audio_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/scent_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/seed_words_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/world_gen_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/world_save_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/puppy_kraft_scene_test.gd -- --game=all
godot --path ..\.. --script res://games/puppy_kraft/tests/world_view_test.gd -- --game=all
```

Run the host's 15 framework suites sequentially in an isolated user profile:
they share settings and progress. Scene tests load gameplay at runtime after
autoloads exist, never preload `GameShell`. Windowed tests require real graphics;
headless success is not proof of rendering, web/mobile performance or playtesting.
There is no separate linter or formatter.

The shared Instructions screen requires a real clip and poster. This game's
`tools/tutorial_driver.gd` records registered inputs through
`res://tools/tutorial_capture.tscn` and validates jumping, climbing, digging both
layers, placement, real sniff trails, all three barks, energy recovery and a
saved diary. Its recorder-only `_set_capture_inset` keeps the real HUD above
the caption card. Never assign poses or edits to fake a take.
Use the shared capture scene directly: the host PowerShell recorder's fixed
game list does not yet include this prototype. Re-record only when the visuals
or captions change.

On Windows, wait for Godot with
`Start-Process -NoNewWindow -Wait -PassThru` and check `.ExitCode`.
