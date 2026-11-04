# Puppy Kraft

A saved, solo block-world prototype: run, jump, climb, sniff, bark, dig and build
in a seeded meadow with a very small puppy. This includes the Phase 0 /
Milestones 1-2 foundation and the Milestone 3 sniffing/barking slices with basic
energy, not the finished adventure described in [DESIGN.md](DESIGN.md).

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
| Sniff | Hold L; Hold/Toggle in Settings | - |
| Bark | Hold I and release; Hold/Tap to cycle in Settings | - |
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

## Follow your nose

Sniffing drains the world to soft tones while coloured, shaped trails point
through walls: **zigzags and an ORE diamond** lead to crystal or glow moss;
**pawprints and HOME** lead to the starting bed. The HUD names the strongest
scent and its direction, including back-wall resources. Ordinary grass and
building wood do not mask these points of interest.

Daytime range is 48 cells, doubled to 96 during the saved clock's six-minute
night. Buried resources within six cells are outlined. Walk at half speed while
sniffing; stop before digging, barking or using the bed. Sniffing has no energy cost.
The Game tab offers Hold or Toggle, and the Controls tab can rebind L. Menus
cancel the toggle; loading a world never restores held sniff input. Reduced
motion parks the trails and adds static arrows.

This slice uses existing PK1 terrain and preserves old saves. Treasure caches,
quest/lost-item trails, cave entrances and night-only finds await their world
systems; night lighting and full survival needs are not implemented yet.

## Find your bark

Hold **I**, watch the numbered pips, then release: a quick **Yip** reaches four
cells and is free; **Woof** takes 0.5 seconds, reaches seven cells and costs
3 energy; **Ruff** takes 1.2 seconds, reaches ten cells and costs 8 energy.
Ruff starts a one-second bark cooldown. Insufficient energy refuses the chosen
strength with a caption; it never silently downgrades.

The Game tab also offers **Tap to cycle**: tap once, twice or three times,
then pause **0.6 seconds** to fire. Another tap restarts that pause; a fourth
cycles back to Yip. The key is rebindable. Sniffing, menus, rebinding and control
mode changes cancel unfinished charges without refunding real costs or
clearing the cooldown.

Woof and Ruff gather front-layer leaves within range. Foliage does not shield
other leaves, but other solid blocks stop the bark; back walls remain intact.
This adds real building materials, not dig counts or adventure rewards.
Original synthesized cues have captions and sound-wave rings. Reduced motion
uses static rings with opacity-only fading; intense effects off softens them.

The basic energy budget is **100**. After one grounded, inactive second, recover
**2 energy per second**. Movement, sniffing, digging, placing and barking interrupt
rest; only Woof and Ruff currently spend energy. There are no hunger, warmth,
happiness or low-energy penalties yet. The bed still closes the outing; full
naps and night skipping remain later work.

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

Energy, partial rest delay and the remaining bark cooldown are saved. Held keys,
tap sequences and visual effects are not. Existing format-1 worlds load with
100 energy and no cooldown; malformed new fields are rejected, and unknown
additive fields remain intact. PK1 generation and the save format are unchanged.

Canonical seeds are three friendly compound words plus a number, for example
`SUNNYBISCUIT-GENTLECLOVER-MUDDYBUNNY-42`. Any other text is also accepted and
hashed. Seed words recreate the original PK1 terrain, **not another player's
edits**. Full signed 64-bit seeds round-trip.

## Validation and remaining scope

See [AGENTS.md](AGENTS.md) for test commands and [TODO.md](TODO.md) for gates.
Ten headless game suites, the windowed world-view suite and all 15 shared
framework suites pass on Godot 4.7.2 / Windows. Scene checks also pass windowed;
window-close saving survives a separate verification process. Tests use an
isolated user profile rather than the developer's progress.

Sniffing checks cover finding and collecting a buried resource, live rebinding
and Hold/Toggle changes, menu cancellation, edited-source invalidation and
unchanged PK1 generation. Rendered composites at landscape, portrait and
ultrawide verify desaturation, through-wall ore markers and parked
reduced-motion pixels. Bark checks cover thresholds, rapid taps, costs, resting,
cooldowns, real leaf collection, legacy saves and live modal/settings changes.
Rendered tests check expanding/static rings and the bounded feedback queue.
The 34-second real-input walkthrough includes sniffing, all three barks and
energy recovery; recorder-only clearance keeps its HUD above the lesson card.

The desktop view retains at most 35 mesh chunks, remeshes at most two per frame,
and uses six 3D world draw calls in the tested shots. On an RTX 4090 / OpenGL
Compatibility desktop, warmed remeshing averaged 0.543 ms with a 1.027 ms maximum.
A first cold night sniff took about 81 ms including lazy generation/indexing;
cached queries averaged 1.02 ms. Initial discovery can therefore hitch, and
web/mobile performance remains an open gate. Fresh and edited saves measured
600 and 1172 bytes respectively.

Gamepad/touch input, full inventory and survival needs, crafting,
day/night visuals, quests, rewards, Pupedia, Pack mode and final art remain
future milestones. Bark-driven villagers, threats, switches and mechanisms
await their world systems; Mighty Howl is not exposed.
Pending-point persistence is present, but adventure points
are not yet earned or paid into a store. Web/mobile profiling, heavily built
save/backup budgets and three-person playtesting are still open.