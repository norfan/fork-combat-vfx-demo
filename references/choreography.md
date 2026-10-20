# Composing a combo from a request

A request names moves, a rhythm, colours and a width, e.g. "1st cut horizontal, 2nd
vertical chop, 3rd rising, 4th spin, ultimate an aerial flip combo; rhythm slow slow fast
fast fast; black and red; medium width". This file teaches how to turn that into events
(format: `combo_events.md`). Nothing here is a finished combo to copy: derive the numbers
from the request, and make each combo its own.

## What makes a combo feel good

1. **Contrast.** Rhythm is the difference between gaps, not the gaps themselves. Fast
   strings only feel fast next to a pause; a big hit only feels big after small ones.
2. **The freeze sells the impact.** Hit-stop (`stop`) is the strongest tool. Small hits
   freeze briefly, the finisher freezes several times longer, shakes harder and sparks
   bigger.
3. **Every cut changes something.** Alternate swing directions (down, up, across), shift the
   tilt, lunge on heavy cuts. Two identical slashes in a row read as a stutter.
4. **Escalate.** Width, spark and shake grow over the combo; colour may switch on the last
   one or two moves (e.g. `normal` → `gold` or `red`).
5. **Follow the target.** If a hit launches the target, move the attacker up after it
   (`move` with negative dy) before the next swing, then come back down.

## 1. Moves → slash shapes

Think in terms of the swing's direction around the attacker (0° = toward the target, y down).

| Move (also called) | How to shape it |
|---|---|
| Horizontal slash (横斩, sweep) | flattened ellipse: `squash` 0.4–0.7, swing across 0° (e.g. `from` around −80, `to` around +70), small `tilt` |
| Vertical chop (竖劈, overhead) | round arc (`squash` ~1) from high up to below 0°: `from` −100…−120, `to` +50…+80; optional short `move` forward |
| Rising slash (上挑, launcher) | the reverse: `from` +80…+100, `to` −90…−120; its hit has a negative `launch` |
| Diagonal (斜斩) | flattened sweep with `tilt` ±20…35; pair two with opposite tilts for an X |
| Thrust (突刺, stab) | very flat ellipse through 0°: `squash` 0.15–0.2, large `radius` (180–240), wide `width` (80–150), with a forward `move` at the same `t`. A flurry of thrusts shares one lunge budget: keep the attacker's total forward travel under ~100 px |
| Spin (旋转攻击) | half-turn slashes back to back, 0.06–0.1 s apart, each continuing where the last ended (−90→90, 90→270, …); one turn = two halves, "two turns" = four. Put a hit on each front half (the ones crossing 0°); the back halves are the wind-up and usually don't hit |
| Aerial combo (空中连斩) | after a launcher: `move` up (dy −100…−160), then quick alternating slashes with small hits (small `push`, `stop` 0.03–0.05) while the target hangs; end with a slam (`launch` > 500) and a `move` back down |
| Dash slash (冲刺斩) | a large forward `move` (dx 60–120, time 0.05–0.08) at the same `t` as a flat sweep |
| Iaido / one flash (居合, 一闪) | `charge` → `flash_step` → two or three `cut`s (each with a small hit, 0.04–0.08 s apart) → a big finisher hit |

The hit is always drawn on the target; your job is that the crescent visibly reaches it.
From the start position the target is ~145 px away, so `radius` ≥ ~150 unless the attacker
has moved closer.

Any move not listed: build it from these pieces (slash + move + hit, plus charge /
flash_step / cut for special moves) and say in the report how you built it.

## 2. Rhythm → times

Rhythm words map to moves in order ("慢 慢 快快快" = one word per move). Fewer words than
moves: the last word repeats. A move made of several slashes (spin, aerial combo, a thrust
flurry) takes one word: it sets the gap before the move and the stop/shake of every hit in
it, and the next gap is measured from the move's last slash. The slashes inside a
multi-slash move are as close as the tempo's gap, or closer.

Intensifiers stretch the table: 极快 / blinding = the low end of fast or a bit below
(0.06–0.09 s); 极慢 / very slow = above slow (0.5 s+). The word for the last move that
reads as power — 重 / heavy / 终结 / 必杀 / ultimate — makes it the finisher. A move is the
finisher when it is the last one, or the user calls it that; a 慢 / heavy move in the middle
is just slow. Choose numbers inside these ranges and vary them a little
so the combo doesn't sound mechanical.

| Tempo | gap before the move (s) | `stop` | `shake` | `spark` |
|---|---|---|---|---|
| slow (慢, heavy) | 0.30–0.45 | 0.07–0.10 | 3.5–5 | 55–70 |
| normal (中, steady) | 0.16–0.25 | 0.05–0.06 | 2.5–3.5 | 45–55 |
| fast (快, quick) | 0.08–0.14 | 0.03–0.05 | 1.5–2.5 | 38–46 |
| finisher (终结, 必杀, ultimate) | its own tempo word, plus a short wind-up (`charge` or a 0.1–0.2 s rise) | 0.12–0.16 | 8–10 | 100–130, `finisher: true` |

The gap is measured from the previous move's slash to this move's slash; the hit goes 0.03–
0.05 s after its slash. Hit-stops are added on top (the clock stops), so you don't subtract
them.

## 3. Width and pixel size

Per-slash `width`: light cuts 30–45, heavy cuts 50–70, thrusts 80–150, finisher the widest
non-thrust slash. The user's width word goes into `style.json` `thickness`: thin/细 0.6,
medium/中等 1.0, bold/粗 1.4 (it scales every width).

`pixel` is the size of one slash texel in screen pixels: finer/细腻 2, default 3,
chunky/颗粒粗 4–5, retro/very chunky 6. Big pixels with thin blades make short slashes
blobby; widen thrusts a little to compensate.

## 4. Colours → palettes

`style.json` has five palette slots (`normal`, `violet`, `red`, `gold`, `green`), each
`[core, highlight, body, edge]`, brightest first. The names are only slots: put any colours
in them (an ice-white accent in `gold` is fine). Events pick a slot by name. Usually:
`normal` for the regular cuts, one accent slot for the launcher/finisher. `charge` and
`flash_step` always use `gold`. `styles/default.json` lists every default value.

The accent should differ from `normal` in hue or lightness, or the escalation is lost; for a
two-colour request (ice blue + white) make one the regular cuts and the other the accent.

- Core and body must stand out from the background (clearly different lightness); edge
  differs from both.
- Named colours go into body and edge; core and highlight are lighter tints of the body so
  the blade glows.
- A colour darker than any sensible background (black, navy, deep purple) goes on the
  **edge**, and the background becomes light (grey, paper, sand) so the blade still reads.
- Scene colours (`colors` in style.json): `background`, `ground`, `outline`, `flash` (target
  on hit), `dummy` and `dummy_band` (target block), `blade` (hit counter text),
  `marker_core` (attacker), `text_gold` (counter after the finisher; set it to your accent).
  Recolour `dummy`/`dummy_band` too if the brown block clashes with the theme.

Example, "black and red": `normal` = `["fff0ec", "ff5a4a", "c8102e", "0a0a0a"]`, an accent
`red` with a deeper body, on background `c9c2b8`, ground `5a524a`, outline `1a1a1a`.

## Checklist before verifying

- One `hit` per strike the request implies (a spin 2–3, an aerial combo 3–5, the finisher 1).
- Gaps follow the rhythm words; the finisher has the longest `stop` and biggest `shake`.
- No two consecutive slashes share the same direction and shape. When the user asks for a
  repeated move (four thrusts), keep the move but vary it: alternate the swing direction,
  nudge tilt, radius and width, and let spark and shake grow along the string.
- The attacker ends near the ground; it stays behind the target (watch the total of the
  forward moves against the target's knockback).
- Run `tools/verify_combo.py <name> --gif` and read `verification/<name>/combo_sheet.png` (frames from
  start to finish in a grid): crescents reach the target, launches/slams look right, the
  finisher stands out. The sheet has at most 18 tiles, so a fast string falls between them;
  to inspect one, add `--keep-frames` and tile just that stretch:
  `python tools/frames_to_review.py <project>/verification/<name>/frames part.png --frames 0 3 6 9 12 15`
  (frame n is at n/60 s). Fix and re-run if not.
