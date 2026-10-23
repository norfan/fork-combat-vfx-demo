extends RefCounted
## 雷 — lightning. A cast makes `count` strikes (thunder/bolt.gd); each paired hit makes the
## strike's impact sized by the cast's `radius` (thunder/strike.gd) and leaves the target
## electrified (thunder/shock.gd).

const Bolt = preload("res://vfx/magic/thunder/bolt.gd")
const Shield = preload("res://vfx/magic/thunder/shield.gd")
const Strike = preload("res://vfx/magic/thunder/strike.gd")
const Shock = preload("res://vfx/magic/thunder/shock.gd")

## A thunder cast's defaults (any of them can be set on the `cast` event). `travel` is how
## long the leader takes to reach the end, `hold` how long the strike keeps pulsing and
## `jag` how hard the channel zigzags.
const DEFAULTS := {"start": "hand", "end": "target", "path": "straight", "arc": 40.0, "wave": 30.0, "turns": 2.0,
	"ease": 1.0, "charge": 0.3, "travel": 0.08, "count": 1, "interval": 0.14, "spread": 30.0,
	"radius": 60.0, "size": 1.0, "hold": 0.22, "jag": 0.28}

static func cast(spec: Dictionary) -> Array:
	# Staying put, lightning is a shield of arcs around its start: one body that bursts
	# when it lands.
	if spec.path == "stay": return [Shield.new().configure(spec)]
	var parts := []
	for i in int(spec.count): parts.append(Bolt.new().configure(spec.merged({"index": i, "seed_id": int(spec.seed_id) + i * 7}, true)))
	return parts

static func hit(spec: Dictionary) -> Array:
	return [Strike.new().configure(spec.merged({"part": "impact"}, true)), Shock.new().configure(spec.merged({"part": "status"}, true))]
