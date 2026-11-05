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
- Pup and stick share `world_grid.move_box_axis` for sub-cell movement.
  Compare its result with a Vector2-rounded destination, not a scalar double:
  float32 rounding must not look like a collision and zero normal velocity.
- Generation depends only on the seed, version and cell coordinates. Preserve
  `PK1` forever when adding later generators.
- Scent indexes use chunk revisions, not mesh dirtiness that remeshing clears.
  Edit terrain through `world_grid.set_block`. Sniff input/state is transient;
  menus cancel it and saves do not latch it. Moving stick sources refresh even
  without terrain edits; project each source's exact `position`, not its cell.
- Bark frames carry ordered press/release edges, buffered across sub-tick
  render frames. Reset both adapter and model queues around menus/rebinding.
  Charge/tap state is transient; energy, rest delay and Ruff cooldown are not.
- Carry buffers a press across sub-tick frames and ignores key echo. Reset
  adapter/model queues around menus/rebinding without turning a held key into
  a new press. Cancellation must not drop, move or stop the persistent toy.
- `sim/fetch_stick.gd` owns one toy, not a general inventory. Drop it before
  digging/placing; bed use and sniff pickup remain allowed. Q/R and the packed
  building bag are unchanged. Motion remains essential under reduced motion.
- `sim/needs.gd` implements only the bark budget. Missing optional energy/rest/
  cooldown save fields get legacy defaults; present malformed values fail.
  Do not advertise the remaining survival needs or future bark interactions.
- Save only edits against generated terrain. Reject unreadable or newer saves
  explicitly, never replace them with a fresh world. Write a temporary file,
  then rename over the slot; ignore unfinished temporary files when loading.
- Keep three fixed world paths and merge future state without discarding it.
  Do not rename the host's permanent user directory before title clearance.
- Missing `[world] stick` gives old saves the bedside gift (or the saved pup's
  clear position if occupied). Present malformed state fails. Held sticks
  reanchor to the loaded pup and cannot have independent saved velocity.
- `sim/day_cycle.gd` uses integer phase units at 60 Hz. Pace changes preserve
  phase/day; physical `world.ticks` remain independent. Missing `[world] clock`
  migrates from legacy Normal ticks; present snapshots must match the header day.
  Keep format 1 and PK1 unchanged. Apply the current setting on load, not a time skip.
- Lighting is derived, never saved. Column and halo-chunk revisions invalidate
  static fields even after mesh cleaning. Keep mesh light versions so another
  reader cannot consume an invalidation before the view remeshes.
- Terrain vertex alpha is metadata: sky in the high nibble, block/nose in the
  low nibble. Preserve it through greedy merging; the shader does not use it as
  opacity. Time changes update one uniform, not every light field or mesh.
- Rebuild at most two meshes and one cold light field per frame. Actor/stick
  illumination samples current cached fields only; do not bypass that budget
  from `present`. Moving nose light remains essential under reduced motion.
- `sim/first_steps.gd` tracks only actual actions in the current ordered prompt,
  never held inputs or retroactive credit. Walking uses actual horizontal travel.
  Menus/new outings do not reset it; no ability, reward or inventory is gated.
- Missing `[world] first_steps` exempts an old world; malformed present data
  fails. Keep format 1/PK1 unchanged. Skip and final HOME completion must roll
  progress back on failed saves; HOME completes only after the bed diary saves.
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
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/day_cycle_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/lighting_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/audio_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/scent_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/first_steps_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/seed_words_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/world_gen_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/world_save_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/puppy_kraft/tests/puppy_kraft_scene_test.gd -- --game=all
godot --path ..\.. --script res://games/puppy_kraft/tests/world_view_test.gd -- --game=all
```

There are 14 game suites: 13 headless and the windowed world-view suite.
Run the host's 15 framework suites sequentially in an isolated user profile:
they share settings and progress. Scene tests load gameplay at runtime after
autoloads exist, never preload `GameShell`. Windowed tests require real graphics;
headless success is not proof of rendering, web/mobile performance or playtesting.
There is no separate linter or formatter.

The shared Instructions screen requires a real clip and poster. This game's
`tools/tutorial_driver.gd` records registered inputs through
`res://tools/tutorial_capture.tscn` and validates jumping, climbing, digging both
layers, placement, real sniff trails, all three barks, energy recovery, stick
pickup/drop/throw/retrieval, all five actual First Steps stages and a saved
completed guide/carried-stick diary/clock. It uses Normal
pace and actual dawn lighting, not an assigned night or fake moon.
The 43-second take's
recorder-only `_set_capture_inset` keeps the real HUD above the caption card.
It may shrink the view below its ordinary minimum to honor that clearance;
clearing the inset restores normal gameplay layout.
Never assign poses or edits to fake a take.
Use the shared capture scene directly: the host PowerShell recorder's fixed
game list does not yet include this prototype. Re-record only when the visuals
or captions change.

On Windows, wait for Godot with
`Start-Process -NoNewWindow -Wait -PassThru` and check `.ExitCode`.
