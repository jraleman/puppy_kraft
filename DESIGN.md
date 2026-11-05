# Puppy Kraft — Game Design Document

> Hand-off document for the implementation session. It fixes the concept, the
> rules, the architecture and the order of work. Numbers marked *(tune)* are
> starting points, not contracts. Read the repository's `AGENTS.md` first — the
> framework/game boundary there overrides anything here that seems to conflict.
> This document describes the **full game** and marks the **v1 slice** that
> ships first (§1.5). Anything marked *(verify)* must be checked with the owner
> before it reaches a model, a recording or player-facing copy (§19).

| | |
| --- | --- |
| Game ID | `puppy_kraft` |
| Title | Puppy Kraft *(confirm before it is locked into `custom_user_dir_name` — §19.1)* |
| Folder | `godot-base/games/puppy_kraft/` (its own Git repository, `jraleman/puppy_kraft`, intended to become a submodule) |
| Control style | `GameManifest.CONTROL_STYLE_CUSTOM_KEYS` |
| Round rules | Game-owned (`uses_shell_round_rules = false`) |
| Players | Solo; same-screen couch co-op "Pack mode" for 2–3 pups, played simultaneously (`max_local_players = 3`, **not** turns) |
| Menu order | `13` (after Tifo Beato's planned `12`) |
| Feature tag | `puppy_kraft` |
| Model reference | `games/cube_trials/` (node-free fixed-step model under a real 3D view) |
| Look-and-feel reference | `games/cube_trials/`, `games/chicken_pit/`, `games/creep_code/` (toy-like 3D in a `SubViewport` under the 2D shell) |
| Renderer | `gl_compatibility` — unchanged |

**Current implementation scope.** The owner chose Phase 0 plus Milestones 1-2,
then the Milestone 3 sniffing, barking, starter-stick, day/night, lighting and
First Steps slices with basic energy: a playable, saved meadow spike, keyboard
and mouse first. Players name their pup at world creation; blank means **Pup**.
The implementation includes movement,
digging/placement, PK1 seeds, three world slots, autosaving, a building HUD and
a procedural 3D view, sniff trails for existing crystal/glow-moss deposits
and the starting bed, Yip/Woof/Ruff with a saved bark-energy budget, and one
persistent fetch toy with a lost-stick scent. Saved, phase-preserving 12/18/30-minute
days drive dawn autosaves, dusk warnings, eighth-night moonlight, sky/terrain
lighting, crystal/glow-moss emitters and the moving nose glow.
New worlds offer five saved, non-blocking onboarding prompts; older worlds
are exempt and Skip never gates an ability.
The owner chose to keep the
existing building bag rather than introduce the full inventory/mouth wheel.
It does not yet implement the full adventure, Pad/Touch,
Pupedia, progression or reward payouts. See `TODO.md` for verified checks and
still-open hardware/playtest gates.

---

## 1. Concept

You are one very small puppy with a very big destiny. You have a stick, a
wagging tail and no idea how anything works.

**Puppy Kraft** is a cosy-epic **side-on block sandbox**. The world is a seeded
grid of chunky toy blocks, seen from the side like a diorama cut in half:
sunny meadows on top, then roots and clay, then glowing crystal caverns far
below. You dig, sniff, bark, fetch, jump, swim and carry things in your mouth.
You gather blocks and build a den that feels like home. Friendly animals move
in next door, and you follow the scent of the legendary **Bone Fragments**
through temples of the First Dog. Along the way you grow from a wobbly newborn
into the **Guardian of the Realm**.

### 1.1 Locked pillars

1. **Every discovery is a quest; every shelter is a home.** Wherever you go,
   something is buried, half-hidden or sniffable, and every den you build
   changes how the game plays (spawn point, warmth, neighbours, safety).
2. **Danger is real, never cruel.** Threats can chase you home, but nothing
   dies and nothing bleeds. Enemies get *shooed*, bosses get *befriended*,
   and defeat is a dramatic retreat and a groggy wake-up at your den (§5.2).
3. **A puppy plays like a puppy.** There are no swords and no menus full of
   numbers. Your verbs are dog verbs: dig, sniff, bark, fetch, carry. Crafting
   happens with paw gestures (§6.3), not crafting grids.
4. **Honest, deterministic world.** The grid, generation, creatures and needs
   are a node-free model in `sim/` (§14.2). The same seed always generates the
   same world. Saves store only what you changed. Headless tests cover all of it.
5. **Readable at a glance, on any screen.** A side-on grid at a fixed 2.5D
   camera reads on a phone, a laptop and an ultrawide alike, with the same
   rules everywhere.
6. **Same studio look.** A real, toy-like 3D world of felt, wood and painted
   blocks sits in an isolated viewport, driven by the model and filmed from
   the side, under the shared HUD.

### 1.2 Why side-on

The pitch reads like a 3D voxel game, but a full 3D voxel world means chunk
meshing in three axes, a free camera, LOD and memory budgets that web and
mobile builds on `gl_compatibility` cannot afford. A side-on grid keeps
everything the pitch cares about: digging down into caves, building tall
lookout kennels, bridges, tunnels, biomes and sky islands. It also keeps the
model 2D, cheap and testable. Depth comes from the art: full 3D blocks, a
recessed background wall layer, parallax scenery and real lighting (§11).

### 1.3 Look and tone

Grand and heroic, always cute. Sweeping skies, glowing ruins, a huge moon over
the meadow at night, and fearsome threats that turn out to be fluffy. The
camera sees the world at puppy height. The music swells (§10.4), the puppy's
ears flop, and a boss's entrance is a proper event with a title card. The
humour is gentle. A raccoon bandit wears a tiny mask and tiptoes, and the
Mailman King has a crown made of stamps.

### 1.4 Story (for the intro cards and `instructions_rules`)

Five short cards, using the same intro shape as the other games:

1. Long ago, the First Dog kept the realm safe with the Spirit of the Pack.
2. Then the Spirit shattered into seven Bone Fragments, scattered to the
   corners of the world. The pack's lost spirits became shadows in the fog.
3. One morning, in a meadow, a puppy wakes up with a stick, a wagging tail
   and a funny feeling in their nose.
4. Something out there smells… important.
5. Dig. Sniff. Build. Be brave. — **Go, pup!**

### 1.5 Full vision and the v1 slice

The full game is large. v1 ships a **complete, polished slice** that already
holds the whole loop. Later milestones add content to it, not systems (§18).

| | v1 slice | Full game |
| --- | --- | --- |
| Biomes | Sunny Meadows, Whispering Forest, Crystal Caverns | + Snowy Peaks, Sandy Desert, Floating Sky Islands, Flooded Ruins (7) |
| Bone Fragments | 3 of 7 (Root Temple, Mailman King, Crystal Vault) | 7; restoring all of them is the finale |
| Temples | Root Temple, Crystal Vault | + Sandglass Temple, Sunken Temple |
| Bosses | The Mailman King | + the Thunder Tomcat, the Cavern Wyrm |
| Threats | Raccoon bandits, grumpy storm clouds, shadow wolves, cave chills | + one or two per new biome (§5.3) |
| Villagers | Cat blacksmith, rabbit chef, bird postal service | + tortoise lorekeeper, sheep weaver and others |
| Vehicles and pets | — | Minecart, leaf boat, kite; duck and baby dragon pets |
| Breeds | Mixed pup, Corgi, Beagle, Husky, Greyhound | Same, plus seasonal fur |
| Growth | Newborn → Pup → Junior (Guardian needs all 7 fragments) | All four stages |
| Seasonal events | Moonlit howl nights | + Snowball festival, Harvest fetch-off |
| Co-op | Pack mode, 2–3 pups, one screen | Same |

The v1 ending: three pillars of the Pack Shrine glow, the shadow wolves near
your den turn friendly, and the trail of the fourth fragment glows into the
distance. It is not a dead end. The world stays fully playable as a sandbox.

---

## 2. Core loop

```
Title ─► Play ─► Mode select (Solo / Pack · breed per seat on the plinth)
     ─► Instructions ─► Den Door: pick a world slot, or make a new world (seed words)
     ─► (new world only) First steps: wobble, dig, sniff, bark, nap — five prompts
     ─► OUTING
          wake in the den ─► needs check (hunger, energy, warmth, happiness)
          ─► explore: sniff a trail ─► dig ─► gather ─► carry it home
          ─► build and craft at home ─► neighbours, quests, garden
          ─► dusk: light up, head home, or go treasure hunting in the fog
          ─► temple / boss / fragment when you're ready
          ─► retreat (if it goes wrong) ─► groggy wake-up at the den
     ─► CALL IT A DAY: nap in a bed and choose "Call it a day"
          ─► Day's Diary (results) ─► Kibble payout ─► autosave
          ─► Keep going (new outing, same world) / Title
     ─► Photo mode / Share card / Store / Gallery / Pupedia
```

### 2.1 The outing is the shell round

A sandbox has no natural end, so this game decides what a shell round is:

- **A round is one outing.** It starts when the pup wakes up in the world and
  ends when the player naps in a bed and chooses **Call it a day**. The shell's
  results panel then shows the **Day's Diary** (§12.4): discoveries, blocks dug
  and placed, Pawprints earned (§9.1), fragments, and the session's highlight.
- `_round_totals` reports the outing's **Adventure points** (§12.2) as the
  integer score, and the shell banks the Kibble payout from it.
- **Quitting never loses anything.** Pause → Quit autosaves the world. Any
  Adventure points not yet paid out are stored in the world file and paid at
  the next Call it a day *(verify that the shell's quit path lets the game
  save in time — §15)*.
- **No countdown.** `_begin_first_round` opens straight into the world with a
  wake-up animation, not a 3-2-1.
- Retreat (§5.2) does **not** end the round. It is part of the outing.

### 2.2 Session shape

A typical outing lasts **20–60 minutes** *(tune)*, about one to three in-game
days (§3.7). A short phone session can call it a day after five minutes and
still see a diary and a payout. The v1 story takes **6–10 hours** *(tune)*.
The sandbox has no end.

### 2.3 Implemented First Steps — `sim/first_steps.gd`, `ui/first_steps.gd`

The current prototype teaches **Wobble → Dig → Sniff → Bark → Home** during
ordinary play, not a separate tutorial level. Walk four cumulative horizontal
cells, remove one block, reveal a real scent trail, emit any successful bark
(a free Yip is enough), then confirm the saved bed diary. Held input against
a wall, empty digs, suppressed/rejected barks and cancelled charges do not
count. Earlier actions remain available but are not credited retroactively.

The HUD follows current rebound keys and Hold/Toggle/Tap settings immediately.
It explains active sniff and carried-stick blockers without changing those
mechanics. Menus and new outings do not reset progress. Skip persists a
dismissal without changing terrain, inventory or ability access. Failed Skip
and final-bed writes restore progress; the last prompt completes only after
the outing is saved successfully. This slice grants no rewards or tricks and
does not implement Sit, a full nap or sleep-to-dawn.

---

## 3. The block world

### 3.1 Grid and blocks — `sim/blocks.gd`, `sim/chunk.gd`, `sim/world_grid.gd`

The world is a 2D grid of cells, each **0.5 m** across in the view *(tune)*.
Each cell holds two layers:

| Layer | Purpose |
| --- | --- |
| **Front** | Solid blocks you stand on, dig and place; fluids live here too |
| **Back wall** | The recessed wall behind, a darker layer. It makes a room "indoors" (§6.2), blocks skylight and keeps rain out. You can dig it and place it |

The grid is split into **32 × 32 chunks** *(tune)*, stored as
`PackedInt32Array` per layer with a dirty flag per chunk. The block registry
is constant data. Each block declares:

| Field | Example |
| --- | --- |
| `id`, `title` | `meadow_soil`, "Meadow soil" |
| `hardness` | `soft` / `firm` / `stone` / `crystal` / `ancient` (§6.4) |
| `drops` | Itself, another item, or a weighted table (buried treasure) |
| `light` | 0–15 emitted (glow moss 6, lantern 14, crystal 9) *(tune)* |
| `flags` | `solid`, `climbable`, `falls` (sand, snow), `slippery` (ice), `fluid_source`, `placeable_back`, `unbreakable` |
| `warmth` | Positive near hearths, negative for ice |
| `scent` | What sniff-vision says about it, if anything (§4.4) |

The world is **finite and wide**. v1 worlds are **1536 × 320** cells *(tune)*,
48 × 10 chunks. The full game adds **Large** worlds at **3072 × 384**
*(tune)* once the extra biomes exist. The edges are sea cliffs (west) and a
mountain wall (east) in v1. Sea level sits at row 100 from the top.

### 3.2 Generation — `sim/world_gen/`

Generation runs in **two passes**, so a new world starts instantly:

1. **Layout (eager, about 50 ms):** from the seed, decide the biome bands
   left to right, the surface height curve's control points, the depth of the
   cavern layer, and every **structure site**: dens of the starting kennel,
   villages, temples, the boss arena, the Pack Shrine, fragment vaults and
   treasure caches. The layout is stored in memory and is tiny.
2. **Chunk fill (lazy):** a chunk is generated the first time it is needed.
   It reads the layout, samples seeded noise for terrain, caves and ore veins,
   and stamps in any structure that overlaps it. A chunk depends only on the
   seed, the layout and its own coordinates. It never depends on neighbouring
   chunks having been generated first.

Structures are **hand-authored templates** in `sim/world_gen/structure_templates.gd`,
placed by the generator but never generated from free noise, like Capitan's
Walk's route chunks. Each template declares its size, its anchor (surface,
cavern, floating), its blocks, its loot slots and its scent markers.

The generator must obey these rules, and `world_gen_test.gd` checks them over
many seeds:

- The spawn meadow is flat enough to build on, within 40 cells of the world centre.
- The Pack Shrine is within 60 cells of spawn, and the starting kennel is
  next to it (§6.2).
- A path to every fragment exists for a pup with that fragment's required
  tricks (§9.2). The test walks a coarse reachability graph.
- No temple overlaps another structure. Every loot slot is reachable.
- Buried treasure density is at least one cache per 24 surface columns
  *(tune)*, so sniff-vision always has something to find nearby.

**Generator versions are permanent.** Every world file records the generator
version that made it. When later milestones add biomes, the new generator gets
a new version, and **old worlds keep generating with the old one** forever, so
an unexplored chunk of an existing save never changes under the player. New
biomes appear in new worlds.

### 3.3 Biomes

Biomes are bands across the surface, plus the cavern layer underneath and the
sky layer above. Each has blocks, music stems, ambient creatures, threats,
weather and a signature find.

| Biome | v1 | Where | Blocks and feel | Threats | Signature |
| --- | --- | --- | --- | --- | --- |
| **Sunny Meadows** | ✔ | Centre surface, spawn | Soft soil, flowers, ponds, gentle hills; warm by day | Raccoon bandits at night, grumpy storm clouds | The Pack Shrine; Post Office Ruins (the Mailman King) |
| **Whispering Forest** | ✔ | East of the meadow | Giant roots, hollow trees, mushrooms, glow moss; quiet and shady | Raccoon bandits (their camps), shadow wolves in the fog | The Root Temple, under a great tree |
| **Crystal Caverns** | ✔ | Underground, under every surface biome from row 160 | Stone, crystal clusters, underground pools; dark without light | Crystal mites, cave chills (cold, slippery pockets) | The Crystal Vault |
| **Snowy Peaks** | | East edge, tall | Snow (falls), packed snow, ice; cold | Snowball yetis (they throw), ice caves | The Cloud Kennel stairs |
| **Sandy Desert** | | West of the meadow | Sand (falls), sandstone, cactus; hot by day, freezing at night | Dust devils, sneaky sand moles | The Sandglass Temple |
| **Floating Sky Islands** | | Above the peaks and meadow, rows 10–40 | Cloud blocks (bouncy), sky stone; windy | Sky gulls (steal from your mouth), storm clouds | The Cloud Kennel (the Thunder Tomcat) |
| **Flooded Ruins** | | West coast, half underwater | Old bricks, kelp, sunken pillars | Grumpy crabs, eel currents | The Sunken Temple |

The **Deep Hollow** sits at the very bottom of the caverns in the full game
and holds the Cavern Wyrm (§7.3).

### 3.4 Structures

| Structure | Biome | Contents |
| --- | --- | --- |
| **Starting kennel** | Meadow | A tiny ruined den beside the Pack Shrine: a straw bed, a water bowl, a chew mat. It is the first den (§6.2) |
| **Pack Shrine** | Meadow | Seven stone pillars around an altar. A fragment returned to the altar lights its pillar (§7.1) |
| **Abandoned dens** | Any surface | Small rooms with loot and a sniffable "home" scent; easy first finds |
| **Raccoon camps** | Forest | Tents of stolen goods. Bark them away to get the loot back |
| **Buried caches** | Everywhere | 1–3 cells of loot under the surface; only sniff-vision shows them |
| **Ruins of the First Dog** | Any | Glowing broken arches with a bark switch, a mural (Pupedia lore) and a cache |
| **Temples** | Per biome | §7.2 |
| **Boss arenas** | Per boss | §7.3; built from `unbreakable` ancient stone, so a fight can't be cheesed by digging |

### 3.5 Fluids and falling blocks — `sim/fluids.gd`

- **Water** is a simple cellular automaton: each cell holds a level from 0 to 8.
  It flows down, then sideways, and only in **active chunks** near a pup
  (§17), capped at 2000 cell updates per tick *(tune)*. Chunks that settle go
  idle. Ponds, underground pools and the Flooded Ruins use it. Swimming
  (§4.3) needs it.
- There is **no lava**. Deep "hot springs" warm you instead (warmth +, §5.1).
- Blocks with the `falls` flag (sand, snow, gravel) drop when unsupported,
  one cell per tick, and land as blocks. A falling block never hurts the pup.
  It nudges them aside.

### 3.6 Light — `sim/lighting.gd`

Light lives in the model, not in Godot lights, so `gl_compatibility` never
needs dozens of dynamic lights:

- **Skylight** shines down every column until it hits a solid front block or a back
  wall, scaled by the time of day (§3.7).
- **Block light** flood-fills from emitters (lanterns, crystals, glow moss),
  losing one level per cell, 0–15.
- An edit invalidates affected nearby fields and roof shadows below it, not
  the entire world. The view bakes light into the
  chunk meshes' **vertex colours**, so night falls without one extra draw call.
- The pup has a soft **nose glow**, light 3 *(tune)*, so a pitch-black cave is
  never totally unreadable.

Light matters to gameplay: threats never spawn on cells with light ≥ 8, and a
den needs light (§6.2).

**Implemented slice.** Existing crystal emits level 9 and glow moss level 6;
lanterns, dens and threat spawning are not present yet. Static 32-cell fields
use a 15-cell halo, cached skylight cutoffs and terrain revisions. Front solids
and every non-air back tile block direct sky; ordinary light diffuses through
front air. Cutaway solid faces sample neighbouring light. Vertex alpha packs
separate sky/local nibbles, allowing a Compatibility shader to change daylight
without rebuilding fields or meshes. The view retains at most 35 fields, rebuilds
at most one cold field and two meshes per frame, and samples cached actor illumination
without bypassing that budget. Level-three nose light is a separate moving
overlay; reduced motion does not freeze it.

### 3.7 Day, night and weather — `sim/day_cycle.gd`, `sim/weather.gd`

| Phase | Default length *(tune)* | What changes |
| --- | --- | --- |
| Dawn | 1 min | Autosave; crops grow; villagers wake |
| Day | 10 min | Explore and build; weather rolls once |
| Dusk | 1 min | Caption "The sun is setting — time to head home?" |
| Night | 6 min | Glowing creatures, spooky fog, shadow wolves, raccoon raids. **Treasure scents are twice as strong**, and night-only finds appear (moon flowers, star bones) |

A full day lasts 18 minutes by default. The tunable offers Short (12),
Normal (18) and Long (30). Sleeping in a bed at night skips to dawn.

Every eighth night is a **full moon**: a moonlit howl night (§9.4).

Weather rolls once per day per biome: clear, breezy, rain (puddles, warmth
drain, crops watered) or **storm** (grumpy storm clouds, §5.3). Weather is
seeded from the world seed and the day number, so it is deterministic.

**Implemented slice.** All four phases and pace choices work; phase lengths
scale proportionally. Integer phase units preserve exact phase/day on a live
pace change, independently of physical play ticks. The six-second dusk warning
does not replace save-error feedback. Each eighth night has a **FULL MOON**
header and brighter lighting, not a literal moon mesh or howl event. Dawn
starts at the preceding night's brightness. Weather, crops, villagers,
night-only finds, threats and sleeping through the night remain future work.

### 3.8 World slots, saves and seeds — `sim/world_save.gd`, `sim/seed_words.gd`

- **Three world slots**, as fixed files, because `save_files` declares fixed
  paths: `user://puppy_kraft_world_1.cfg`, `_2.cfg` and `_3.cfg`.
- A world file is a `ConfigFile` with a **header** (format version, generator
  version, seed, seed words, world size, created date, play time, day number,
  pending Adventure points), the **pups' state** (position, needs, bag,
  gear, growth, tricks), **world state** (NPCs, friendship, quests, farm plots,
  dens, fragments, boss states, shrine) and **chunk deltas**.
- A chunk delta stores only the cells that differ from what the generator
  would produce, run-length encoded and compressed with
  `PackedByteArray.compress()`. A world you've barely touched is a few KB. A
  heavily built one should stay under **2 MB** *(tune, verify against the
  Saves backup path — §15)*.
- Writes are **atomic**: write to `…_world_n.tmp`, then rename. A crash
  mid-save never corrupts a world.
- Autosave at every dawn, after a retreat, at Call it a day, and on
  pause → quit and window close.
- The **Pupedia** (§10.5) is global across worlds, in
  `user://puppy_kraft_pupedia.cfg`.

The implemented format-1 `[world] clock` snapshot saves day, integer phase and
pace. A missing snapshot migrates exactly from legacy Normal ticks; a malformed
or header-inconsistent snapshot is rejected. Gameplay applies the current global
pace setting on load while preserving the saved day and phase. Lighting remains
derived and is not stored. No format or PK1 generator bump is required.

The optional `[world] first_steps` snapshot stores an integer prompt (0–5)
and finite cumulative walking distance (0–4 cells). MOVE requires less than
four; later prompts require exactly four. Partial progress resumes on load.
A missing snapshot marks an older world exempt; malformed present data fails
explicitly. Completed, skipped and legacy-exempt worlds all use DONE.

**Seed words.** A seed is shown and typed as three friendly compound words plus a
number, such as `SUNNYBISCUIT-GENTLECLOVER-MUDDYBUNNY-42`, from a fixed list of 1024
words (32 prefixes × 32 nouns in PK1). Preserve the word ordering once saves
exist. Words map to a signed 64-bit integer. Any typed string is also accepted
and hashed, so "my dog's birthday" is a valid seed. The share card (§12.4)
prints the seed words and the generator version (`PK1`), so a friend can
make the same world.

---

## 4. The puppy

### 4.1 Body — `sim/puppy_body.gd`

The pup is an **axis-aligned box** moving through the grid at a fixed
**60 Hz** step with an accumulator *(tune)*. It is `RefCounted` and touches no
node or autoload. Godot's physics server is **not** used, so the movement is
deterministic and the headless tests can import it.

| Property | Base *(tune)* | Notes |
| --- | --- | --- |
| Size | 0.9 × 0.8 cells | Fits a **one-cell tunnel** at every growth stage. Burrows are part of the fantasy |
| Run speed | 6 cells/s | Breeds scale it (§9.3) |
| Jump | 2.2 cells high | Clears two blocks. Coyote time 0.1 s and a jump buffer of 0.12 s |
| Fall | No fall damage | Ever. A long fall ends in a comic "splat" pose and a puff, nothing more |
| Swim | 3 cells/s | Surface paddling from the start, diving with a trick (§9.2) |
| Climb | Ladders, vines, roots | Holding up |

Growth (§9.1) changes the view scale slightly and some numbers. It **never**
changes the box size, so a tunnel dug as a newborn still fits a Guardian.

### 4.2 Controls

Interaction is **directional**: the target is the cell next to the pup in the
direction you face or hold (up, down, forward, and the forward diagonals),
with a **reach of 1.5 cells** *(tune)*. That works the same on a keyboard
shared by two co-op players, on a gamepad and on touch. A mouse is an extra
for solo play on desktop: it aims at any cell within a **3-cell reach**.

| Action | Keyboard (P1) | Gamepad | Touch | Effect |
| --- | --- | --- | --- | --- |
| Move | A / D | Left stick / D-pad | Left thumb pad | Run; hold down to crouch or drop through platforms |
| Aim | W / S (with move) | Left stick direction | Thumb pad direction | Picks the target cell |
| Jump | Space | A | Jump button | Jump; hold to paddle up in water |
| Dig / use | J (or left mouse) | X | Dig button | Dig the target cell; use furniture, talk, open chests |
| Place | K (or right mouse) | B | Place button | Place the held block in the target cell; hold Shift / LB to place on the back wall |
| Sniff | L (hold) | RT (hold) | Nose button (hold) | Sniff-vision (§4.4) |
| Bark | I (tap / hold) | Y (tap / hold) | Bark button | Bark or charged bark (§4.5) |
| Carry / drop | E | RB | Mouth button | Pick up or drop an item, creature or block; throw while running (fetch) |
| Mouth wheel | Q / R | LB / D-pad up/down | Swipe the mouth icon | Cycle what's in your mouth (§4.6) |
| Craft | C | Back / View | Paw button | Open the chew mat or station nearby (§6.3) |
| Pet me | P | R3 | Heart button | Ask for a pet (§10.3) |
| Bag | Tab | Start (hold) | Bag icon | Inventory |
| Map | M | Back (hold) | Map icon | World map of explored chunks and found sites |
| Photo | F | L3 | Camera icon | Photo mode (§10.2) |
| Pause | Escape (shell) | Start | Pause icon | — |

P2 and P3 keyboard defaults sit on the arrow keys plus numpad, and on IJKL
plus nearby keys, or play on gamepads (§13). Every key is rebindable on the
Controls tab.

### 4.3 Abilities

Each ability opens new ways to shape and explore the world.

| Ability | From | What it does | What it opens |
| --- | --- | --- | --- |
| **Dig** | Start | Dig the target cell; speed by hardness and the tool in your mouth (§6.4) | Tunnels, burrows, caves, buried caches |
| **Sniff** | Start | Sniff-vision (§4.4) | Hidden caves, ore, treasures, quest trails |
| **Bark** | Start | Tap to talk and greet; hold to charge (§4.5) | Shooing threats, bark switches, calling allies |
| **Fetch** | Start | Throw what you carry; it lands in an arc and you can chase it | Distracting threats, fetch plates in temples, the Mailman King (§7.3) |
| **Jump** | Start | §4.1 | Two-block ledges; with Wall Scrabble, walls |
| **Swim** | Start (paddle) | Paddle on the surface; dive with the Dive trick | Ponds, flooded caves, the Flooded Ruins |
| **Carry** | Start | Hold one thing in your mouth (§4.6) | Carrying blocks home, keys, eggs, a sleepy villager |

### 4.4 Sniff-vision — `sim/scent.gd`

Hold **Sniff** and the world drains to soft, desaturated tones while scents
glow:

- **Trails** run from the pup toward the nearest points of interest within
  **48 cells** *(tune, Beagle +50 %)*: buried caches, hidden cave pockets, ore
  veins, structure doors, quest targets and lost items (including your own
  retreat bundle, §5.2). Trails pass **through** blocks, so they point the way
  even underground.
- Each kind of scent has its own **icon and trail shape**: bones are a dotted
  line, treasure a sparkle chain, ore a zigzag, doors a pawprint line, quests
  a ribbon. None relies on colour alone.
- A **caption** names the strongest scent: "Strong scent: treasure, down and
  to the right". It updates as you move, so the trail is usable without seeing
  it.
- Buried cells within 6 cells are outlined.
- While sniffing, the pup walks at half speed and can't dig or bark. Sniffing
  costs no energy.
- At night every trail is twice as long and night-only scents appear (§3.7).
- Reduced motion turns flowing particle trails into static arrows.

**Implemented slice:** existing PK1 crystal/glow-moss markers use an ore zigzag
and diamond; the starting bed uses home pawprints; the loose starter stick uses
dots, a twig icon and STICK. Moving toy positions refresh without terrain edits,
and a carried stick has no lost-item trail. A rebindable L, Hold/Toggle,
the caption, six-cell buried outlines, half-speed walking and 48/96-cell
day/night ranges are playable. Sniff state is transient and menus cancel it.
Ambient grass/wood do not create trails. Caches, other structure/quest/lost-item
scents and night-only finds remain pending with those world systems; this does
not add night lighting or change PK1 generation.

### 4.5 Bark power — `sim/puppy_abilities.gd`

| Bark | Input | Range *(tune)* | Effect |
| --- | --- | --- | --- |
| **Yip** | Tap | 4 cells | Greets villagers, starts dialogue, presses a nearby bark switch, startles small critters |
| **Woof** | Hold 0.5 s | 7 cells | Shoos raccoons and crystal mites (§5.3), knocks loose leaves and snow, rings echo crystals |
| **Ruff** | Hold 1.2 s | 10 cells | Scares off shadow wolves and storm clouds, activates ancient mechanisms (howl stones, temple doors), staggers a boss in its weak phase |
| **Mighty Howl** | Hold 2 s, needs the trick (§9.2) | 16 cells | Calls allies (restored spirit wolves, your pet, nearby villagers' guard dog), lights every howl stone in range, breaks a boss's shield |

- A bark draws a ring with a sound-wave icon and a caption ("Woof!"). The
  charge meter has numbered pips (1–3, 4 with the trick).
- Charged barks cost energy (Woof 3, Ruff 8, Howl 15) *(tune)*. A 1 s
  cooldown follows a Ruff or Howl.
- The tunable **Bark charge** offers Hold (default) or Tap to cycle, for
  players who can't hold buttons.

**Implemented slice:** rebindable I, release-to-fire Hold at 0.5/1.2 s, and
the owner's chosen Tap sequence: 1-3 taps followed by 0.6 s without another tap
fires once; the fourth tap cycles to Yip. Pips are numbered 1-3. Woof and Ruff
gather front-layer leaf blocks within their radius, through other foliage but
not other solid blocks; back walls remain intact. Captions, original synthesized
cues and up to four wave rings provide feedback. Reduced motion uses static
fading rings. Sniffing, menus and mode/rebinding changes cancel charges, not the
saved energy or Ruff cooldown. Villagers, creatures, snow, echo crystals and
mechanisms await their systems; Mighty Howl is not exposed.

### 4.6 Carry, the bag and gear — `sim/inventory.gd`

- **The mouth** holds one thing: a tool, a block stack to place, food, a key,
  a stick, an egg or a small creature. What's in your mouth is what Dig, Place
  and Fetch use. The **mouth wheel** keeps **four quick picks** you cycle with
  Q / R.
- **The bag** starts as a **Bandana pouch (8 slots)**. A Saddlebag (16) and an
  Explorer pack (24) are crafted later *(tune)*. Stacks hold 50 blocks or 10
  food *(tune)*.
- **Gear** is functional equipment, crafted in the world and saved in the
  world file. It has four slots: **mouth tool** (the dig tier, §6.4), **paws**
  (ice-grip booties, swim fins), **back** (a sweater for warmth, a lantern
  pack for light) and **collar charm** (sniff range, courage, warmth).
- **Cosmetics** (§12.3) are a separate look layer from the store. Gear sets
  the stats and cosmetics set the look, so you never have to wear an ugly
  sweater to stay warm. The HUD shows equipped gear as icons.

**Implemented starter slice:** `sim/fetch_stick.gd` owns one stick beside the
starting bed. Rebindable E picks it up within 1.5 cells with clear front-layer
line of sight. E while stopped drops it; movement held and at least 4 cells/s
in the facing direction throws it at 9 cells/s with 7.5 cells/s upward lift
*(tune)*. Flight shares the pup's fixed-step grid collision and gravity;
front solids stop it, back walls do not, and ground drag settles it.
The release position clips against terrain rather than passing through a wall.

The mouth HUD shows state/refusals. Carrying prevents digging/placing but
allows bed use and sniff pickup. Solid front placement cannot bury the loose
toy. Held, flying and settled state are saved; older saves receive the gift
without changing materials or PK1 terrain. The owner chose persistence and a
sniff trail, not recall or despawning. The packed building bag and Q/R material
selection remain unchanged; four quick picks, slotted inventory, other carry
items, gear and fetch rewards are not implemented.

---

## 5. Survival with heart

### 5.1 Needs — `sim/needs.gd`

Four meters, 0–100, each drawn as an icon with a number. None relies on
colour.

| Need | Drains *(tune, Classic pace)* | Restored by | When low |
| --- | --- | --- | --- |
| **Hunger** | 1 per 15 s; faster when digging and swimming | Snacks (berries, treats, the rabbit chef's meals), the water bowl (+5 and a drink) | Below 25: digging slows by a third and courage doesn't regenerate. At 0: happiness drains. **Never** causes a retreat by itself |
| **Energy** | Running, digging, charged barks | A nap in a bed (full, skips the night), Sit (slow, anywhere), snacks (a little) | Below 20: yawns and slower movement. At 0: the pup flops for a 3 s power nap where they stand |
| **Warmth** | Night, rain, snow, ice, deep caves, swimming | Indoors in a den (§6.2), a hearth or lantern nearby, sweaters, sunbathing, hot springs, **huddling** with another pup in Pack mode | Below 25: shivers, slower digging. At 0: courage drains 1 paw per 10 s, so cold can end in a retreat |
| **Happiness** | Slowly, by 1 per minute | Belly rubs and pets (§10.3), playing fetch, treats, discoveries, a cosy den (comfort, §6.2), a friend moving in | At 0 nothing bad happens. High happiness is a **buff**: Pawprints ×1.0 → ×1.5, and at 100 a 10 s **Zoomies** burst (run speed +40 %) |

The **Survival pace** tunable offers **Cozy** (drains at half rate; hunger and
warmth never reach 0), **Classic** and **Hardy** (×1.5 drain).

**Implemented basic budget only:** 100 energy, spent only by Woof (3) and Ruff
(8). After one grounded, inactive second, recover 2 energy per second up to 100.
Movement, sniffing, digging, placing, barking and carry input interrupt rest;
paused/modal worlds freeze it. Energy, partial rest delay and bark cooldown persist as
optional additive fields in format 1; old saves default to full energy and no
cooldown. Other drains, food, low-meter consequences, survival-pace choices and
the other needs are pending. The current bed closes an outing, not a full nap
or night skip.

### 5.2 Courage and the retreat

**Courage** is the pup's health, drawn as paw icons: 5 paws at the start, and
one more per growth stage (§9.1). A threat's bump, a boss attack or freezing
cold costs paws. Courage regenerates one paw per 20 s *(tune)* when the pup
is out of danger and hunger is above 25.

At 0 courage the pup **retreats**: a dramatic "Yipe!" with a dust-cloud
dash off-screen, a fade, and a groggy wake-up in the last den slept in (or the
starting kennel).

- If it was night, the pup wakes at dawn; by day, one in-game hour later.
- Energy is full, hunger is reduced by 20, and the pup is **Groggy** for
  60 s: run speed −20 %, with little stars around the head.
- **The retreat bundle:** half of the loose **materials** in the bag drop where
  the pup fell, as a scent bundle that sniff-vision always shows and that
  never despawns. Tools, gear, food, keys, fragments and cosmetics are
  **never** dropped. The **Retreat penalty** tunable can turn the bundle off.
- A boss fight resets to its start, and the boss waits politely.

The Day's Diary counts retreats as "Brave tries", never as deaths. The word
"die" never appears in the game's copy.

### 5.3 Threats — `sim/creatures/`

Threats have **nerve**, not health. Boops (landing a pounce on one), barks and
thrown sticks reduce nerve. At zero they **flee** and drop anything they stole.
Nothing is ever killed.

| Threat | v1 | Where and when | Behaviour | Counter |
| --- | --- | --- | --- | --- |
| **Raccoon bandits** | ✔ | Forest camps; meadow at night | Tiptoe up, steal one random bag item (never gear or fragments) and run for camp. They raid unlit, unguarded toy chests in a den | Chase and boop, bark a Woof, or throw a stick for them to fumble. Light and a bell keep them out of dens |
| **Grumpy storm clouds** | ✔ | Surface during storms | Drift above, rain (warmth drain) and drop a telegraphed **zap**: a crackle and a shadow, then a burst that frizzes fur (−1 courage, knockback) | Shelter under any block or back wall; a Ruff puffs them away |
| **Shadow wolves** | ✔ | Any surface at night, in fog; the forest at dusk | Prowl, stalk and pounce (−1 courage). Afraid of light ≥ 8 and of Ruff barks. They are the **lost spirits of the pack**: each fragment returned to the shrine turns some of them friendly (§7.1) | Stay lit, carry a lantern, Ruff, or get home |
| **Cave chills** | ✔ | Caverns | Patches of icy mist and slippery ice: warmth drain, low friction | Ice-grip booties, a lantern pack, hot springs |
| **Crystal mites** | ✔ | Caverns | Small skittering critters that nibble placed torches and lanterns | A Woof; they love crystal dust and can be fed it |
| Snowball yetis | | Snowy Peaks | Lob snowballs in telegraphed arcs (knockback, warmth −) | Dodge, Ruff, or catch a snowball and fetch it back |
| Dust devils | | Desert, by day | Spinning gusts that push and blind with sand | Shelter, or dig down |
| Sky gulls | | Sky Islands | Dive at the item in your mouth | Duck (crouch), Woof |
| Grumpy crabs | | Flooded Ruins | Sideways patrols, pinch (knockback) | Jump over, Woof |

Every threat has an **approach cue**: a caption with a direction, an icon and
a sound ("Rustling — left", "Low growl — behind you"). None relies on sound or
colour alone.

### 5.4 Spawning rules

- Threats spawn only in loaded chunks out of view, on cells with light below 8,
  never within 12 cells of a den or the shrine *(tune)*.
- The **Threats** tunable offers **Peaceful** (no hostile spawns; bosses still
  fight but do half damage), **Gentle** (default: fewer spawns, longer
  telegraphs) and **Adventurous**.
- Despawn when out of range for 30 s. A fleeing raccoon that reaches camp
  stashes its loot there, where it stays until you take it back.

---

## 6. Building and crafting

### 6.1 Digging and placing

- **Dig** hits the target cell. A dig takes a hold of **0.25–2.0 s**
  depending on hardness and tool (§6.4), with a crack overlay showing progress
  in steps. The block drops into the bag; if the bag is full, it pops out as a
  pickup.
- **Place** puts the mouth's block in the target cell. You can't place a block
  inside a creature or a pup.
- Front blocks need support (a neighbour or a back wall), except platforms,
  ladders and scaffolding.
- **Dig Deep** (trick, §9.2) digs a 1 × 3 line in one action.
- In Pack mode, a **Builder** can show a blueprint ghost (§10.1).
- Everything is undoable by digging it back up, with the block returned.
  Nothing is ever lost by building.

### 6.2 Dens — `sim/dens.gd`

A **den** is a recognised room, like Terraria's housing check. A room counts
as a den when it has:

- an enclosed space of at least **6 × 4** cells *(tune)*, with walls, a floor,
  a ceiling and a back wall across at least 90 % of the room;
- a **door** (a door block or a dog flap);
- a **bed**, a **water bowl** and a **light** source.

A den is:

- a **respawn point** (the last den slept in);
- **warm** (warmth fills inside) and **safe** (no spawns within 12 cells);
- a **home** for one villager, if it has a second bed and their station
  (§8.1);
- scored for **comfort** (0–5 bones), from distinct furniture, decorations,
  trophies and size. Comfort raises happiness while inside and the nap's
  happiness bonus.

The den check runs in the model whenever an edit touches a room's boundary.
The HUD shows a small house icon with the comfort score when you stand inside
a recognised den, and a hint ("Needs: a light") when a room nearly qualifies.

**Den styles** are not separate systems. A burrow is a den dug underground, a
treehouse is a den built in a giant tree with ladders, and a castle is a big
den with towers. The comfort score rewards variety, and Pupedia tracks the
styles you've built.

### 6.3 Crafting by paw gestures — `sim/crafting.gd`, `ui/chew_mat.gd`

There are no crafting grids. Crafting happens at a **station**, with your paws:

1. Stand at a station and press **Craft**. The station's mat opens as a small
   overlay with up to **three ingredient bowls**.
2. Drop ingredients into the bowls (from the bag, or straight from your mouth).
   The mat shows what you **could** make with them as large picture cards. A
   recipe you've never made shows as a silhouette with a sniffable hint.
3. Pick a card and **perform its gesture**:

| Gesture | Input | Used for *(examples)* |
| --- | --- | --- |
| **Paw-pat** | Tap Dig to a 3-beat rhythm shown on screen | Furniture, simple tools |
| **Dig-dig** | Down, down, down | Blocks: bricks, planks, cloth |
| **Roll-over** | A full circle on the stick or the four directions | Soft goods: beds, cushions, sweaters |
| **Tail-chase spin** | Hold left or right for a full spin | Mixing: food, dyes, potions |
| **High-five** | Up + Dig together | Gear and charms |

- A good gesture gives a cheerful flourish. A sloppy one still crafts, with a
  wobblier animation. **There is no failure state.**
- The **Craft gestures** tunable offers **Gestures** (default) or **One
  press**, which crafts the chosen card immediately. Both are equal: no
  bonus, no achievement depends on the gesture.
- **Recipe discovery:** the first time you pick up an ingredient, sniffing it
  reveals one recipe it belongs to. Villagers teach more, and temple murals
  teach ancient ones. The **recipe book** lives in the Pupedia (§10.5).

Stations:

| Station | Where | Makes |
| --- | --- | --- |
| **Chew mat** | Starting kennel; crafted anywhere | Basic tools, planks, ladders, beds, bowls, simple furniture |
| **Cat forge** | Whiskers the blacksmith's home (§8.1) | Shiny and crystal tools, metal furniture, collar charms, rails |
| **Rabbit kitchen** | Clover the chef's home | Meals (bigger hunger and warmth buffs), treats, bone broth |
| **Weaving nest** | Crafted after the first wool | Sweaters, bandanas, cushions, kites (later), sails |
| **Shrine altar** | Pack Shrine | Spirit gear from fragments' dust *(late game)* |

### 6.4 Materials and tool tiers

| Tier | Tool (held in the mouth) | Digs | Made from |
| --- | --- | --- | --- |
| 0 | **Paws** | `soft`: soil, sand, snow, leaves, moss | — |
| 1 | **Stick scoop** | + `firm`: clay, wood, packed snow, roots | Sticks |
| 2 | **Bone shovel** | + `stone`: stone, sandstone, bricks | Bones + sticks |
| 3 | **Shiny pick** | + `crystal`: crystal, ore veins | Shiny stones (ore) at the cat forge |
| 4 | **Spirit spade** | + `ancient` sealed doors (never arena walls) | Crystal + fragment dust at the shrine *(late game)* |

Base dig times: soft 0.25 s, firm 0.6 s, stone 1.0 s, crystal 1.4 s *(tune)*,
each halved per tier above the minimum. Materials in the pitch map like this:
**bones** (buried caches, bone trees), **sticks** (trees, bushes), **wool**
(brushing friendly sheep in the meadow), **shiny stones** (ore in the
caverns) and **rare finds** (crystals, star bones, moon flowers, temple
relics).

### 6.5 Furniture and decorations

Beds (straw, cushion, canopy), water bowls, toy chests (storage, 16 slots),
lanterns, a hearth, a **trophy wall** (it shows boss trophies and your biggest
finds automatically), rugs, paintings of discovered places, a doorbell, a
mailbox (the bird post, §8.1), flower pots, a dog flap, windows and
weathervanes. Every piece adds to comfort (§6.2).

---

## 7. Adventure

### 7.1 The Great Bone Quest — `sim/quest_line.gd`

The main story is about returning the seven **Bone Fragments** to the **Pack
Shrine** next to the starting kennel. Each fragment:

- lights one pillar of the shrine with a small cutscene and a swell of music;
- turns the shadow wolves within a widening radius of the shrine into
  **spirit wolves**: friendly glowing allies who wander the night and answer a
  Mighty Howl;
- grants a trick or an ability (§9.2) and a big Pawprints award (§9.1);
- adds a trophy to the trophy wall.

| # | Fragment | Where | How | v1 | Grants |
| --- | --- | --- | --- | --- | --- |
| 1 | **Root Fragment** | The Root Temple, Whispering Forest | Temple (§7.2) | ✔ | Dig Deep |
| 2 | **Stamp Fragment** | Post Office Ruins, Sunny Meadows | Befriend the Mailman King (§7.3) | ✔ | Mighty Howl |
| 3 | **Crystal Fragment** | The Crystal Vault, Crystal Caverns | Temple | ✔ | Dive |
| 4 | **Storm Fragment** | The Cloud Kennel, Sky Islands | Befriend the Thunder Tomcat | | Lightning Dash |
| 5 | **Sand Fragment** | The Sandglass Temple, Desert | Temple | | Wall Scrabble II |
| 6 | **Tide Fragment** | The Sunken Temple, Flooded Ruins | Temple | | Deep breath |
| 7 | **Heart Fragment** | The Deep Hollow | Soothe the Cavern Wyrm | | Guardian growth |

Fragments 1–3 can be done in any order. The world map shows each
fragment's region once you sniff its first trail, and the Bird Post (§8.1)
brings rumours that point the way. With all seven fragments, the Spirit of the
Pack returns: every shadow wolf becomes a spirit wolf, the pup grows into the
**Guardian**, and the credits roll over the shrine. Then the sandbox goes on.

### 7.2 Temples of the First Dog — `sim/temples.gd`

A temple is a hand-authored structure template of **4–8 rooms**, stamped by
the generator (§3.2), with `unbreakable` ancient walls so puzzles can't be
dug around. Inside, the rooms are the puzzles.

| Puzzle | Rule |
| --- | --- |
| **Bark switches** | Carved dog-head panels that open doors when barked at with the right strength (pips on the panel) |
| **Echo crystals** | A bark bounces between crystals; place mirrors (crystal blocks) to steer it to a panel |
| **Scent locks** | Dark rooms where the only guide is a scent trail; walk it without touching the "stale" tiles |
| **Fetch plates** | Carry a bone key, or throw a stick, onto a pressure plate. Some need two at once: one in your mouth, one thrown |
| **Dig-through** | Soft "temple sand" pockets hide the path. Sniff, then dig the right ones |
| **Water levels** | (Sunken Temple) Raise and lower water by barking at valves |

Traps are **never** gory: spring floors that bounce you back, rolling yarn
balls, squeaker darts that knock you back with a squeak, snapping clam doors
and puffs of sneezing pollen. Each trap costs at most one paw of courage and is
telegraphed (a click, a glint and a caption).

Every temple ends at a fragment altar, with a mural of the First Dog
(Pupedia lore) and a treasure room. The **Root Temple** (v1) teaches bark
switches, fetch plates and dig-through. The **Crystal Vault** (v1) adds echo
crystals and scent locks in the dark.

### 7.3 Bosses — `sim/bosses/`

Bosses are never killed. You **win them over**: each has a "grump" bar that
falls as you land the right moves, and at zero they calm down, tell you why
they were grumpy, and become friends. Each boss has three phases, telegraphs
every attack (a caption, an icon and a sound) and has a title-card entrance.
Arenas are made of `unbreakable` ancient stone.

| Boss | v1 | Arena | Pattern | Afterwards |
| --- | --- | --- | --- | --- |
| **The Mailman King** | ✔ | Post Office Ruins, Sunny Meadows | A pompous giant mail carrier with a crown of stamps and a royal mail tricycle. **1. Parcel barrage:** parcels lob in with shadow telegraphs; catch one in your mouth and **fetch it back** to his feet ("Return to sender!") to stagger him. **2. Doorbell shockwave:** a ding-dong telegraph, then a ground wave to jump. **3. Junk-mail blizzard:** paper fills the screen; sniff-vision shows his scent, and a Ruff blows the paper away. He also builds "Beware of Dog" sign walls that a Woof knocks down | He admits nobody ever greets him at the door. He moves into the village and runs the **Bird Post** as Postmaster (§8.1). Trophy: a royal stamp |
| **The Thunder Tomcat** | | The Cloud Kennel, Sky Islands | An enormous fluffy storm cat on a cloud throne. Telegraphed lightning swipes along lanes; yarn-ball thunderheads to dodge; bark into **storm drums** to ground the lightning; glide between clouds on a kite (§7.4) | He just wanted a nap in the sun. You build him a sun-bed, and he sleeps on it in your village forever |
| **The Cavern Wyrm** | | The Deep Hollow | A huge, soft, crystal-crested worm that **burrows through the arena's soft fill** (the fill regenerates after the fight). A minecart chase through his tunnels; bark echo crystals to make him surface; a Ruff to his crest opens his mouth | He had a tummy ache: the Heart Fragment was stuck in a tooth. You pull it out. He becomes your tunnel-digging friend |

Bosses scale to Pack mode (more grump, more parcels), and the **Threats**
tunable softens them (§5.4). Each one is an **original character**. The
Mailman King resembles no real postal service: no real logos, colours,
uniforms or names *(verify the final look — §19.4)*.

### 7.4 Vehicles and pets — `sim/vehicles.gd`, `sim/pets.gd` *(after v1)*

| Ride | How you get it | What it does |
| --- | --- | --- |
| **Minecart** | Rails and carts from the cat forge | Fast travel along laid rails, through caverns; needed for the Wyrm chase |
| **Leaf boat** | Crafted from a giant leaf and sticks | Paddle across water at 6 cells/s; carries one co-op passenger |
| **Kite** | Weaving nest | Glide: hold Jump in the air; updrafts on the peaks and sky islands lift you |
| **Duck** (pet) | Hatch an egg from the meadow pond | Follows you, swims with you, quacks at buried treasure within 8 cells |
| **Baby dragon** (pet) | Hatch a warm egg from the Sky Islands | Follows you, gives off light 8 and warmth, flutters you up one extra block per jump |

Pets never fight. They are companions with one helpful trick each. A pet
appears in photos, and a Mighty Howl calls it to you.

### 7.5 Secrets and treasure

Buried caches (§3.4), night-only finds, the murals of the First Dog, secret
rooms behind cracked walls (sniff-vision shows a "draught" scent), constellations
that point to star bones on full-moon nights, and lost villagers' items for
quests. Every secret goes into the Pupedia (§10.5) with where you found it.

---

## 8. Base life

### 8.1 Villagers — `sim/npcs/`

Wandering animals visit once you have a den. Each visitor moves in when a
**free den** has a second bed, their station and comfort ≥ 2 (§6.2).

| Villager | v1 | Arrives | Moves in with | Gives |
| --- | --- | --- | --- | --- |
| **Whiskers**, the cat blacksmith | ✔ | After your first shiny stone | The cat forge | Tier 3 tools, rails, charms; trades shiny stones for gear |
| **Clover**, the rabbit chef | ✔ | After your first berry harvest | The rabbit kitchen | Meals, recipes, seeds; buys crops |
| **Pip and the Bird Post** | ✔ | After your first den | A mailbox | Mail quests and rumours (fragment hints); delivers items from any mailbox to your den. The Mailman King later becomes Postmaster |
| Old Shell, the tortoise lorekeeper | | After the first fragment | A reading nook | Lore, mural translations, fragment hints |
| Bramble, the sheep weaver | | Brush a sheep three days in a row | The weaving nest | Wool, cloth, kites and sails |
| Visiting merchants | | Random, by day | — | A travelling shop of rare seeds and decorations |

Villagers walk between their den, the village and nearby places, and sleep at
night. They never get hurt. When a threat comes near, they hide indoors.

### 8.2 Friendship and quests — `sim/npcs/friendship.gd`, `sim/npcs/quests.gd`

- Friendship runs from **0 to 5 hearts**. Talking (once a day), gifts they like,
  finishing their quests and pets (§10.3) raise it.
- Hearts unlock their recipes, shop stock and their **belly rub**: once a day,
  a friendly villager gives you a belly rub (happiness +25, a big cosy
  animation).
- **Quests** come from a template table, filled in from the world's state:
  fetch ("Clover needs 5 moon flowers"), deliver ("Take this letter to
  Whiskers"), build ("Pip wants a lookout kennel 20 cells up"), find ("I lost
  my thimble somewhere in the forest", followed by sniff-vision) and visit.
  At most three are active at a time.
- Rewards: Pawprints, items, recipes and friendship.

### 8.3 Garden and farming — `sim/farming.gd`

- Dig soil with a seed in your mouth, then Place to plant. Tilled soil needs
  water within 4 cells (a water bowl, a pond, or rain that day).
- Crops grow **one stage per dawn** *(tune)*. Growth is caught up on load from
  the day count, so it is deterministic and costs nothing while unloaded.

| Plant | Stages | Harvest |
| --- | --- | --- |
| **Berry bush** | 3 | Berries (snack) every 2 days |
| **Treat sprout** | 4 | Crunchy treats (happiness + hunger) |
| **Bone tree** | 5 | A tree that yields 2–3 bones every 3 days, planted from a buried "seed bone" |
| **Moon flower** | 3 | Blooms only on full-moon nights; a rare crafting find |
| **Pumpkin** | 4 | The Harvest fetch-off's ball (§9.4) |

---

## 9. Progression

### 9.1 Growth — `sim/growth.gd`

**Pawprints** are the growth points. They come from discoveries, quests,
temples, fragments, building dens, new recipes and new Pupedia entries, never
from scaring threats. That keeps growth about exploring, not grinding.

| Stage | Pawprints *(tune)* | Courage | Look | Unlocks |
| --- | --- | --- | --- | --- |
| **Newborn** | 0 | 5 paws | Huge head, tiny legs, wobbly run | — |
| **Pup** | 300 | 6 paws | Longer legs | Wall Scrabble, the Saddlebag recipe |
| **Junior** | 1500 | 7 paws | Lankier, collar charm socket | Woof → Ruff range +2, the Explorer pack recipe |
| **Guardian** | All 7 fragments | 8 paws | Full-grown, a glowing collar, the cape looks best | Spirit spade, the Guardian title |

Growth changes the rig's proportions and up to 15 % view scale *(tune)*, never
the box (§4.1). Guardian needs the full game, so a v1 pup tops out at Junior.

### 9.2 Tricks

Tricks are learned. Each has a short "learning" cutscene where a villager or
a mural shows it, and an icon in the Pupedia.

| Trick | Learned from | Effect |
| --- | --- | --- |
| **Sit** | First steps | Rest anywhere: energy and courage slowly come back. Villagers say "Good pup!" |
| **Fetch** | First steps | Throw what you carry (§4.3) |
| **Play bow** | Whiskers, 2 hearts | Invites critters and villagers to play: +happiness. Also a photo pose |
| **Wall Scrabble** | Growth: Pup | Scramble up a two-cell wall |
| **Dig Deep** | Root Fragment | Dig 1 × 3 in one action, and dig ×1.5 faster below the surface |
| **Mighty Howl** | Stamp Fragment | The fourth bark (§4.5) |
| **Dive** | Crystal Fragment | Swim underwater, with 10 s of breath |
| **Play dead** | Old Shell *(later)* | Shadow wolves and raccoons lose interest |
| **Lightning Dash** | Storm Fragment *(later)* | A short dash across gaps, through falling sand and past threats |

### 9.3 Breeds — `characters`, profiles in `sim/breed_profiles.gd`

A breed changes **authored parameters only** (speeds, sniff range, warmth
drain, bag bonus, dig speed), as Cube Trials' vehicle profiles do. It never
changes the box size or the solver. Breeds are the manifest's `characters`,
one per seat, stood on the setup plinth by `character_preview.tscn`.

| Id | Breed | Strength *(tune)* | Pack role it leans to | Unlocked by |
| --- | --- | --- | --- | --- |
| `breed_mixed` | **Mixed pup** | Balanced; +2 bag slots | Builder | always |
| `breed_corgi` | **Corgi** | Nimble: dig ×1.2, and Wall Scrabble from the Newborn stage | Digger | `puppy_kraft_first_den` |
| `breed_beagle` | **Beagle** | Sniff-master: sniff range +50 %, trails show one more scent | Scout | `puppy_kraft_nose_knows` |
| `breed_husky` | **Husky** | Sturdy: warmth drains at half rate, +1 courage paw | Guard | `puppy_kraft_first_night` |
| `breed_greyhound` | **Greyhound** | Swift: run speed +25 %, longer coyote time | Scout | `puppy_kraft_return_to_sender` |

The breed is chosen per session and per seat. A world remembers its pups'
progress (growth, tricks, gear) per seat, not per breed. You can visit your
world as a corgi today and a husky tomorrow. Greyhound unlocking after you
befriend the Mailman King is the joke. Breeds never gate story content.

### 9.4 Seasonal events — `sim/seasons.gd`

| Event | v1 | When | What happens |
| --- | --- | --- | --- |
| **Moonlit howl nights** | ✔ | Every 8th in-game night (full moon) | Spirit wolves gather at the shrine; a howl-along mini-game (bark on the beat with the pack) for a moon charm; moon flowers bloom; star bones appear |
| **Snowball festival** | | Local date, Dec 15 – Jan 5 *(verify)* | Snow falls on the meadow; villagers hold a snowball fight (fetch-throwing); scarf and hat rewards |
| **Harvest fetch-off** | | Local date, Oct 1 – 31 *(verify)* | Pumpkins grow everywhere; a timed fetch race through the village; a pumpkin-hat reward |

Calendar events read the device's **local date** and stay offline. The
**Seasonal events** tunable can switch them off, and they never gate story
progress or achievements beyond their own (§19.8).

---

## 10. Fun extras

### 10.1 Pack mode — same-screen couch co-op

Two or three pups play **simultaneously on one screen**, in one world. This is
not hot seat: `local_multiplayer_turns = false`. Pack mode is desktop and
console-style only. Mobile stays single-player (`GameSession.multiplayer_available()`).

- **One world, one save.** Pack mode plays the world slot chosen at the Den
  Door. Each seat's pup progress (growth, tricks, bag, gear) is stored in that
  world under P1/P2/P3. The world itself, its dens, villagers and quests are
  shared.
- **Shared camera.** The camera frames every pup and zooms out to a limit
  (**1.6×** the solo view, *tune*). At the limit, the screen edge is a soft
  wall. A pup held at the edge for 4 s *(tune)* can press **Regroup** (or any
  pup can Howl) to zip to the pack in a puff of fluff. There is no split
  screen: it would double the world draw cost (§17).
- **Pack roles.** Each pup picks a bandana role at the **Pack Board** in any
  den. Roles are in the world, not in setup, so no framework change is needed.
  Roles are soft perks and work solo too:

| Role | Perk *(tune)* |
| --- | --- |
| **Digger** | Dig ×1.3; dug blocks go straight to the closest Builder's bag if there's room |
| **Scout** | Sniff pings: a tap of Sniff marks the strongest scent for the whole pack for 10 s |
| **Builder** | Place ×1.5; shows blueprint ghosts other pups can fill |
| **Guard** | Barks also shield nearby pups: the next bump costs no courage |

- **Nuzzle revive.** A pup at 0 courage in Pack mode doesn't retreat at once.
  They flop with "Help!" over their head for 10 s, and any pup can nuzzle
  them (Carry, while touching) to bring them back with 2 paws. If nobody comes,
  they retreat to the den on their own and the rest play on.
- **Huddle.** Pups standing together warm each other (§5.1).
- **Identity.** Every pup wears a floating **P1 / P2 / P3** tag and a seat
  identity mark (a collar tag in the shared blue, red or green **plus** a
  shape: circle, triangle or square). Store cosmetics never hide it.
- Payout: one shared payout at Call it a day, from the pack's combined
  Adventure points.

### 10.2 Photo mode — `ui/photo_mode.gd`

- **Photo** freezes the simulation (the model stops; the view stays live).
- Pan and zoom the camera within the loaded chunks. Hide the HUD.
- **Poses:** sit, play bow, sploot, howl, roll-over, zoomies, sleepy curl.
  **Expressions:** happy, derp-tongue, sleepy, boop-eyed, proud, surprised. In
  Pack mode each pup poses on its own.
- **Filters:** Warm print, Storybook, Night glow, Mono; plus frames and an
  optional caption.
- **Snap** renders the view and passes it to `ShareManager.generate_score_image()`
  through `share_art.tscn` as the photo card (§12.4).
- With intense effects off there is no shutter flash. Reduced motion keeps the
  camera still between moves.

### 10.3 Pet-the-puppy button

**Pet me** (§4.2) is always available:

- The nearest villager within 8 cells comes over and pets you, with a joyful
  reaction that's unique to them (Whiskers purrs, Clover thumps, Pip
  chirps a song). Happiness +5, with a diminishing return per villager per day
  *(tune)*. A spirit wolf or your pet nuzzles you.
- In Pack mode, a nearby pup gets a "pet pile": both wag, both +5.
- Alone, the pup rolls over for a pretend belly rub (+1).
- Threats pause for half a second, confused and charmed, once per creature
  per night *(tune)*.
- Nobody ever ignores it. That's the point.

### 10.4 Soundtrack — `audio/music_director.gd`

The music is an adaptive, orchestral-style score in **vertical layers**: per
biome, a base loop and stems for strings, woodwinds, percussion and brass.

- The director mixes stems from the state: exploring (base + woodwinds),
  underground (base + low strings, reverb), night (muted base + celesta),
  danger near (+ percussion), temple (a temple motif), boss (a full swell and
  a boss theme per boss), fragment returned (a fanfare stinger).
- Crossfades last 2–4 s. Transitions land on the bar.
- Music ducks under captions with voice, and under important cue sounds.
- Placeholders come from the studio's synthesised tools until the score is
  composed or commissioned *(owner decision — §19.6)*.

### 10.5 The Pupedia — `sim/pupedia.gd`, `ui/pupedia.gd`

The collection log, global across worlds (`user://puppy_kraft_pupedia.cfg`):

- **Biomes**, **Creatures** (threats, critters, villagers, bosses, pets),
  **Treasures**, **Secret places**, **Recipes**, **Tricks**, **Den styles** and
  **Lore** (the murals of the First Dog).
- Each entry records the seed words and the coordinates where it was first
  found. An undiscovered entry shows as a silhouette with a hint.
- New entries pay Pawprints in the world where they're found.
- Completion percentages per tab. Some gallery exhibits and achievements
  key off it.

---

## 11. Art direction

### 11.1 Pipeline and camera

Follow Cube Trials: a real `Node3D` world in an isolated `SubViewport` driven
by the node-free model, original vertex-coloured low-poly meshes built with
`mesh_builder.gd` (copied from `cube_trials/world/`), a warm key light, and no
SSAO or glow.

- **Chunk meshes.** `world/chunk_mesher.gd` builds one mesh per chunk per
  layer: front blocks as bevelled toy cubes (only exposed faces), back walls
  as flat recessed tiles, light baked into vertex colours (§3.6). One shared
  material with a small pattern atlas. A chunk edit rebuilds only that
  chunk, in under **2 ms** *(tune)*.
- **Camera.** A perspective camera with a narrow FOV (about 20°) square to
  the grid, so blocks read flat-on with a hint of depth on their sides. About
  **36 × 20 cells** visible at 16:9 *(tune)*, and a taller view in portrait
  that suits digging down. A gentle look-ahead in the run direction.
  The **Camera zoom** tunable scales it (0.8–1.25×). Reduced motion gives a
  smooth follow with no shake or punch.
- **Depth.** A parallax backdrop of hills, trees and sky per biome; the back
  wall layer recessed 0.3 cells and darker; a fog plane at night.
- **Budget:** under **100 draw calls** in a typical surface shot, enforced by
  `world_view_test.gd`.

### 11.2 Rigs

- **`puppy_rig.gd`** — a soft toy puppy of felt and wood, with a big head,
  floppy ears and a tail that wags with happiness. Breeds are one rig with
  per-breed proportions and coat colours. Growth stages change proportions.
  Sockets for collar, bandana, hat, cape and gear (§4.6), and a fur-pattern
  vertex-colour pass (§12.3). The model drives position, facing and state;
  the view adds the run cycle, ear flops, the sniff pose, the bark squash and
  emotes. These are decorative, and reduced motion calms them.
- **Villagers, critters, threats and bosses** share one small `critter_rig.gd`
  kit (body, head, limbs, tail) with per-character parts, as Chicken Pit's
  `ChickenRig` does for birds and scenery.
- **Scent trails**, **bark rings** and **weather** are view-only effects
  (`world/scent_trails.gd`, `world/weather_fx.gd`) with reduced-motion and
  intense-effects variants.

### 11.3 Palette and theme

Sunny, warm and storybook. The default collar's red is the accent *(tune)*:

```gdscript
const MEADOW := Color("7cc35a")      # meadow grass, the starting biome
const SOIL := Color("8a5a3b")        # soft soil
const STONE := Color("8d8f99")
const CRYSTAL := Color("8fd6e8")     # cavern crystal glow
const NIGHT := Color("1f2440")
const SKY := Color("bfe6f5")
const COLLAR := Color("e2553d")      # accent: the default collar
const CREAM := Color("fff4e0")       # light
const INK := Color("2a2230")         # plaque and outlines
```

`GameTheme`: accent `COLLAR`, light `CREAM`, plaque `INK`, a sky-to-meadow
gradient background, `style_share_card = true`, and the logo
`assets/game-icon.png` (the pup mid-dig with a stick in their mouth,
captured from the rig). Player identities keep the shared blue/red/green
colours, and the theme must not tint them.

---

## 12. Shell features

### 12.1 Achievements (keys are stable forever)

`v1` marks keys that are reachable in the slice. The rest are registered from
v1 too, so their keys are fixed, but they unlock only in later content.

| Key | Title | Badge | Condition | v1 |
| --- | --- | --- | --- | --- |
| `puppy_kraft_first_dig` | Paws in the Dirt | DIG | Dig your first block | ✔ |
| `puppy_kraft_first_craft` | Paw-some Crafter | CRAFT | Craft anything | ✔ |
| `puppy_kraft_first_den` | Home Sweet Den | DEN | Build your first recognised den | ✔ |
| `puppy_kraft_first_night` | Brave Little Pup | NIGHT | Stay outside a den for a whole night | ✔ |
| `puppy_kraft_nose_knows` | Nose Knows | SNIFF | Dig up 10 buried caches found by sniffing | ✔ |
| `puppy_kraft_ancient_woof` | Ancient Woof | BARK | Open a mechanism with a bark | ✔ |
| `puppy_kraft_root_fragment` | Under the Great Tree | ROOT | Return the Root Fragment | ✔ |
| `puppy_kraft_return_to_sender` | Return to Sender | STAMP | Befriend the Mailman King | ✔ |
| `puppy_kraft_crystal_fragment` | Crystal Clear | CRYSTAL | Return the Crystal Fragment | ✔ |
| `puppy_kraft_neighbour_whiskers` | Hot Metal, Warm Heart | CAT | Whiskers moves in | ✔ |
| `puppy_kraft_neighbour_clover` | Dinner Is Served | RABBIT | Clover moves in | ✔ |
| `puppy_kraft_neighbour_pip` | You've Got Mail | BIRD | The Bird Post opens | ✔ |
| `puppy_kraft_belly_rub` | Best Belly Rub | RUB | Reach 5 hearts with any villager | ✔ |
| `puppy_kraft_green_paws` | Green Paws | FARM | Harvest 50 crops | ✔ |
| `puppy_kraft_cosy_castle` | Cosiest Den | 5 BONES | A den with comfort 5 | ✔ |
| `puppy_kraft_deep_dig` | Down the Rabbit Hole | DEEP | Reach row 280 | ✔ |
| `puppy_kraft_lookout` | Lookout Kennel | HIGH | Stand in a den whose floor is 30 cells above the surface | ✔ |
| `puppy_kraft_grow_pup` | Growing Up | PUP | Reach the Pup stage | ✔ |
| `puppy_kraft_grow_junior` | Nearly Grown | JUNIOR | Reach the Junior stage | ✔ |
| `puppy_kraft_zoomies` | ZOOMIES | 100 | Reach 100 happiness | ✔ |
| `puppy_kraft_pet_everyone` | Everyone Loves a Pup | PETS | Get a pet from every villager in one day | ✔ |
| `puppy_kraft_howl_night` | Moon Song | MOON | Finish a howl-along on a full moon | ✔ |
| `puppy_kraft_say_woof` | Say Woof | PHOTO | Snap a photo | ✔ |
| `puppy_kraft_pack` | Pack Adventure | PACK | Call it a day in Pack mode | ✔ |
| `puppy_kraft_nuzzle` | Never Leave a Pup Behind | NUZZLE | Revive a packmate | ✔ |
| `puppy_kraft_storm_fragment` | Calm After the Storm | STORM | Befriend the Thunder Tomcat | |
| `puppy_kraft_sand_fragment` | Sands of Time | SAND | Return the Sand Fragment | |
| `puppy_kraft_tide_fragment` | High Tide | TIDE | Return the Tide Fragment | |
| `puppy_kraft_heart_fragment` | Tummy Ache | WYRM | Soothe the Cavern Wyrm | |
| `puppy_kraft_guardian` | Guardian of the Realm | GUARDIAN | Restore the Spirit of the Pack | |
| `puppy_kraft_all_biomes` | Globe-Trotting Pup | MAP | Visit all seven biomes | |
| `puppy_kraft_rides` | All Aboard | RIDE | Ride a minecart, a leaf boat and a kite | |
| `puppy_kraft_hatchling` | Hatchling | EGG | Hatch a pet | |
| `puppy_kraft_snowball` | Snowball Champion | SNOW | Win the snowball festival | |
| `puppy_kraft_fetch_off` | Fetch-Off Champion | PUMPKIN | Win the harvest fetch-off | |

These keys gate breeds (§9.3), store items (§12.3) and gallery exhibits
(§12.5). No achievement depends on the craft gestures, the survival pace or
the threat level.

### 12.2 Adventure points (the round score)

An outing's **Adventure points** add up its discoveries: new Pupedia entries,
caches dug, quests finished, blocks placed in a recognised den, crops
harvested, temple rooms solved, fragments and boss friendships *(table in
`puppy_kraft_options.gd`, tune)*. Simply digging dirt for an hour scores
little. Points never come from scaring threats.

### 12.3 Store — currency "Kibble"

`store_currency`: `name` "Kibble", `plural` "Kibble", about one per 20
Adventure points *(tune)*, a `round_bonus` of 5, **no `win_bonus`** (there is
no CPU rival), and a ceiling of 150 per outing. Everything in the store is
**cosmetic only**. Functional gear is crafted in the world (§4.6).

| Slot id | Wears | Kind | Empty allowed |
| --- | --- | --- | --- |
| `pk_collar` | Collar | `collar` | No: a plain red collar is the free default |
| `pk_bandana` | Bandana | `bandana` | Yes |
| `pk_hat` | Hat | `hat` | Yes |
| `pk_cape` | Cape | `cape` | Yes |
| `pk_fur` | Fur pattern | `fur` | No: "Natural" (the breed's own coat) is the free default |

In v1 the outfit dresses **every pup in the pack**, each in its own breed,
with seat identity kept by the P-tag and identity mark (§10.1). Per-seat
outfits would need per-seat store slots and are left as a later question.

Starter catalogue. Gated items with a price of 0 are **adventure rewards**,
as the pitch asks: you earn them, then claim them free in the store.

- **Collars:** plain red (default), bell, studded, flower, glow (light 2, view
  only), and the **royal stamp collar** (0, `puppy_kraft_return_to_sender`).
- **Bandanas:** tennis-ball, paisley, starry, the **root-leaf bandana** (0,
  `puppy_kraft_root_fragment`).
- **Hats:** beanie, party hat, explorer hat, wizard hat, and the **crown of
  stamps** (0, `puppy_kraft_return_to_sender`).
- **Capes:** hero cape, leaf cape, the **crystal cape** (0,
  `puppy_kraft_crystal_fragment`), and the **Guardian's cape** (0,
  `puppy_kraft_guardian`).
- **Fur patterns:** Natural (default), socks, spots, saddle, starry
  (`puppy_kraft_howl_night`).

### 12.4 Share card

Two variants, both through the game's `share_art.tscn`:

- The **Day's Diary card**: the pup in their outfit, the growth stage, the
  fragments (x/7), the outing's headline find, the day number and the
  **seed words** (`PK1 · MUDDY-BISCUIT-SQUIRREL-42`) so friends can make the
  same world.
- The **photo card** (§10.2): the player's frame and caption.

Both carry the QR code to `stats_url`.

### 12.5 Gallery

`GALLERY_EXHIBITS`:

- **Breeds**, each gated by its unlock, and the four **growth stages** of the
  mixed pup (Guardian gated).
- **Villagers**, gated by their move-in achievement.
- **Threats:** a raccoon bandit (with loot sack), a grumpy storm cloud, a
  shadow wolf and its spirit-wolf form (gated by `puppy_kraft_root_fragment`).
- **Bosses:** the Mailman King on his tricycle (gated), and later the others.
- **Dioramas:** the starting kennel, the Pack Shrine with all seven pillars
  lit, a Root Temple room and the Crystal Vault, all built from the real structure templates by the same
  `chunk_mesher.gd`.

The stage implements `configure`, `set_view` and `set_auto_spin`.

### 12.6 Accessibility (non-negotiable)

- **Every need, courage and charge** shows a number and an icon, never colour
  alone.
- **Captions** for every meaningful sound: threat approaches with a direction,
  storm crackles, boss telegraphs, the doorbell shockwave, bark responses
  ("The panel rumbles"), water and falling blocks near you, the dusk warning,
  villager greetings.
- **Sniff-vision** names its strongest scent in a caption (§4.4), and trails
  differ by shape and icon.
- **Craft gestures** can be replaced by One press (§6.3). **Bark charge** can
  be Tap to cycle (§4.5). **Sniff** can be Hold or Toggle.
- **Survival pace** Cozy and **Threats** Peaceful (§5.1, §5.4) let anyone
  enjoy the world; neither blocks an achievement.
- **Reduced motion:** smooth camera follow with no shake or punch, static
  scent arrows, calmer decorative animation (ears, tail, grass sway, water
  shimmer), opacity-only fades for cutscene cards. The pup's and creatures'
  movement stays, because it is the gameplay.
- **Intense effects off:** no screen shake, no storm flash (lightning shows as
  a bright outline instead), no shutter flash, a gentler retreat cutscene.
- **P1/P2/P3** tags and shape marks on every pup in Pack mode.
- Touch controls are large, can be repositioned for left- or right-handed
  play, and accept independent multitouch.

### 12.7 Audio — `audio/pk_audio.gd`

Original, game-owned, short sounds: digging per block hardness, placing,
paws on each surface, splashes, yips, woofs and howls (by breed and growth
stage), gestures' flourishes, villagers' voices (cute babble), threats' cues,
the shrine's chime. Synthesised or recorded, never taken from elsewhere.
Every sound that carries meaning has a caption (§12.6).

The current bark-only factory is `audio/bark_audio.gd`, routed through the
shared `AudioManager.play_sfx` pool and SFX volume/mute. Other world sounds and
the full audio facade remain future work.

---

## 13. Tunables and bindings

| Key | Type | Default |
| --- | --- | --- |
| `game/puppy_kraft_survival_pace` | choice: Cozy / Classic / Hardy | Classic |
| `game/puppy_kraft_threats` | choice: Peaceful / Gentle / Adventurous | Gentle |
| `game/puppy_kraft_retreat_penalty` | choice: None / Scent bundle | Scent bundle |
| `game/puppy_kraft_day_length` | choice: Short / Normal / Long | Normal |
| `game/puppy_kraft_craft_gestures` | choice: Gestures / One press | Gestures |
| `game/puppy_kraft_sniff_mode` | choice: Hold / Toggle | Hold |
| `game/puppy_kraft_bark_charge` | choice: Hold / Tap to cycle | Hold |
| `game/puppy_kraft_camera_zoom` | slider 80–125 % | 100 % |
| `game/puppy_kraft_seasonal_events` | toggle | true |
| `game/puppy_kraft_touch_layout` | choice: Thumbs / Left-handed / Right-handed | Thumbs |

The survival and threat options are **per player, not per world**, because
`Settings` stores tunables globally. A world records which settings each
outing used only for the Day's Diary.

Bindings use the prefix `controls/puppy_kraft_`. P1: `left`, `right`, `up`,
`down`, `jump`, `dig`, `place`, `back_wall`, `sniff`, `bark`, `carry`,
`wheel_prev`, `wheel_next`, `craft`, `pet`, `bag`, `map`, `photo`, `regroup`.
P2 and P3 get `p2_*` and `p3_*` copies of the movement and action keys (not
`bag`, `map` or `photo`, which open a shared overlay) with `"player": 1` and
`"player": 2` *(verify P3 support — §15)*. The four movement keys of each seat
are `movement: true`. Gamepads and the mouse are polled in `gameplay.gd`, as
Cube Trials does, and one gamepad attaches to each seat in join order.

---

## 14. Architecture

### 14.1 File layout

```
game.gd                        # GameManifest — copy, theme, achievements, credits
puppy_kraft_options.gd         # constants-only: tunables, bindings, breeds, store,
                               #   gallery, Adventure points table (loaded by path)
gameplay.gd / .tscn            # extends GameShell; inherited scene of game_shell.tscn
intro.tscn                     # five story cards (§1.4)
sim/input_frame.gd             # per seat: move, aim, buttons — every source emits these
sim/blocks.gd                  # block registry (§3.1)
sim/chunk.gd                   # 32×32 × two layers, packed arrays, dirty flags
sim/world_grid.gd              # chunk map, get/set, lazy fill, edit deltas
sim/world_gen/layout.gd        # biome bands, height control points, structure sites
sim/world_gen/terrain.gd       # surface, layers, caves, ore (seeded noise)
sim/world_gen/biomes.gd        # biome table (§3.3)
sim/world_gen/structure_templates.gd  # authored structures (§3.4, §7.2)
sim/world_gen/world_generator.gd      # versioned; layout + chunk fill
sim/seed_words.gd              # words ↔ 64-bit seed
sim/fluids.gd                  # water automaton, falling blocks
sim/lighting.gd                # skylight + block light, per chunk
sim/day_cycle.gd / weather.gd / seasons.gd
sim/puppy_body.gd              # box movement, swim, climb, scrabble, dash (§4.1)
sim/puppy_abilities.gd         # dig, place, bark, fetch, carry, tricks
sim/scent.gd                   # sniff targets and trails (§4.4)
sim/needs.gd                   # hunger, energy, warmth, happiness, courage
sim/inventory.gd               # mouth, wheel, bag, gear
sim/crafting.gd / recipes.gd / gestures.gd
sim/dens.gd                    # den recognition and comfort (§6.2)
sim/creatures/                 # creature_brain.gd, spawner.gd, raccoon.gd,
                               #   storm_cloud.gd, shadow_wolf.gd, crystal_mite.gd …
sim/bosses/                    # boss_runner.gd, mailman_king.gd (later: tomcat, wyrm)
sim/temples.gd                 # puzzle elements: switches, plates, echo, scent locks
sim/npcs/                      # villager.gd, housing.gd, friendship.gd, quests.gd
sim/farming.gd
sim/growth.gd                  # Pawprints, stages, tricks
sim/breed_profiles.gd
sim/quest_line.gd              # the Great Bone Quest and the shrine
sim/vehicles.gd / pets.gd      # after v1
sim/pupedia.gd                 # global collection log
sim/world_state.gd             # owns everything; fixed 60 Hz step; events out
sim/first_steps.gd             # ordered achieved actions and saved walking progress
sim/world_save.gd              # slot files, deltas, compression, atomic writes
input/key_source.gd            # per-seat keyboard
input/pad_source.gd            # gamepads, seat assignment
input/mouse_aim.gd             # solo desktop aiming
input/touch_controls.gd        # thumb pad + buttons (after drive_controls.gd)
world/world_view.gd            # isolated SubViewport, camera, pack framing
world/chunk_mesher.gd          # chunk → mesh, baked light
world/mesh_builder.gd          # copied from cube_trials/world/, adapted
world/puppy_rig.gd / critter_rig.gd
world/scent_trails.gd / weather_fx.gd / sky.gd / backdrop.gd
ui/pk_hud.gd                   # needs, courage, charge pips, mouth wheel, den icon,
                               #   scent caption, quest pin
ui/den_door.gd / .tscn         # world slots, new world, seed words
ui/first_steps.gd              # five-prompt first run
ui/chew_mat.gd / .tscn         # crafting overlay and gestures
ui/bag_panel.gd / map_panel.gd / pupedia.gd / quest_journal.gd / dialogue.gd
ui/photo_mode.gd / .tscn
audio/pk_audio.gd / music_director.gd
assets/models/ assets/icons/ assets/audio/ assets/music/ assets/video/
share_art.gd / .tscn           # Day's Diary card and photo card
store_preview.gd / .tscn       # a pup wearing one item
gallery_stage.gd / .tscn       # turntable
character_preview.gd / .tscn   # breed on the setup plinth
tests/                         # §16
tools/                         # capture_art.gd, tutorial_driver.gd, world_preview.gd,
                               #   structure_preview.gd, seed_scan.gd
README.md · DESIGN.md · TODO.md · AGENTS.md
```

### 14.2 Model / view split

Everything under `sim/` is `RefCounted`. It touches **no autoload and no
node**, and it is what the headless tests exercise. `gameplay.gd` collects one
`InputFrame` per seat per tick, steps `world_state.gd` at a fixed 60 Hz with
an accumulator, and hands the state and its event list (dug, placed, barked,
retreated, discovered…) to `world_view.gd`, the HUD and the audio. The view
may add wag, sway and particles, but it never feeds back into the model. Saves,
seeds, tests and photo mode all depend on that rule.

Simulation radius: chunks within **2 chunks** of any pup are **active**
(creatures, fluids, crops' visual growth). Chunks within 3 are **loaded**
(meshed). Everything else is just data. Crop growth and villager schedules
catch up from the day count when a chunk loads.

### 14.3 `GameShell` hooks used

`game_id`, `_prepare_session`, `_build_playfield`, `_begin_first_round`,
`_load_round_settings` (`super()`), `_reset_round_state`, `_activate_round`,
`_update_round`, `_handle_gameplay_input`, `_finish_round`, `_round_totals`,
`_player_stats`, `_describe_round_outcome`, `_round_highlight_summary`,
`_award_round_achievements`, `_round_points_earned`, `_playfield_bounds`,
`_configure_mode_ui` (`super()`), `_on_game_setting_changed`,
`_set_reduced_motion_enabled` (**`super(value)`**),
`_set_intense_effects_enabled` (**`super(value)`**). Copy the signatures
exactly from `AGENTS.md`.

- With `uses_shell_round_rules = false`, there is no timer and no lives
  pool. Gameplay calls the shell's normal end-of-round path at Call it a day,
  as Cube Trials does at the garage.
- The **Den Door** (world select) is a game-owned panel shown inside
  `gameplay.tscn` before the outing starts. It is not a framework screen.
- `_round_totals` reports Adventure points per seat. `_player_stats` reports
  discoveries, caches, blocks dug and placed, quests, Pawprints, brave tries
  and the growth stage.
- `_describe_round_outcome` returns the Day's Diary headline ("Day 4: the
  Root Temple!").

### 14.4 Manifest sketch

```gdscript
game.id = Options.GAME_ID                       # "puppy_kraft"
game.title = "Puppy Kraft"
game.tagline = "Small pup. Big world. Bigger destiny."
game.menu_order = 13
game.gameplay_scene_path = "res://games/puppy_kraft/gameplay.tscn"
game.intro_scene_path = "res://games/puppy_kraft/intro.tscn"
game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
game.uses_shell_round_rules = false
game.supports_multiplayer = true                # Pack mode
game.supports_cpu_opponent = false
game.max_local_players = 3                      # §19.7
game.local_multiplayer_turns = false            # simultaneous, one screen
game.characters = Options.BREEDS                # §9.3, achievement-gated
game.character_preview_scene_path = ".../character_preview.tscn"
game.save_files = [
	{"path": "user://puppy_kraft_world_1.cfg", "title": "World 1", "description": "…"},
	{"path": "user://puppy_kraft_world_2.cfg", "title": "World 2", "description": "…"},
	{"path": "user://puppy_kraft_world_3.cfg", "title": "World 3", "description": "…"},
	{"path": "user://puppy_kraft_pupedia.cfg", "title": "Pupedia",
		"description": "Everything you've discovered, across every world."},
]
game.tunables / control_bindings / store_* / gallery_* = Options.*
game.tutorial_video_path / tutorial_poster_path
game.stats_url = "https://deskcansaw.com"       # ≤ 42 bytes
game.theme = theme                              # §11.3
```

No `levels`: worlds are slots, not a level list.

---

## 15. Integration checklist (outside this folder)

- [ ] `project.godot`: `config/name.puppy_kraft`,
      `config/custom_user_dir_name.puppy_kraft="DeskCanSaw Games/Puppy Kraft"`
      (stable forever once shipped, so confirm the title first — §19.1),
      `config/icon.puppy_kraft`, `dcs/build/single_game_id.puppy_kraft`,
      `[share] stats_urls/puppy_kraft`.
- [ ] `export_presets.cfg`: a standalone preset with the tag. Add
      `games/puppy_kraft/*` to the other presets' `exclude_filter`, and keep
      `tools/` out.
- [ ] `.gitmodules` and the gitlink (two commits).
- [ ] Root `AGENTS.md`: games table, submodule list, options-file list, test
      table, feature-tag list and a per-game blurb. Update `godot-base/README.md`
      if it lists games.
- [ ] **Verify** that `control_bindings` and `Settings` accept `"player": 2`
      for a third simultaneous seat (`AGENTS.md` documents 0, 1 and −1, and
      `control_actions_for_player(index)` for extra seats). If not, raise it as
      framework data, not a game-name branch.
- [ ] **Verify** that the shell's pause → quit path gives the game a chance to
      autosave (`_exit_tree` or a notification) before the scene is freed.
- [ ] **Verify** that `GameSaves` backups copy a ~2 MB `save_files` entry
      correctly and in reasonable time, on web too (IndexedDB).
- [ ] **Verify** that a `uses_shell_round_rules = false` round with no timer
      can last an hour without any shell-side timeout or HUD timer showing.
- [ ] Run `--import` after adding any `class_name`, and prefer preload-by-path.

---

## 16. Tests — `tests/`

These run headless unless noted. Each one is a standalone `SceneTree` script
that exits 0. The table includes the full-game target; current commands in
`AGENTS.md` cover 13 implemented headless suites and one real-window view suite.
All 14 and the 15 framework suites pass; hardware/playtest gates remain open.

| Suite | Covers |
| --- | --- |
| `blocks_test.gd` | Every block's fields are valid; drops exist; hardness tiers match §6.4; flags are consistent (a `falls` block is solid, a fluid is not placeable on the back wall) |
| `world_gen_test.gd` | Over 50 seeds: the same seed gives byte-identical chunks; chunk fill order doesn't matter; spawn flatness; the shrine and kennel near spawn; no structure overlaps; every loot slot reachable; cache density; the fragment reachability graph with each fragment's required tricks; old generator versions still produce their old output |
| `seed_words_test.gd` | Words ↔ seed round trip; arbitrary strings hash stably; the word list has no duplicates or rude words |
| `world_save_test.gd` | A fresh world saves to a few KB; edits round-trip exactly; the delta never stores unchanged cells; atomic write survives a simulated crash; format and generator versions; pending Adventure points survive a quit |
| `puppy_body_test.gd` | Run, jump height, coyote time, jump buffer; one-cell tunnels fit at every growth stage and breed; no fall damage; swimming and climbing; deterministic for a scripted input |
| `abilities_test.gd` | Dig times per hardness and tool; place rules and support; Dig Deep; bark ranges and costs; fetch arcs; carry and drop; the mouth wheel |
| `scent_test.gd` | Trails find caches through blocks; range per breed; night doubling; each scent kind has an icon and a caption; the retreat bundle is always found |
| `needs_test.gd` | Drain and restore per need; Cozy, Classic and Hardy; hunger never retreats; cold can; the Zoomies buff; huddling |
| `day_cycle_test.gd` | Exact 12/18/30-minute cycles; phase-preserving pace changes; dusk expiry; eighth-night moon and dawn continuity; legacy clock migration; fixed-step determinism |
| `lighting_test.gd` | Skylight per column; block light falloff; an edit relights only its chunks; spawn light threshold |
| `first_steps_test.gd` | Ordered successful actions; actual walking rather than held keys; empty/suppressed input; cancellation; deterministic partial progress; durable Skip |
| `fluids_test.gd` | Water settles; a dug-out pond refills from a source; the per-tick cap; idle chunks stop updating; falling blocks land |
| `dens_test.gd` | Valid and invalid rooms (missing door, light, bed, back wall; too small); comfort scoring; respawn point; villager housing |
| `crafting_test.gd` | Every recipe's ingredients exist; stations; One press and Gestures give the same result; sloppy gestures still craft; recipe discovery |
| `creatures_test.gd` | Nerve, shooing and fleeing; raccoons steal only allowed items and stash at camp; storm zaps telegraph; shadow wolves avoid light; spawn rules and Peaceful; restored wolves turn friendly |
| `mailman_king_test.gd` | Every phase runs; fetching parcels back staggers him; the doorbell wave is jumpable; the blizzard yields to a Ruff; he befriends at zero grump; Pack-mode scaling |
| `temples_test.gd` | Bark switches with pips; fetch plates; echo crystal paths; scent locks; every v1 temple template is solvable by a scripted route |
| `npcs_test.gd` | Arrival triggers; move-in rules; friendship; daily belly rub; quest generation only references things that exist in this world |
| `farming_test.gd` | Watering; one stage per dawn; catch-up on load equals live growth; bone tree yields |
| `growth_test.gd` | Pawprint sources (none from threats); stage thresholds; tricks granted by fragments; Guardian needs seven |
| `quest_line_test.gd` | Fragments in any order; shrine pillars; spirit wolf radius; the v1 ending state |
| `pack_mode_test.gd` | Per-seat input frames; shared camera framing and the edge limit; regroup; nuzzle revive and timeout; huddle; per-seat progress saved |
| `pupedia_test.gd` | Entries record seed and position; global across worlds; merge into the file; never regress |
| `puppy_kraft_scene_test.gd` | Gameplay loads under the shell; the Den Door; a new world reaches the first steps; the HUD binds; pause; Call it a day → results → payout; autosave on quit |
| `world_view_test.gd` *(window)* | Real render: the pup and the target cell in shot; chunk remesh under 2 ms; < 100 draw calls; night lighting from vertex colours; portrait → ultrawide; touch controls clear of the pup; Pack mode framing |

The framework suites pick the game up automatically. Run them all with
`--game=all` before calling a milestone done.

---

## 17. Platforms and budgets

| Platform | Notes |
| --- | --- |
| Desktop | The primary target. Keyboard and mouse solo; keyboard sharing or gamepads for Pack mode |
| Mobile | Touch thumb pad and buttons, single-player only (shell rule), Cozy pace suggested on first run. Small worlds only until profiling says otherwise |
| Web | The same build. Fixed 60 Hz step with an accumulator; saves in `user://` (IndexedDB) |

Budgets *(tune, verify in Milestone 1)*:

| Budget | Target |
| --- | --- |
| Frame rate | 60 fps on a mid laptop (web, 1080p); 30 fps floor on a mid phone |
| Loaded chunks | ≤ 7 × 5 around one pup; ≤ 12 × 6 in Pack mode at the zoom limit |
| Draw calls | < 100 in a surface shot |
| Chunk remesh | < 2 ms each; at most two per frame, the rest queued |
| Fluid updates | ≤ 2000 cells per tick |
| Creatures | ≤ 24 active |
| World file | < 2 MB for a heavily built world |
| New world | Playable in under 1 s (lazy chunk fill, §3.2) |

No gameplay script may branch on the platform. Differences are resolved where
input sources are built and where budgets are set.

---

## 18. Milestones

v1 is Milestones 1–13, after the scaffolding phase in `TODO.md`. Milestones
A–E are the full game, added as content on the same systems.

1. **Block world spike.** ⚠ The riskiest part. `blocks`, `chunk`,
   `world_grid`, a meadow-only generator, `chunk_mesher`, `puppy_body`, dig
   and place, and a camera. *Goal: digging and building feel good, and the
   budgets in §17 hold on web.* Measure chunk remesh time, draw calls and
   frame time before anything else is built on it.
2. **Seeds and saves.** Seed words, the layout pass, lazy chunk fill,
   generator versioning, three world slots, chunk deltas, atomic writes, the
   Den Door.
3. **The pup.** Sniff-vision, bark and charge, fetch and carry, swimming,
   the mouth wheel and bag, needs, courage, day and night, lighting.
4. **Crafting and dens.** The chew mat, gestures and One press, recipes and
   discovery, tool tiers, den recognition and comfort, beds and naps, the
   retreat and its bundle.
5. **Threats.** Raccoon bandits, grumpy storm clouds, shadow wolves, cave
   chills, crystal mites; spawn rules and the Threats tunable.
6. **The v1 world.** Whispering Forest, Crystal Caverns, water, falling blocks,
   every v1 structure, buried caches, ruins, weather.
7. **Base life.** Whiskers, Clover and the Bird Post; housing, friendship,
   quests, belly rubs; farming.
8. **The Great Bone Quest, v1.** The shrine, the Root Temple, the Crystal
   Vault, the Mailman King, spirit wolves, the v1 ending.
9. **Growth and breeds.** Pawprints, stages, tricks, breed profiles,
   `characters` with gates, `character_preview.tscn`.
10. **Pack mode.** Per-seat input, the shared camera, the Pack Board and
    roles, nuzzle revive, huddle, per-seat saves.
11. **Extras.** Photo mode, the pet button, the Pupedia, moonlit howl nights,
    the music director.
12. **Shell features.** Achievements, the store, the gallery, share cards,
    the intro, the theme and icon, credits, the tutorial video.
13. **Polish and integration.** Accessibility sweep, mobile touch pass, web
    pass, framework suites with `--game=all`, the export preset and docs.
    **v1 ships.**

After v1:

- **A. Snowy Peaks and the Sky Islands:** snow and ice, the kite, the Cloud
  Kennel, the Thunder Tomcat, the Storm Fragment, the Snowball festival.
- **B. Sandy Desert:** sand physics at scale, the Sandglass Temple, the Sand
  Fragment.
- **C. Flooded Ruins:** the leaf boat, water puzzles, the Sunken Temple, the
  Tide Fragment, the duck.
- **D. The Deep Hollow:** the minecart, the Cavern Wyrm, the Heart Fragment,
  the baby dragon, Guardian growth, the finale, the Harvest fetch-off.
- **E. Large worlds:** the 3072-wide generator version and its budgets.

**Stretch:** online co-op (needs netcode and a backend the repository doesn't
have); split screen if a profile says it fits; a seed-of-the-week challenge;
mod-friendly structure templates; Spanish localisation.

---

## 19. Open questions for the owner

1. **Title.** "Puppy Kraft" is settled for the docs (the folder and repository
   are `puppy_kraft`). "Kraft" is a food company's trademark and "-craft"
   names evoke Minecraft. Clear the name before it fixes
   `custom_user_dir_name` forever.
2. **The pup's name (resolved).** The player types a name at world creation;
   blank means **Pup**. Use that name in the Den Door, HUD and diary.
3. **Overlap with Dolce's Adventure.** It is also a side-on game about a small
   dog in this collection. Is a second dog side-on game fine, and should the
   art keep them clearly apart?
4. **The v1 boss.** The Mailman King (the funniest, and the start biome) is
   proposed. Confirm, and confirm his final look stays clear of any real
   postal service.
5. **Retreat penalty default.** The scent bundle (half the loose materials) or
   nothing at all?
6. **Music.** A commissioned orchestral score, licensed stems, or the
   studio's synthesised placeholders for v1?
7. **Pack mode seats.** Two or three in v1? Three needs the P3 bindings check
   (§15) and a wider camera budget.
8. **Seasonal events.** Which festivals and dates? A local calendar date means
   the Snowball festival lands in the southern hemisphere's summer. Is that
   fine?
9. **Mobile in v1.** Ship mobile with the v1 slice, or desktop and web first?
10. **Earned and bought cosmetics.** Is the split right: adventure rewards as
    free gated store items, and everything else bought with Kibble?
