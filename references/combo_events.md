# combo.json — the event timeline

Each combo lives in `combos/<name>/` of a Godot project: `<name>.tscn` (a `ComboPlayer` node
whose `combo_file` and `style_file` point at the two JSON files), `combo.json`, `style.json`
and `prompt.md`. `tools/new_combo.py` writes all of them.

A combo is a list of timed events. The demo fires each event when the combo clock reaches
its `t`; during a hit-stop the clock (and everything on screen except the target's shudder)
stops, so `t` is "combo time", not wall time.

```json
{
  "name": "free text, shown nowhere",
  "events": [
    {"t": 0.00, "do": "slash", "radius": 160, "from": -70, "to": 70, "width": 44},
    {"t": 0.04, "do": "hit", "push": 60, "stop": 0.05, "shake": 2.5, "spark": 46}
  ]
}
```

Events may be in any order (they are sorted by `t`). Any field marked *default* may be left
out.

## The stage

Screen 1280 × 720, y grows downward, the attacker faces right.

| Thing | Position |
|---|---|
| ground line | y = 520 |
| attacker (diamond marker) start | (430, 450) — 70 px above the ground |
| target (block, 44 × 96) start | feet at (575, 520); its centre is ~145 px right of and ~20 px below the attacker |

The camera is fixed; only the screen shake moves it.

## Angles

Slash angles are in degrees around the attacker: **0° points right at the target**, −90° is
straight up, +90° straight down. `from` → `to` is the direction of the swing:
`from: -70, to: 70` swings top to bottom, `from: 90, to: -90` swings bottom to top.

## Events

### `slash` — a crescent smear grown from the attacker
| Field | Meaning | Default |
|---|---|---|
| `radius` | reach in px; must be ≥ ~150 to cross the target from the start position (less after a `move` toward it) | 140 |
| `from`, `to` | start and end angle of the swing (see above); any values, so 90 → 270 sweeps behind the attacker and −90 → 270 is a full circle | −70, 70 |
| `width` | thickness of the crescent at its fattest, px (× `style.thickness`) | 44 |
| `squash` | vertical flattening of the swing ellipse; 1 = round arc, ~0.5 = a sideways sweep seen from the side, ~0.15–0.2 through 0° = a thrust | 1 |
| `tilt` | rotates the whole ellipse, degrees; tilts a flattened sweep into a diagonal | 0 |
| `palette` | `normal`, `violet`, `red`, `gold` or `green` (colours come from style.json) | normal |

The crescent grows in 0.045 s, holds 0.04 s and fades over 0.13 s. It is attached to the
attacker, so a `move` at the same `t` drags it along (that is what gives a lunge its weight).

#### Sampled trajectory renderer

Set `"renderer": "ribbon"` in `style.json` to use `ribbon_stage.gd` with the same
event player. `slash` accepts `duration` (swing seconds, default 0.16) and `tail`
(retained sample lifetime, default 0.18), plus the normal angle, squash, tilt, width
and palette fields. Its reach is fitted to the target's predicted contact position;
`radius` is not used by this renderer. The midpoint of `from` and `to` crosses the
target at half `duration`, so pair each slash with a `hit` at `slash.t + duration / 2`
rather than the stock crescent's fixed 0.03–0.05 s delay. Put simultaneous `move`
events before the slash so targeting can account for the movement.

This renderer grows a triangle band from blade samples, shades UV breadth and
birth time, and thins/deletes old samples. It shares the stage action clock and
checks the visible ribbon covers every hit point. `combos/rift_dancer/` is the
complete nine-hit example; `combos/trajectory_slash/` is the single-cut study.

### `move` — the attacker glides
| Field | Meaning | Default |
|---|---|---|
| `by` | `[dx, dy]` offset in px (negative dy = up) | [0, 0] |
| `time` | seconds of the glide (eased) | 0.08 |

Moves add up; keep the attacker roughly between x 380 and the target, and bring it back down
to y ≈ 450 by the end if it jumped.

### `hit` — the target is struck
| Field | Meaning | Default |
|---|---|---|
| `push` | added to the target's horizontal speed, px/s. On the ground friction (1600 px/s²) stops it, so a lone push of v slides about v²/3200 px (140 → 6 px, 260 → 21 px, 400 → 50 px); in the air it keeps drifting until it lands | 60 |
| `launch` | **replaces** the target's vertical speed, px/s: negative throws it up, a large positive one (> 500) slams it down so it bounces once | none |
| `stop` | hit-stop seconds: everything freezes, the target shudders | 0.05 |
| `shake` | screen-shake strength, px | 2.5 |
| `spark` | size of the star spark, px | 46 |
| `palette` | spark colours | normal |
| `finisher` | `true`: spark at the target's centre, 12 rays, a ring and a ground ring, longer shake, the hit counter turns gold | false |

Gravity is 1500 px/s². A launch of −v keeps the target in the air for about 2v/1500 s
(−640 → ~0.85 s, peak ~135 px up). To keep juggling, give later air hits a small negative
`launch` (−200…−300): because launch replaces the vertical speed, each one re-lifts the
target. Plan the slam to arrive before the target lands. The target can't leave the screen
(it is held between x 80 and 1200).

Every `hit` adds one to the counter and is what the self-test counts. Put it ~0.03–0.05 s
after its slash so it lands while the crescent is fully grown.

### `charge` — a gold glint gathers on the attacker
No fields. Lasts ~0.25 s; leave that much before the next event.

### `flash_step` — the attacker vanishes and reappears past the target
| Field | Meaning | Default |
|---|---|---|
| `past` | how far beyond the target it reappears, px | 140 |

Leaves a long gold streak, then the whole scene holds still for 0.1 s.

### `cut` — a straight cut drawn across the target's body
| Field | Meaning | Default |
|---|---|---|
| `angle` | direction of the cut, degrees (0 horizontal, ±35 diagonals, 90 vertical) | 0 |
| `palette` | colours | normal |

A `cut` does not count as a hit; pair it with a `hit` at the same `t` if it should.

## Run flags (for scripts)

After `--`: `--verify` (headless; prints `PASS: N hits landed`), `--capture=FILE
--capture-at=S`, `--frames=DIR --duration=S`. `tools/verify_combo.py` uses them for you.
