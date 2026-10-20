# combat-vfx-demo

[中文说明](README.zh-CN.md)

Describe a sword combo in plain words — moves, rhythm, colours, width — and get a Godot 4
scene with fighting-game hit feel: crescent pixel slash smears, star hit sparks, hit-stop,
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
                (colours), gallery.gd; ink_stage.gd + ink_stroke.gd (the ink renderer)
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

## Examples: prompt → result

Each folder in [combos/](combos) holds the prompt (`prompt.md`), the `combo.json` and
`style.json` an agent wrote for it, and the scene.

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

Write moves in order, then rhythm, colours, width. Each phrase maps to a group of effects:

| Say | You get |
|---|---|
| horizontal slash / sweep · 横斩 | a flat crescent across the target, small knockback |
| vertical chop / overhead · 竖劈 | a round crescent from high to low |
| diagonal · 斜斩; "an X" | a tilted crescent; two with opposite tilts cross |
| thrust / stab · 突刺 | a long flat spear-shaped smear and a forward lunge |
| spin / whirlwind · 旋转, 旋风斩 ("two turns") | half-turn crescents chained around the attacker, a hit on each front half |
| rising slash / launcher · 上挑 | an upward crescent; the target is thrown into the air |
| aerial combo · 空中连斩 / 乱斩 | the attacker jumps after the target; quick small hits keep it airborne |
| slam / heavy chop to the ground · 砸地, 重劈 | the target is driven down and bounces, ground ring |
| dash slash · 冲刺斩 | a big lunge with a flat sweep |
| iaido / one flash · 居合, 一闪 | a gold glint, the attacker flashes past the target, cuts appear on it, then a burst |
| ultimate / finisher / 终结 / 必杀 / last "heavy" move | the biggest spark, ring, long hit-stop, strong shake, gold counter |
| rhythm: slow · 慢 / normal · 中 / fast · 快 / blinding · 极快 | long / medium / short gaps; longer or shorter hit-stop per hit |
| colours: two named colours (黑红, ice blue and white …) | the first for regular cuts, the second as the accent on launcher and finisher; background adjusted for contrast |
| a preset name: ember, neon, ink | that preset's palettes and scene colours |
| thin · 细 / medium · 中等 / bold · 粗 | blade thickness ×0.6 / ×1.0 / ×1.4 |
| finer · 细腻 / chunky · 颗粒粗 / retro | pixel size 2 / 4–5 / 6 (default 3) |

Not named means default: a varied 3–4 cut combo ending in a launcher and finisher, steel
blue, medium width, pixel 3, text in the language you wrote in.

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
