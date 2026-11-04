# Puppy Kraft

A saved, solo block-world prototype: run, jump, climb, dig and build in a seeded
meadow with a very small puppy. This is the Phase 0 / Milestones 1-2 playable
spike, not the finished adventure described in [DESIGN.md](DESIGN.md).

## Run

Requires Godot 4.7 and the shared `godot-base` host two directories above this
folder. This repository does not have its own `project.godot`.

From this folder in PowerShell:

```powershell
godot --path ..\.. -- --game=puppy_kraft
```

Choose an empty **Den Door** slot, enter your pup's name and a seed, then make a
world. Blank name means **Pup**; blank seed creates a random world.

## Controls

| Action | Keyboard | Solo mouse |
| --- | --- | --- |
| Run | A / D | - |
| Aim / climb roots and ladders | W / S, with movement | Point at a block |
| Jump | Space | - |
| Dig / use the starting bed | Hold J | Hold left button |
| Place one block | K | Right button |
| Work on the back-wall layer | Hold Shift while digging/placing | Same modifier |
| Previous / next material | Q / R | Wheel |
| Pause | Escape | - |

Keyboard controls are rebindable in the shared Controls tab. Mouse controls are
fixed. Directional reach is 1.5 cells; mouse reach is 3 cells. Most placed blocks
need neighbouring support or a back wall. Roots and ladders can stand freely;
front blocks cannot overlap the pup. Falls never cause damage.

The building bag starts with 12 meadow soil, 8 wood and 12 ladders. Camera zoom
is available in Settings; reduced motion parks the tail and decorative camera
look-ahead.

## Worlds and saving

There are three local files: `user://puppy_kraft_world_1.cfg`, `_2.cfg` and
`_3.cfg`, inside the host's Godot user-data directory. **Save world**, dawn
(every 18 minutes of simulation), pause, leaving gameplay and window close save
the latest state. Failed writes are reported explicitly and preserve the previous
successful file. Unreadable/newer worlds are never silently replaced.

Return to the starting straw bed to **Call it a day**. This saves and closes the
outing before opening the shared diary/results screen. **Keep going** starts a
new outing in the same world, retaining terrain and materials. Quitting an
unfinished outing retains its counters and fixed-step remainder.

Canonical seeds are three friendly compound words plus a number, for example
`SUNNYBISCUIT-GENTLECLOVER-MUDDYBUNNY-42`. Any other text is also accepted and
hashed. Seed words recreate the original PK1 terrain, **not another player's
edits**. Full signed 64-bit seeds round-trip.

## Validation and remaining scope

See [AGENTS.md](AGENTS.md) for test commands and [TODO.md](TODO.md) for gates.
Seven headless game suites, the windowed world-view suite and all 15 shared
framework suites pass on Godot 4.7.2 / Windows. Scene checks also pass windowed;
window-close saving survives a separate verification process. Tests use an
isolated user profile rather than the developer's progress.

The desktop view retains at most 35 mesh chunks, remeshes at most two per frame,
and uses 6-7 draw calls. On an RTX 4090 / OpenGL Compatibility test desktop,
warmed remeshing averaged 0.559 ms with a 1.143 ms maximum. A fresh save measured
545 bytes; the edited fixture measured 1117 bytes. These are smoke measurements,
not evidence of mid-laptop, web or phone performance.

Gamepad/touch input, full inventory and needs, sniffing/barking/crafting,
day/night visuals, quests, rewards, Pupedia, Pack mode and final art remain
future milestones. Pending-point persistence is present, but adventure points
are not yet earned or paid into a store. Web/mobile profiling, heavily built
save/backup budgets and three-person playtesting are still open.