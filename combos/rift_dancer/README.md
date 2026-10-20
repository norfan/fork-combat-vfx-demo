# 断空九式 · 轨迹刀光

`rift_dancer.tscn` uses the normal SKILL event timeline and `ComboPlayer`, with
`"renderer": "ribbon"` selecting the retained-trajectory renderer.

Nine strikes: two deliberate opposing cuts, three accelerating blue/violet cuts,
a gold full-turn launcher, two aerial follow-ups, and a charged gold descending
finisher. Hits retain the existing hit-stop, knockback, juggling, counter and
screen shake. Medium thickness, 3-pixel grain and the palette are authored defaults.

Each slash samples its blade at 240 Hz, builds indexed triangle bands with UV birth
times, narrows and darkens old samples, then deletes them. A separated outer stroke
uses the same retained samples. Each stroke follows the attacker; effects advance
only on the stage action clock, so hit-stop and slow motion also hold the ribbon.

The renderer fits each slash's reach and midpoint angle to the target's predicted
contact position, including active attacker motion and target airborne velocity.
This is a demo targeting aid, not gameplay damage logic. Each hit checks that its
contact point is inside the actual visible ribbon geometry for that rendered frame.

Open the scene and press F6, or choose Rift Dancer in the F5 gallery. 1/Space replays,
2 toggles quarter speed, R resets, and Esc returns to the gallery.

Validation: `tools/verify_combo.py rift_dancer --gif --keep-frames --godot PATH`.
The headless test must print `PASS: 9 hits landed`; contact misses fail verification.
