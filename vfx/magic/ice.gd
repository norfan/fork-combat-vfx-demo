extends RefCounted
## 冰 — ice. A cast makes `count` ice spears (ice/spear.gd), which always fly straight —
## from `self` with a volley they hang in a cloud first (暴雨梨花) — or, staying put (path
## "stay"), a ring of crystals round its start that slows the target (ice/halo.gd); each
## paired hit shatters into ice at the target sized by the cast's `radius`
## (ice/shatter.gd) and freezes it (ice/freeze.gd).

const Spear = preload("res://vfx/magic/ice/spear.gd")
const Halo = preload("res://vfx/magic/ice/halo.gd")
const Shatter = preload("res://vfx/magic/ice/shatter.gd")
const Freeze = preload("res://vfx/magic/ice/freeze.gd")

## An ice cast's defaults (any of them can be set on the `cast` event). Spears crystallise
## slowly and fly fast, speeding up into the target.
const DEFAULTS := {"start": "hand", "end": "target", "path": "straight", "arc": 40.0, "wave": 30.0, "turns": 2.0,
	"ease": 1.6, "charge": 0.35, "travel": 0.22, "count": 1, "interval": 0.09, "spread": 40.0,
	"radius": 60.0, "size": 1.0, "hold": 0.6}

static func cast(spec: Dictionary) -> Array:
	if spec.path == "stay": return [Halo.new().configure(spec)]
	var parts := []
	for i in int(spec.count): parts.append(Spear.new().configure(spec.merged({"index": i, "seed_id": int(spec.seed_id) + i * 7}, true)))
	return parts

static func hit(spec: Dictionary) -> Array:
	return [Shatter.new().configure(spec.merged({"part": "impact"}, true)), Freeze.new().configure(spec.merged({"part": "status"}, true))]
