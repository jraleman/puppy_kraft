# Puppy Kraft — TODO

Progress tracker for implementing [`DESIGN.md`](DESIGN.md). Sections follow the
milestones in DESIGN §18, with a scaffolding phase first. Milestones 1–13 are
the **v1 slice** (DESIGN §1.5). A–E are the full game. Tick a box only when the
item works **and** its tests pass. Each phase ends with an exit check.

`§n` points at the matching section of `DESIGN.md`. Run commands from
`godot-base/`. Framework rules from the root `AGENTS.md` still apply.

**Current deliverable:** the playable/saved Milestones 1-2 foundation plus the
Milestone 3 sniffing/barking slices with basic energy, keyboard and mouse first.
This is not the entire v1 slice. Ten headless game
suites, the windowed world-view suite and all 15 host suites pass; scene checks
also run windowed. The desktop profile and remaining manual gates are recorded
below. Staging and committing remain with the owner.

---

## Blocked on the owner (DESIGN §19)

These change names, keys or scope that become permanent once shipped. Nothing
below that depends on one should start until it is answered.

- [x] **Working title and id** — "Puppy Kraft", `puppy_kraft`, matching the
      folder and the `jraleman/puppy_kraft` remote.
- [x] **World view** — a 2.5D side-on block grid in a `SubViewport` (§1.2).
- [x] **Scope** — the full design, with a v1 slice of three biomes, two
      temples, one boss and three fragments (§1.5).
- [x] **Co-op** — same-screen, simultaneous Pack mode (§10.1).
- [ ] **Clear the title** (§19.1) — "Kraft" and "-craft" sit near existing
      marks. Blocks `custom_user_dir_name` in Milestone 13.
- [x] **The pup's name** (§19.2) — player-chosen at world creation; blank means
      **Pup**. The Den Door, HUD and saved state use it.
- [ ] **Overlap with Dolce's Adventure** (§19.3) — a second side-on dog game.
      Blocks the final art direction (Milestone 6 onwards).
- [ ] **The v1 boss** (§19.4) — the Mailman King, and a look clear of any real
      postal service. Blocks Milestone 8.
- [ ] **Retreat penalty default** (§19.5).
- [ ] **Music** (§19.6) — commissioned score, licensed stems or placeholders.
      Blocks the music director's final assets (Milestone 11).
- [ ] **Pack mode seats in v1: 2 or 3** (§19.7) — sets `max_local_players`.
- [ ] **Seasonal events** (§19.8) — festivals, dates, hemispheres. Moonlit howl
      nights are in-game and not blocked.
- [ ] **Mobile in v1?** (§19.9)
- [ ] **Earned vs bought cosmetics** (§19.10).

## Discrepancies found while planning

- [x] Keep **Puppy Kraft** / `puppy_kraft` as the working name/id. No Phase 0
      rename; release title clearance remains separate.
- [x] Godot **4.7.2** is installed through Scoop on the Windows implementation
      host. The earlier 4.6.2 Linux tooling note does not describe this host.
- [x] Keep `menu_order = 13`, reserved after Dolce's Adventure (`9`), Sailor
      Man (`10`), Capitan's Walk (`11`) and Tifo Beato (`12`). Discovery works
      without changing shared catalog code.
- [x] `save_files` uses three fixed world slots (§3.8), not an open list.
- [x] The game-owned Den Door fits inside `gameplay.tscn` (§14.3). The shell
      stays untimed while it is visible; no world ticks before selection.
- [ ] `control_bindings` document `"player"` as 0, 1 or −1. Check that a third
      simultaneous seat (`"player": 2`) works in `Settings` and the Controls
      tab, or raise it as framework data (§15).
- [x] Pause autosaves before opening the shared menu; exit-tree saving covers
      pause → title, and a two-process fixture verifies window-close saving.
- [ ] `GameSaves` backups copy `save_files` bytes into one `ConfigFile`. Check
      that a ~2 MB world backs up and restores correctly, on web too (§15).
- [ ] A `uses_shell_round_rules = false` round with no timer must last an hour
      with no shell timeout or visible timer (§15).
- [x] Keyboard/mouse first for this spike: keys are rebindable, mouse controls
      fixed. Gamepad/touch gameplay adapters remain Milestone 3.
- [ ] Store slots are per game, not per seat, so in v1 one outfit dresses every
      pup in the pack (§12.3). Per-seat outfits would be a framework question.

---

## Phase 0 — Scaffolding

As soon as `game.gd` exists, `GameCatalog` loads it and every framework suite
sweeps it. Start with a stub that passes them, and keep them green from here on.

- [x] Commit `DESIGN.md` and this `TODO.md` to the game repository.
- [x] A folder `AGENTS.md` with game-specific agent notes, as Chicken Pit has.
- [x] `puppy_kraft_options.gd` — constants-only: `GAME_ID`, tunable keys (§13),
      binding keys (§4.2, §13), with empty `BREEDS`, store, gallery and
      Adventure points table for now.
- [x] `game.gd` — minimal manifest (§14.4): id, title, tagline,
      `menu_order = 13`, `CONTROL_STYLE_CUSTOM_KEYS`,
      `uses_shell_round_rules = false`, `supports_cpu_opponent = false`,
      tunables, bindings. Leave multiplayer off until Milestone 10.
- [x] `gameplay.tscn` (inherits `game_shell.tscn`) + `gameplay.gd` (`extends
      GameShell`, `game_id()`, `super(value)` in the reduced-motion and
      intense-effects overrides).
- [x] A `tests/` folder and a smoke test that loads the manifest by path.
- [x] `godot --headless --path . --import`
- [x] A real, game-owned walkthrough and poster for the shared Instructions
      screen, recorded through the shared capture scene and validated driver.
- [x] **Exit:** all 15 framework suites exit 0 with `--game=all`; the game
      opens under the real shared shell rather than a standalone stub.

## Milestone 1 — Block world spike (§3.1, §4.1, §11.1, §17) ⚠ riskiest

- [x] `sim/blocks.gd` — registry with hardness, drops, light, flags, warmth,
      scent; a dozen meadow and cavern blocks.
- [x] `sim/chunk.gd` — 32 × 32 × two layers in packed arrays, dirty flags.
- [x] `sim/world_grid.gd` — chunk map, get/set by cell, edits.
- [x] A meadow-only generator: surface curve, soil and stone layers, simple
      caves.
- [x] `sim/puppy_body.gd` (`RefCounted`, 60 Hz, every constant at the top):
  - [x] Box movement, run, jump with coyote time and a jump buffer
  - [x] One-cell tunnels fit; no fall damage
  - [x] Climbing on ladders and roots through the generic climbable flag;
        vines can use that flag when added in later biomes
- [x] Dig (hold, crack steps, hardness times) and place (support rules) on
      the directional target cell; mouse aim within 3 cells.
- [x] `world/mesh_builder.gd` — copy from `cube_trials/world/` and adapt.
- [x] `world/chunk_mesher.gd` — exposed faces only, back wall tiles, vertex
      colours, one shared material.
- [x] `world/world_view.gd` — isolated `SubViewport`, narrow-FOV side camera,
      look-ahead.
- [x] A grey-box puppy (a box with ears is fine).
- [x] `tests/blocks_test.gd`, `tests/puppy_body_test.gd`.
- [ ] **Exit:** a profile on web and desktop. Record here: chunk remesh time
      (target < 2 ms), draw calls in a surface shot (target < 100), frame time
      on a mid laptop on web (target 60 fps) and on a mid phone (30 fps floor).
      Digging and building feel good to three playtesters. Adjust the chunk
      size, world size and loaded radius (§17) from these numbers before
      moving on.

**Desktop smoke profile:** Godot 4.7.2, Windows, OpenGL 3.3 Compatibility,
RTX 4090 / NVIDIA 610.88. At 1280 × 720, 540 × 960 and 2560 × 1080:
35 mesh chunks, two remeshes maximum per frame, 0.543 ms mean / 1.027 ms maximum
warmed chunk remesh, and 6 / 6 / 6 world draw calls. The windowed suite checks
actual pup/terrain pixels, projection, queue limits and the <2 ms / <100 budgets.
This high-end desktop is not a mid-laptop/web/phone profile. Those hardware
gates and three-person feel checks remain unverified, so the exit stays open.

## Milestone 2 — Seeds and saves (§3.2, §3.8)

- [x] `sim/seed_words.gd` — 1024 friendly compound words (32 prefixes × 32
      nouns), words ↔ signed 64-bit seed, any string
      hashed; no duplicates, nothing rude.
- [ ] `sim/world_gen/layout.gd` — the eager pass: biome bands, height control
      points, structure sites. The PK1 meadow band and kennel/shrine site
      metadata exist; height control points and later-biome layouts are pending.
- [x] Lazy chunk fill that depends only on the seed, the layout and the
      chunk's coordinates.
- [x] `sim/world_gen/world_generator.gd` — versioned (`PK1`); old versions
      kept forever.
- [x] `sim/world_save.gd` — header, pup state, world state, RLE + compressed
      chunk deltas, atomic tmp-and-rename writes.
- [x] Autosave at dawn, Call it a day, pause, exit-tree and window close.
- [ ] Autosave after retreat, when the retreat system exists.
- [x] `ui/den_door.tscn` — three slots with summaries, new world (seed words,
      random or typed), delete with confirmation.
- [x] Declare the three world files in `save_files`.
- [ ] Declare/create the Pupedia when its collection log exists.
- [x] `tests/seed_words_test.gd`, `tests/world_save_test.gd`, first pass of
      `tests/world_gen_test.gd` (determinism, fill order, generator versions).
- [ ] **Exit:** make a world, dig a tunnel, quit, reopen: the tunnel is there,
      and the file is a few KB. The same seed words on another machine give
      the same world.

**Verified locally:** a fresh save is 600 bytes; the edited round-trip fixture
is 1172 bytes. A real scene creates a named world, digs, saves at dawn/pause/exit,
reloads the tunnel and unfinished outing (including the fixed-step remainder),
then closes it at the bed and keeps going without regeneration. Window-close
saving is verified by a second process. Corrupt/newer formats, unsupported
generators and malformed deltas are rejected explicitly. Failed replacements
keep the prior file; orphaned temporary files are ignored. Unknown additive
sections/keys and unpaid points survive saving. Optional energy/rest/cooldown
fields round-trip; older format-1 worlds get explicit defaults without a
format or PK1 change. Held sniff/bark inputs never resume from a save.
Generation is fill-order independent over 50 seeds, with a golden PK1 fingerprint.
Cross-machine confirmation, heavily built <2 MB saves and web backup/restore
profiling remain open; no rewards or Pupedia are claimed.

## Milestone 3 — The pup (§3.6–§3.7, §4, §5.1–§5.2)

- [ ] `sim/input_frame.gd`; `input/key_source.gd`, `input/pad_source.gd`,
      `input/mouse_aim.gd`, `input/touch_controls.gd` (after
      `drive_controls.gd`, independent multitouch).
- [x] `sim/scent.gd` + `world/scent_trails.gd` — existing PK1 crystal/glow-moss
      and home trails through blocks, distinct ore/home icons and shapes,
      six-cell buried outlines, strongest-scent caption, 48/96-cell day/night
      range, half-speed walking, static reduced-motion arrows and Hold / Toggle.
- [ ] Other scent sources: treasure caches, cave/structure/quest targets,
      lost items and night-only finds, as their world systems become available.
- [x] `tests/scent_test.gd` — discovery through walls, range/night transitions,
      live edited-source invalidation, stable ties, Hold/Toggle edge buffering,
      dig suppression and real sniff-to-collection. Scene checks cover rebound L,
      live settings and pause cancellation; composite pixels cover three layouts
      and static reduced motion. The recorded walkthrough demonstrates sniffing.
- [x] Bark: Yip, Woof, Ruff; numbered charge pips; 0/3/8 energy costs;
      rebindable I; Hold / Tap to cycle (1-3 taps, then 0.6s quiet); one-second
      Ruff cooldown; reachable front-leaf collection. Original synthesized
      cues use the shared SFX bus, with captions and bounded wave rings.
- [x] Basic energy only: 100 points, 2/s recovery after 1s grounded and idle;
      saved rest delay and bark cooldown, explicit insufficient-energy feedback,
      cancellation around sniffing, settings and menus, static reduced-motion
      rings and gentler intense-effects-off feedback.
- [ ] Other bark interactions: villagers, critters/threats, snow, echo crystals
      and ancient mechanisms when those world systems exist. No Mighty Howl yet.
- [ ] Fetch and carry: throw arcs, pickups, the mouth wheel (four picks).
- [ ] Swimming (surface paddle); water from a placeholder pond.
- [ ] `sim/inventory.gd` — mouth, wheel, Bandana pouch (8), gear slots.
- [ ] Complete `sim/needs.gd` — hunger, warmth, happiness, running/digging
      energy and low-meter consequences; Zoomies; Cozy, Classic, Hardy.
      Only the basic bark budget above is implemented.
- [ ] Courage: paws, regeneration, the retreat sequence, Groggy, the scent
      bundle; the Retreat penalty tunable.
- [ ] `sim/day_cycle.gd` — dawn, day, dusk, night; Short / Normal / Long; the
      dusk caption; full moon every 8th night.
- [ ] `sim/lighting.gd` — skylight and block light per chunk, baked into
      vertex colours; the nose glow.
- [ ] `ui/pk_hud.gd` — needs, courage, charge pips, mouth wheel, scent
      caption; numbers and icons, never colour alone.
- [ ] `ui/first_steps.gd` — wobble, dig, sniff, bark, nap.
- [x] `tests/abilities_test.gd`, `tests/scent_test.gd`, `tests/needs_test.gd`
      and `tests/audio_test.gd` for implemented abilities and the basic budget.
- [ ] Full survival-needs coverage and `tests/lighting_test.gd` as those systems land.
- [ ] **Exit:** on a grey-box meadow, a new player finishes the first steps,
      sniffs out a buried cache, digs it up and survives a night, by keyboard,
      gamepad and touch.

**Sniffing desktop smoke:** first cold night activation (including generation
and indexing) measured 80.944 ms; 20 cached night scans averaged 1.015 ms.
This initial hitch is not a web/mobile frame-time pass. PK1's golden terrain
fingerprint and old-format world round trips still pass; no cache rewards or
Pupedia entries are invented.

**Barking verified:** real rebound keys and key echo, rapid ordered taps across
sub-tick frames, exact Hold thresholds, cooldown/cost failures, fixed-tick rest,
wall/range/layer-safe leaf collection and old-save defaults. Scene checks
preserve save errors and cancel unfinished charges on pause, nap and setting
changes; a simultaneous bark/bed use leaves no ring over its modal. Composite
pixels and real HUDs pass landscape, portrait and ultrawide. The updated
34-second walkthrough validates all three strengths, rest recovery and a saved
diary, with recorder-only HUD clearance. Full needs and the milestone exit
remain open.

## Milestone 4 — Crafting and dens (§6)

- [ ] `sim/recipes.gd` — v1 recipes for tiers 0–3, furniture, food, gear.
- [ ] `sim/crafting.gd` + `sim/gestures.gd` — three bowls, picture cards,
      five gestures with a forgiving judge, One press; no failure state.
- [ ] Recipe discovery from sniffing ingredients.
- [ ] `ui/chew_mat.tscn` — overlay, cards, gesture prompts, flourish.
- [ ] Tool tiers in the mouth (§6.4).
- [ ] `sim/dens.gd` — room check, door, bed, bowl, light, back wall; comfort
      0–5; respawn point; the "Needs: …" hint.
- [ ] Furniture (§6.5): beds, bowls, toy chests, lanterns, hearth, trophy
      wall, doors and dog flaps.
- [ ] Naps: a bed at night skips to dawn; Call it a day reaches the shell's
      results (placeholder diary).
- [ ] `tests/crafting_test.gd`, `tests/dens_test.gd`.
- [ ] **Exit:** from the starting kennel, craft a stick scoop and a bone
      shovel, build a recognised den elsewhere, sleep in it, retreat and wake
      up there.

## Milestone 5 — Threats (§5.3–§5.4)

- [ ] `sim/creatures/creature_brain.gd` — nerve, boops, flee, steal, stash.
- [ ] `sim/creatures/spawner.gd` — out of view, light < 8, not near dens or the
      shrine, despawn; Peaceful / Gentle / Adventurous.
- [ ] Raccoon bandits (steal, run to camp, raid unlit dens; a bell and light
      protect).
- [ ] Grumpy storm clouds (rain, telegraphed zap, shelter rule, a Ruff puffs
      them).
- [ ] Shadow wolves (fog, stalk, pounce, light and Ruff).
- [ ] Cave chills and crystal mites.
- [ ] Approach cues: a caption with a direction, an icon and a sound for each.
- [ ] `world/critter_rig.gd` — the shared kit; grey-box threats.
- [ ] `tests/creatures_test.gd`.
- [ ] **Exit:** a night in the meadow is tense but fair on Gentle, quiet on
      Peaceful, and every threat can be shooed without a single kill.

## Milestone 6 — The v1 world (§3.2–§3.5, §3.7)

- [ ] Biome table and bands: Sunny Meadows, Whispering Forest, Crystal
      Caverns; edges (sea cliffs, mountain wall).
- [ ] `sim/fluids.gd` — water automaton in active chunks, the per-tick cap;
      falling sand, snow and gravel.
- [ ] Structure templates: starting kennel, Pack Shrine, abandoned dens,
      raccoon camps, buried caches, ruins of the First Dog.
- [ ] Generator rules (§3.2): spawn flatness, shrine near spawn, no overlaps,
      reachable loot, cache density.
- [ ] `sim/weather.gd` — clear, breezy, rain, storm; seeded per day.
- [ ] Biome art: blocks, backdrops, glow moss, crystals; `world/sky.gd`,
      `world/weather_fx.gd` (no storm flash with intense effects off).
- [ ] `tools/world_preview.gd`, `tools/structure_preview.gd`,
      `tools/seed_scan.gd` (scan many seeds for rule failures). Dev-only.
- [ ] `tests/fluids_test.gd`; extend `tests/world_gen_test.gd` (50 seeds,
      structure rules, cache density).
- [ ] **Exit:** fifty seeds pass `seed_scan`, and a playtester can walk from
      the meadow through the forest down into the caverns.

## Milestone 7 — Base life (§8)

- [ ] `sim/npcs/villager.gd` — schedules, hiding from threats, sleeping.
- [ ] `sim/npcs/housing.gd` — arrival triggers, move-in rules (§8.1).
- [ ] Whiskers (cat forge), Clover (rabbit kitchen), Pip and the Bird Post
      (mailbox, deliveries, rumours).
- [ ] `sim/npcs/friendship.gd` — hearts, gifts, daily talk, the daily belly
      rub.
- [ ] `sim/npcs/quests.gd` — fetch, deliver, build, find, visit; only things
      that exist in this world; three active at most.
- [ ] `ui/dialogue.gd`, `ui/quest_journal.gd`.
- [ ] `sim/farming.gd` — tilling, watering, a stage per dawn, catch-up on load;
      berries, treat sprouts, bone trees, moon flowers, pumpkins.
- [ ] Wool from brushing meadow sheep; the weaving nest.
- [ ] `tests/npcs_test.gd`, `tests/farming_test.gd`.
- [ ] **Exit:** a village of three with their own dens, a garden that feeds
      the pup, and a finished quest from each villager.

## Milestone 8 — The Great Bone Quest, v1 (§7.1–§7.3)

- [ ] `sim/quest_line.gd` — fragments in any order, shrine pillars, spirit
      wolves in a widening radius, tricks granted, the v1 ending state.
- [ ] `sim/temples.gd` — bark switches with pips, echo crystals, scent locks,
      fetch plates, dig-through; telegraphed, gentle traps.
- [ ] The Root Temple (4–8 rooms) and the Crystal Vault; murals.
- [ ] `sim/bosses/boss_runner.gd` + `mailman_king.gd` — three phases, grump
      bar, telegraphs with captions, Pack-mode scaling, the befriend scene,
      the Postmaster move-in.
- [ ] Post Office Ruins arena of `unbreakable` ancient stone.
- [ ] Spirit wolves (friendly variant of the shadow wolf rig).
- [ ] Map hints and Bird Post rumours toward each fragment.
- [ ] `tests/temples_test.gd` (scripted solve of each template),
      `tests/mailman_king_test.gd`, `tests/quest_line_test.gd`; add the
      fragment reachability graph to `tests/world_gen_test.gd`.
- [ ] **Exit:** a fresh world can be played to the v1 ending, with all three
      fragments in at least two different orders.

## Milestone 9 — Growth and breeds (§9.1–§9.3)

- [ ] `sim/growth.gd` — Pawprint sources (none from threats), happiness
      multiplier, Newborn → Pup → Junior; Guardian held back for the full game.
- [ ] Tricks: Sit, Fetch, Play bow, Wall Scrabble, Dig Deep, Mighty Howl, Dive.
- [ ] `sim/breed_profiles.gd` — Mixed pup, Corgi, Beagle, Husky, Greyhound;
      authored parameters only.
- [ ] `world/puppy_rig.gd` — the real rig: per-breed proportions and coats,
      growth stages, sockets, run cycle, ear flops, wag, sniff, bark squash,
      emotes; calmer under reduced motion.
- [ ] `BREEDS` as `characters`, achievement-gated; `character_preview.tscn`.
- [ ] `tests/growth_test.gd`; extend `tests/puppy_body_test.gd` (tunnels fit
      every breed and stage).
- [ ] **Exit:** every breed is reachable from a fresh profile through its
      gate, and each one plays noticeably differently.

## Milestone 10 — Pack mode (§10.1)

- [ ] `supports_multiplayer`, `max_local_players` (per §19.7),
      `local_multiplayer_turns = false`.
- [ ] Per-seat input frames: shared keyboard defaults for P2 and P3, one
      gamepad per seat in join order (after the P3 bindings check).
- [ ] Shared camera: frame every pup, zoom-out limit, soft edge, Regroup.
- [ ] The Pack Board in dens; Digger, Scout, Builder, Guard perks.
- [ ] Nuzzle revive with a 10 s window; huddle warmth.
- [ ] P1/P2/P3 tags and shape marks; cosmetics never hide them.
- [ ] Per-seat pup progress in the world file; one shared payout.
- [ ] Mailman King Pack-mode scaling.
- [ ] `tests/pack_mode_test.gd`.
- [ ] **Exit:** three players on one screen play an outing through the Root
      Temple and call it a day, with budgets (§17) holding at the zoom limit.

## Milestone 11 — Extras (§9.4, §10.2–§10.5)

- [ ] `ui/photo_mode.tscn` — freeze, pan and zoom, poses, expressions, filters,
      frames, caption; snap through `share_art.tscn`; no flash with intense
      effects off.
- [ ] Pet-the-puppy button: villager reactions, pet piles, the solo roll-over,
      the threats' once-a-night pause; diminishing returns.
- [ ] `sim/pupedia.gd` + `ui/pupedia.gd` — all tabs, silhouettes and hints,
      seed and coordinates, global file that merges and never regresses.
- [ ] `sim/seasons.gd` — Moonlit howl nights and the howl-along; the Seasonal
      events tunable.
- [ ] `audio/music_director.gd` — stems per biome, state mixing, bar-aligned
      crossfades, boss swell, ducking; placeholder stems.
- [ ] `audio/pk_audio.gd` — dig, place, paws per surface, splashes, barks per
      breed and stage, villagers, threats, shrine.
- [ ] `tests/pupedia_test.gd`.

## Milestone 12 — Shell features (§12)

- [ ] Achievements (§12.1): every key registered, including later-content
      ones; each v1 one reachable on Cozy and Peaceful.
- [ ] Adventure points table (§12.2); `_round_totals`, `_player_stats`,
      `_describe_round_outcome`, `_round_highlight_summary`; pending points
      carried across quits.
- [ ] Store (§12.3): Kibble, five slots (collar and fur always filled), the
      starter catalogue with free gated adventure rewards; `store_preview.tscn`.
- [ ] Gallery (§12.5): breeds, growth stages, villagers, threats, the Mailman
      King, dioramas from real structure templates; `gallery_stage.tscn` with
      `configure`, `set_view`, `set_auto_spin`.
- [ ] Share cards (§12.4): the Day's Diary card with seed words, and the photo
      card.
- [ ] `GameTheme` (§11.3) + `assets/game-icon.png` captured from the rig.
- [ ] `intro.tscn` — five story cards (§1.4).
- [ ] Instructions copy through `manifest.text` keys.
- [ ] Credits.
- [ ] Tutorial video + poster (`tools/tutorial_driver.gd`, `record_tutorials.ps1`).
- [ ] `tests/puppy_kraft_scene_test.gd` (full pass).

## Milestone 13 — Polish and integration (§12.6, §15, §17) — v1 ships

- [ ] Accessibility sweep against §12.6.
- [ ] Mobile touch pass (layouts, left- and right-handed, small worlds) per
      §19.9; web pass (60 Hz accumulator, IndexedDB saves, budgets).
- [ ] `tests/world_view_test.gd` *(window)* — render, remesh time, draw
      calls, night lighting, portrait → ultrawide, touch clear of the pup,
      Pack framing.
- [ ] `project.godot`: `config/name.puppy_kraft`,
      `custom_user_dir_name.puppy_kraft` (after §19.1),
      `config/icon.puppy_kraft`, `dcs/build/single_game_id.puppy_kraft`,
      `[share] stats_urls/puppy_kraft` (≤ 42 bytes).
- [ ] `export_presets.cfg`: a standalone preset; exclude `games/puppy_kraft/*`
      from other presets; keep `tools/` out.
- [ ] `.gitmodules` + gitlink (two commits).
- [ ] Root `AGENTS.md`: games table, submodules, options files, test table,
      feature tags, blurb. Update `godot-base/README.md` if it lists games.
- [ ] Write the folder `README.md` properly.
- [ ] **Exit:** all framework suites + all game suites exit 0 with
      `--game=all`; window suites run without `--headless`.

---

## After v1 (§18)

### A — Snowy Peaks and the Sky Islands

- [ ] New generator version; snow, ice, cloud blocks; snowball yetis, sky gulls.
- [ ] The kite and updrafts.
- [ ] The Cloud Kennel and the Thunder Tomcat; the Storm Fragment; Lightning
      Dash.
- [ ] The Snowball festival.

### B — Sandy Desert

- [ ] Sand physics at scale; dust devils, sand moles.
- [ ] The Sandglass Temple; the Sand Fragment; Wall Scrabble II.

### C — Flooded Ruins

- [ ] The leaf boat; water-level puzzles; grumpy crabs, eel currents.
- [ ] The Sunken Temple; the Tide Fragment; Deep breath.
- [ ] The duck pet.
- [ ] Old Shell and Bramble move in.

### D — The Deep Hollow and the finale

- [ ] Minecart and rails; the Cavern Wyrm chase and arena with regenerating
      fill; the Heart Fragment.
- [ ] The baby dragon pet.
- [ ] Guardian growth, the Spirit of the Pack finale and its credits.
- [ ] The Harvest fetch-off.

### E — Large worlds

- [ ] The 3072-wide generator version and its budgets.

## Stretch (§18)

- [ ] Online co-op (netcode and a backend)
- [ ] Split screen, if a profile says it fits
- [ ] Seed-of-the-week challenge
- [ ] Mod-friendly structure templates
- [ ] Spanish localisation
