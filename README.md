# Puppy Kraft

A saved, solo block-world prototype: run, jump, climb, sniff, bark, fetch, dig
and build in a seeded meadow with a very small puppy. This includes the Phase 0 /
Milestones 1-2 foundation and the Milestone 3 sniffing, barking, starter-stick,
day/night, lighting and First Steps slices with basic energy, not the finished
adventure described in [DESIGN.md](DESIGN.md).

## Run

Requires Godot 4.7 and the shared `godot-base` host two directories above this
folder. This repository does not have its own `project.godot`.

From this folder in PowerShell:

```powershell
godot --path ..\.. -- --game=puppy_kraft
```

Choose an empty **Den Door** slot, enter your pup's name and a seed, then make a
world. Blank name means **Pup**; blank seed creates a random world.

## First Steps

New worlds offer five non-blocking prompts: walk four actual cells, dig a
block, reveal a scent trail, bark, then return to the straw bed and confirm
**Call it a day**. Only successful actions during the current prompt count.
The guide uses your current bindings and Hold/Toggle/Tap settings, including
instructions to stop sniffing or drop the stick when needed.

Progress, including partial walking, is saved with the world. **Skip First
Steps** saves its dismissal without changing terrain, materials or abilities.
Failed Skip or final-bed saves keep the lesson active and preserve the previous
file. Older worlds do not receive the guide. Nothing is locked behind it:
there are no tutorial rewards, Sit unlock or full nap/sleep-to-dawn yet.

## Controls

| Action | Keyboard | Solo mouse |
| --- | --- | --- |
| Run | A / D | - |
| Aim / climb roots and ladders | W / S, with movement | Point at a block |
| Jump | Space | - |
| Sniff | Hold L; Hold/Toggle in Settings | - |
| Bark | Hold I and release; Hold/Tap to cycle in Settings | - |
| Carry / drop the stick; throw while running | E | - |
| Dig / use the starting bed | Hold J | Hold left button |
| Place one block | K | Right button |
| Work on the back-wall layer | Hold Shift while digging/placing | Same modifier |
| Previous / next material | Q / R | Wheel |
| Pause | Escape | - |

Keyboard controls are rebindable in the shared Controls tab. Mouse controls are
fixed. Directional reach is 1.5 cells; mouse reach is 3 cells. Most placed blocks
need neighbouring support or a back wall. Roots and ladders can stand freely;
solid front blocks cannot overlap the pup or bury the loose stick. Falls never
cause damage.

The unchanged building bag starts with 12 meadow soil, 8 wood and 12 ladders.
Q/R still cycle building materials, not a mouth wheel. Camera zoom is available
in Settings; reduced motion parks the tail and decorative camera look-ahead.

## Follow your nose

Sniffing drains the world to soft tones while coloured, shaped trails point
through walls: **zigzags and an ORE diamond** lead to crystal or glow moss;
**pawprints and HOME** lead to the starting bed; **dots, a twig and STICK** lead
to your loose toy. The HUD names the strongest scent and its direction,
including back-wall resources. Ordinary grass and building wood do not mask
these points of interest.

Daytime range is 48 cells, doubled to 96 at night. Buried resources within six
cells are outlined. Walk at half speed while sniffing; stop before digging,
barking or using the bed. Sniffing has no energy cost.
The Game tab offers Hold or Toggle, and the Controls tab can rebind L. Menus
cancel the toggle; loading a world never restores held sniff input. Reduced
motion parks the trails and adds static arrows.

This slice uses existing PK1 terrain and preserves old saves. Treasure caches,
quest/other lost-item trails, cave entrances and night-only finds await their
world systems; full survival needs are not implemented yet.

## Play fetch

A starter stick waits beside the bed. Press **E** within 1.5 cells to pick it
up. Press again while stopped to drop it, or get running and press to throw it
in an arc. Release movement first when you want a drop rather than a throw.
Solid front terrain, including leaves, blocks pickup and flight; back walls do not.
Follow the dotted **STICK** scent to retrieve it, even while sniffing.

The mouth HUD shows what you carry and explains refusals. Drop the stick before
digging or placing; taking it home to the bed is allowed. Held, flying and
settled state all survive saving. There is one persistent toy, no recall,
despawning or fetch reward. The four-pick mouth wheel, slotted bag and other
carry items remain future work.

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
**2 energy per second**. Movement, sniffing, digging, placing, barking and carry
input interrupt rest; only Woof and Ruff currently spend energy. There are no
hunger, warmth, happiness or low-energy penalties yet. The bed still closes the outing; full
naps and night skipping remain later work.

## Day, night and cave light

The Game tab offers **Short / Normal / Long** days lasting **12 / 18 / 30 minutes**.
Normal has one minute of dawn, ten of day, one of dusk and six of night;
the other paces scale all four phases proportionally. Changing pace preserves
the current day and exact phase, without changing movement or ability timing.
Menus pause the clock. Dusk gives a six-second, outlined warning to head home,
and every eighth night shows **FULL MOON** with brighter moonlight.

Sky and terrain darken smoothly. Solid front blocks and back walls stop direct
skylight; existing crystal and glow moss light nearby caves. Your small nose
glow follows you even with reduced motion enabled. Digging and building update
affected light fields, including roof shadows. There are no weather effects,
night threats, full-moon events or sleep-to-dawn yet; the bed still ends the
outing rather than skipping the night.

## Worlds and saving

There are three local files: `user://puppy_kraft_world_1.cfg`, `_2.cfg` and
`_3.cfg`, inside the host's Godot user-data directory. **Save world**, dawn
(every 12 / 18 / 30 minutes of simulation at a fixed pace), pause, leaving
gameplay and window close save the latest state. Failed writes are reported
explicitly and preserve the previous
successful file. Unreadable/newer worlds are never silently replaced.

Return to the starting straw bed to **Call it a day**. This saves and closes the
outing before opening the shared diary/results screen. **Keep going** starts a
new outing in the same world, retaining terrain and materials. Quitting an
unfinished outing retains its counters and fixed-step remainder.

Energy, partial rest delay, the remaining bark cooldown and the stick's
position, velocity and carried state are saved, along with the day clock and
First Steps progress.
The current day-length setting applies on load without skipping the saved phase.
Held keys, tap sequences and visual effects are not.
Older format-1 worlds recover their exact Normal clock from play ticks and get
energy/cooldown defaults and the starter stick without losing building materials.
If the bedside spot is occupied, the legacy stick appears at the saved pup.
Missing First Steps data exempts an older world from onboarding.
Malformed new fields are rejected, and unknown additive fields remain intact.
PK1 generation and the save format are unchanged.

Canonical seeds are three friendly compound words plus a number, for example
`SUNNYBISCUIT-GENTLECLOVER-MUDDYBUNNY-42`. Any other text is also accepted and
hashed. Seed words recreate the original PK1 terrain, **not another player's
edits**. Full signed 64-bit seeds round-trip.

## Validation and remaining scope

See [AGENTS.md](AGENTS.md) for test commands and [TODO.md](TODO.md) for gates.
Thirteen headless game suites, the windowed world-view suite and all 15 shared
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
Fetch checks cover pickup, stopped drop, running throws, terrain contact,
building guards, rebound input, moving scent sources and held/in-flight save
round trips. Actual loose/mouth pixels and STICK markers pass all three layouts,
including reduced-motion flight. The 43-second real-input walkthrough adds
throwing, sniffing out the lost stick and carrying it home to the saved diary;
recorder-only clearance keeps its HUD above the lesson card. Imported clip and
poster playback and a normal single-game boot are verified.

Clock checks cover exact cycle lengths, live phase-preserving settings, dusk,
full moons, pause and old-save migration. Lighting checks cover roofs, back
walls, emitter falloff, chunk seams, edit invalidation and bounded caches.
Rendered tests verify actual night/moon/cave/nose pixels, unchanged light fields
on time-only updates, and readable dusk text alongside save errors at all three
layouts.

First Steps checks cover ordered actual actions, blocked/empty inputs,
frame-partition determinism, partial-progress saves, legacy exemption and
malformed snapshots. Live checks cover rebound movement and Carry keys,
immediate mode-specific prompts, pause/reload, saved Skip, and failed Skip/bed
save rollback. Its real HUD clears the shared footer and recorder card at all
three layouts. The refreshed walkthrough observes every lesson and verifies
saved completion without assigning progress.

The desktop view retains at most 35 mesh chunks, remeshes at most two per frame,
prepares at most one cold light field per frame, and uses 7 / 7 / 8 world draw
calls at landscape / portrait / ultrawide. Its light cache holds 35 fields and
254 skylight columns in the fixture.
On an RTX 4090 / OpenGL Compatibility desktop, warmed remeshing averaged
0.66-0.78 ms with a 1.72 ms maximum. Cold light builds averaged 2.09-2.30 ms with
a 4.49 ms maximum, measured separately from meshing and excluding initial
skylight-column discovery. A first cold night sniff took about 79 ms including
lazy generation/indexing; cached queries averaged 1.01 ms. Initial discovery can
therefore hitch, and web/mobile performance remains an open gate.
Fresh and edited saves measured 777 and 1363 bytes respectively.

Gamepad/touch input, full inventory and survival needs, crafting,
weather, sleep-to-dawn, quests, rewards, Pupedia, Pack mode and final art remain
future milestones. Bark-driven villagers, threats, switches and mechanisms
await their world systems; Mighty Howl is not exposed.
Pending-point persistence is present, but adventure points
are not yet earned or paid into a store. Web/mobile profiling, heavily built
save/backup budgets and three-person playtesting are still open.