@tool
class_name ComboStyle
## The look of a combo: slash palettes, scene colours, slash thickness, pixel size, title and
## on-screen language. Read from the combo's style.json; every missing key keeps the default
## below. Static, because a running demo shows one combo at a time.
## Scene colours by role.
const DEFAULTS := {
	"background": "20262d", "ground": "8a949e", "outline": "14181d", "flash": "fff6ea",
	"dummy": "b8794c", "dummy_band": "6e3f26", "blade": "e8f6ff", "marker_core": "78c4ea",
	"text_gold": "ffe189", "text": "e8eef4",
}
static var data: Dictionary = {}
## Multiplies every slash width (thin 0.6 / medium 1.0 / bold 1.4).
static var thickness := 1.0
## World pixels per slash texel (the pixel-art grain).
static var pixel := 3.0
static var title := "Combo VFX demo"
## On-screen text language: "en" or "zh".
static var language := "en"
const TEXT := {
	"en": {"combo_help": "1 / Space: play   2: slow %s   R: reset   Esc: all combos", "slow_off": "0.25×", "slow_on": "ON", "hits": "%d HITS"},
	"zh": {"combo_help": "1 / 空格：播放　2：慢放 %s　R：重置　Esc：全部连招", "slow_off": "0.25×", "slow_on": "开", "hits": "%d 连击"},
}

static func t(key: String) -> String:
	return String((TEXT.get(language, TEXT["en"]) as Dictionary)[key])

static func load_file(path: String) -> void:
	data = {}
	thickness = 1.0
	pixel = 3.0
	title = "Combo VFX demo"
	language = "en"
	if path.is_empty() or not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("style.json is not a JSON object")
		return
	load_data(parsed)

## The same for a style already in memory (the manual editor).
static func load_data(style: Dictionary) -> void:
	data = style
	thickness = 1.0
	pixel = 3.0
	title = "Combo VFX demo"
	language = "en"
	thickness = float(data.get("thickness", thickness))
	pixel = float(data.get("pixel", pixel))
	title = String(data.get("title", title))
	language = String(data.get("language", language))

## A scene colour by role.
static func c(role: String) -> Color:
	return Color(String((data.get("colors", {}) as Dictionary).get(role, DEFAULTS[role])))

## A four-colour slash palette (brightest first), or `fallback` if the style has none.
static func palette(name: StringName, fallback: Array) -> Array:
	var custom: Variant = (data.get("palettes", {}) as Dictionary).get(String(name))
	if custom is Array and (custom as Array).size() == 4:
		return (custom as Array).map(func(hex: Variant) -> Color: return Color(String(hex)))
	return fallback
