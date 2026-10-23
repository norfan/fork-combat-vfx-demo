extends RefCounted
## 火 — fire. A cast makes `count` fireballs (fire/fireball.gd); each paired hit makes an
## explosion sized by the cast's `radius` (fire/explosion.gd) and sets the target burning
## (fire/burn.gd).

const Fireball = preload("res://vfx/magic/fire/fireball.gd")
const Pillar = preload("res://vfx/magic/fire/pillar.gd")
const Explosion = preload("res://vfx/magic/fire/explosion.gd")
const Burn = preload("res://vfx/magic/fire/burn.gd")

## A fire cast's defaults (any of them can be set on the `cast` event).
const DEFAULTS := {"start": "hand", "end": "target", "path": "arc", "arc": 70.0, "wave": 40.0, "turns": 2.0,
	"ease": 1.25, "charge": 0.22, "travel": 0.36, "count": 1, "interval": 0.12, "spread": 36.0,
	"radius": 70.0, "size": 1.0, "hold": 0.0}

static func cast(spec: Dictionary) -> Array:
	# From under the floor it is a pillar of fire: one body, `count` hits while it burns.
	if spec.start == "below": return [Pillar.new().configure(spec)]
	var parts := []
	for i in int(spec.count): parts.append(Fireball.new().configure(spec.merged({"index": i, "seed_id": int(spec.seed_id) + i * 7}, true)))
	return parts

## The impact and the status (the stage restarts a running status instead of adding one).
static func hit(spec: Dictionary) -> Array:
	return [Explosion.new().configure(spec.merged({"part": "impact"}, true)), Burn.new().configure(spec.merged({"part": "status"}, true))]
