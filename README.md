# combat-vfx-demo

[中文说明](README.zh-CN.md)

Describe a sword combo in plain words — moves, rhythm, colours, width — and get a Godot 4
scene with fighting-game hit feel: pixel crescents or sampled blade ribbons, star hit sparks, hit-stop,
knockback, launch and slam, screen shake, a hit counter and a finisher. Packaged as an AI
agent skill; the repository itself is a Godot project you can open and play. No art,
plugins or autoloads — every effect is drawn in code.

## Open it in Godot

Import `project.godot` (Godot 4.3+) and press F5: the gallery lists every combo. Each combo
is one scene, `combos/<name>/<name>.tscn`; open one to see its stage in the editor, F6 to
play it on loop. Keys: 1/Space replay, 2 slow motion, R reset, Esc back to the gallery.

```
project.godot   main.tscn (gallery)
vfx/            the effect code: combo_player.gd (scene root), combo_stage.gd (the combo and
                the stock pixel renderer), pixel_slash.gd (pixel smears), combo_style.gd
                (colours), gallery.gd; ink_stage.gd + ink_stroke.gd (the ink renderer);
                ribbon_stage.gd + trajectory_ribbon.gd + trajectory_ribbon.gdshader (blade ribbons)
combos/<name>/  <name>.tscn, combo.json (the events), style.json (the look), prompt.md
styles/         style presets: default, ember, neon, ink
tools/          new_combo.py, verify_combo.py, frames_to_gif.py, frames_to_review.py,
                verify_ink_forms.gd; capture_promo.gd, build_promo.py, review_promo.py (promo video)
references/     combo_events.md (format), choreography.md (request → events)
media/          the GIFs and frame sheets shown below
SKILL.md        agent instructions
```

## As a skill

Put this folder in your agent's skills directory (Claude Code: `~/.claude/skills/combat-vfx-demo/`)
and ask, for example:

> 1st cut horizontal, 2nd vertical chop, 3rd rising, 4th spin, ultimate an aerial combo.
> Rhythm slow slow fast fast fast. Black and red, medium width.

> Three quick thrusts, then an iaido flash with a gold finisher. Neon colours, thin blades.

Anything you leave out uses a default. The agent composes the combo as an event timeline
following [references/choreography.md](references/choreography.md), adds it as a new scene
(to your Godot project, or to a fresh demo project), runs the self-test and checks a frame
sheet of the result.

## Choosing crescents or blade ribbons

Both renderers can draw slashes. **Choose ribbons to show how the weapon moves;
choose crescents for a complete crescent silhouette, a sword-energy shape or an
exaggerated broad cut.** Ribbons also work for finishers, as Rift Dancer demonstrates;
the move's name alone does not decide the renderer.

| Drawing method | Best suited to | `style.json` setting |
|---|---|---|
| Crescent | Broad cuts, sword-energy shapes, attacks with a strong complete silhouette | Omit `renderer`, or set it to `""` |
| Blade ribbon | Weapon-following swings, consecutive clashes, spins, natural trailing and recovery | `"renderer": "ribbon"` |

Specify your choice in the skill prompt, for example:

> Use blade ribbons: two slow cuts, three fast cuts, a spinning launcher and a heavy slam.
> Blue and violet, with a gold finisher.

> Use the original crescent renderer for broad cuts with clear crescent sword-energy shapes.

The renderer is currently selected **for the entire demo**. There is no automatic
per-strike selection; omitting `renderer` still uses crescents. Mixing ribbon swings
and a crescent sword-energy finish through per-strike settings is not implemented.
`ribbon` replaces `slash` events; hit sparks, charge effects and straight cut marks
retain their existing implementations. Selecting a renderer changes the drawing
method; it does not add flying sword-energy gameplay.

Ribbon timing must be authored too: `slash.duration` is the swing time, `tail` is the
retained sample lifetime, and its `hit.t` should be `slash.t + duration / 2`.
Do not change only the renderer name while keeping the old contact timing. See the
[Rift Dancer example](combos/rift_dancer/README.md) and the
[event fields](references/combo_events.md#sampled-trajectory-renderer).

## Examples: prompt → result

Each folder in [combos/](combos) holds the prompt (`prompt.md`), the `combo.json` and
`style.json` an agent wrote for it, and the scene.

### Rift dancer — [combos/rift_dancer](combos/rift_dancer)

Nine strikes with sampled blade ribbons: two deliberate opposing cuts, three fast
blue/violet cuts, a gold spinning launcher, two aerial cuts, and a charged gold slam.
The existing combat feedback and event player drive the new `"renderer": "ribbon"`.
Old trajectory samples narrow, darken and disappear; UVs supply the colour bands.

![Rift dancer](media/rift_dancer.gif)

### Ember launcher — [combos/ember_launcher](combos/ember_launcher)

> A thrust, then an X of two diagonal cuts, a gold rising launcher, and a red air slam to
> finish. Rhythm: slow, fast fast, medium, heavy. Fire colours, bold blades.

![Ember launcher](media/ember_launcher.gif)

### Frost swordsman — [combos/frost_swordsman](combos/frost_swordsman)

> 冰霜剑士：先四下极快的连续突刺，停一拍后旋风斩转两圈，然后上挑把敌人挑飞，追上去空中乱斩三刀，最后一记重劈砸回地面。节奏 快快快快 慢 中 快快快 重。冰蓝配白，细刀光，像素颗粒粗一点。

![Frost swordsman](media/frost_swordsman.gif)

### Cyberpunk set — [neon_ronin](combos/neon_ronin), [neon_iaido](combos/neon_iaido), [neon_overdrive](combos/neon_overdrive)

Three combos on the `neon` preset: a five-cut ronin string, an electromagnetic iaido
flash, and a seven-hit overload thrust chain.

![Cyber ronin](media/neon_ronin.gif) ![Electromagnetic iaido](media/neon_iaido.gif) ![Overload thrust](media/neon_overdrive.gif)

### Ink forms — [combos/ink_forms](combos/ink_forms)

Six forms, seven hits, drawn by a separate brush renderer (`"renderer": "ink"`): pressure
strokes, dry-brush gaps, ink drops and splashes instead of crescents and stars. See
[its README](combos/ink_forms/README.md) and the [move design](combos/ink_forms/design.md).

![Ink forms](media/ink_forms.gif)

## Prompt guide: which words give which effect

Describe **drawing method → move order → rhythm → hit feedback → appearance**.
These are authoring guidelines for the agent: it writes your description into a
timeline and style file. The project does not parse prompt keywords itself.

### Choose how the blade is drawn

| Say | What it looks like | Selection |
|---|---|---|
| "Blade ribbons", "leave a trail behind the swinging blade" | A sampled band grows behind the blade; old sections narrow, darken and disappear | `renderer: ribbon`; suited to swings, clashes and spins |
| "Original crescents", "a complete large crescent silhouette" | An authored crescent opens quickly, then erodes from its old end | Default renderer; suited to broad cuts with a strong silhouette |
| "Ink brush strokes, dry-brush gaps and ink drops" | A separate brush renderer with pressure, fibres and droplets | `renderer: ink`; see Ink Forms |

The renderer applies to the entire demo. A move name such as "horizontal slash"
or "launcher" does not switch it automatically. Unspecified means the default
crescent renderer. The `ink` colour preset alone does not enable the brush renderer.

### Describe the move and the target's reaction

| Say | Move and reaction |
|---|---|
| "One horizontal sweep" | A horizontally spread cut; specify small knockback if wanted |
| "Chop down from overhead" | A high-to-low swing; this alone does not launch or slam the target |
| "Two diagonal cuts forming an X" | Opposite diagonal swings with separate contacts |
| "Three quick thrusts, each stepping forward slightly" | Three narrow stabs sharing a small lunge budget; existing thrust examples use the default renderer's flattened blade |
| "Spin twice, one hit per turn" | Two rotations and two contacts; name rotation count and hit count separately |
| "Swing upward and launch the target" | An upward cut plus upward target velocity; swing direction and target reaction are separate choices |
| "Jump after the target and cut three times in the air" | Attacker pursuit and three light hits that sustain the juggle; vary each swing's direction |
| "An aerial heavy chop slamming the target down" | A downward cut with downward target velocity, landing and bounce; add "as the finisher" for finishing rings |
| "Dash forward, then sweep" | A forward move followed by a sweep attached to the attacker |
| "Charge an iaido flash, pass through, then three delayed cut marks" | Charge, instant repositioning, three delayed marks and authored contacts; marks retain the existing straight-cut effect |

The same move can use different blade renderers. The current attacker is a diamond
marker and the target a block: these requests compose movement, effects and hit
reactions, rather than generating character swing animations.

### Set rhythm, impact and appearance

| Say | What changes |
|---|---|
| "Slow, slow, fast-fast-fast, pause, then heavy" | Two spaced swings, a tight three-cut string and a final wind-up; hit-stop adds to the gaps |
| "Finish this swing sooner", "keep the trail longer" | Swing and recovery timing; ribbons use `duration` for the swing and `tail` for sample lifetime |
| "Light hit, small knockback, subtle shake" | Small hit spark, short hit-stop, light knockback and shake |
| "A gold finisher with heavy hit-stop" | Larger hit spark and rings, longer hit-stop, stronger shake; the completed combo counter uses the accent colour |
| "Ice-blue regular cuts, gold finish" | Assign regular and accent palettes, adjusting background contrast; two unspecified colour roles usually follow this pattern |
| "ember colours", "neon colours", "ink colours" | That preset's palettes and scene colours; choose the drawing method separately |
| "Thin / medium / bold blades" | Width multiplier about ×0.6 / ×1.0 / ×1.4 |
| "Fine / chunky / retro pixels" | 2 / 4–5 / 6 world pixels per texture pixel; default 3 |

A complete prompt:

> Use blade ribbons. Sweep, reverse diagonal, then three quick alternating cuts.
> Pause, spin into a launcher, jump after the target for two aerial cuts, and finish
> with a heavy slam. Slow opening, fast middle, a pause before the finish.
> Alternate blue and violet, gold finish, medium width, pixel 3.
> Subtle shake on light hits, heavy hit-stop on the finisher.

The agent fills unspecified details from the SKILL defaults: a varied 3–4 cut combo
ending in a launcher and finisher, steel blue, medium width, pixel 3, and text in
your prompt's language. Refine a specific beat afterwards: "delay the second cut"
or "make the final blade wider".

## By hand

```bash
python tools/new_combo.py my_combo --combo my_combo.json --style styles/neon.json --thickness bold
python tools/verify_combo.py my_combo --gif --godot /path/to/godot
```

This adds `combos/my_combo/my_combo.tscn` to this project (it shows up in the gallery).
`--project DIR` adds it to another Godot project instead (the `vfx/` scripts are copied in),
or makes a fresh demo project if DIR is new or empty. `--media` on verify_combo.py copies
the GIF and sheet into `media/`. Event format:
[references/combo_events.md](references/combo_events.md).

## Your own renderer

The style presets (`default`, `ember`, `neon`, `ink`) only change colours, width and pixel
size. If you want a different *way of drawing* — brush ink, paper cut-outs, vector glow,
hand-painted sprite frames — add a renderer. The event timeline, hit-stop, knockback,
shake, replay keys, slow motion, frame capture and self-test are shared; a renderer only
decides what each event draws.

1. **Stage** — `vfx/<name>_stage.gd`, `extends ComboStage` (keep `@tool`). Override what
   you want drawn differently and leave the rest to `super`:
   - `_fire(event)`: `slash`, `charge`, `flash_step`, `cut` … (anything you skip →
     `super._fire(event)`);
   - `_hit(event)`: the contact. Keep the stock bookkeeping — `hits += 1`,
     `_target_velocity`, `_stop = event.stop`, `_shake(...)` — or the self-test and hit
     feel break;
   - `_draw()` / `_refresh()`: background and on-screen text, if the look needs them.
2. **Effect nodes** — what you spawn. Any `Node2D` added under `fx` (stage space) or
   `attacker` (follows the attacker) works if it has `advance(delta)` and `is_done()`:
   the stage steps it on the combo clock (so hit-stop and slow motion freeze it too) and
   frees it when done. Draw in `_draw()`; don't use `_process` or wall-clock time.
3. **Select it** — put `"renderer": "<name>"` in the combo's `style.json`;
   `combo_player.gd` then loads `vfx/<name>_stage.gd`. Without the key the stock pixel
   renderer is used.
4. **Extra event fields** — your stage may read its own keys from `combo.json` (the ink
   renderer reads `ink_kind`); other renderers ignore them.
5. **Check** — `verify_combo.py <combo> --gif` still runs the hit-count self-test and the
   frame sheet. Add renderer-specific checks as a script like `tools/verify_ink_forms.gd`.

The ink renderer is the worked example: [vfx/ink_stage.gd](vfx/ink_stage.gd) (~100 lines)
and [vfx/ink_stroke.gd](vfx/ink_stroke.gd) (~120 lines). An agent can do it for you: ask
for "a new renderer in X style, don't recolour the existing smears" and point it at this
section.

## License

MIT — see [LICENSE](LICENSE).
