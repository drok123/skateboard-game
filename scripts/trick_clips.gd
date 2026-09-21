class_name TrickClips
## Named AnimationPlayer clips for flatground v1 (beta toast names).

const LOCOMOTION := [
	"idle",
	"push",
	"crouch",
	"land",
]

## Regular-stance v1 — lights HUD toast via trick_started.
const V1_TRICKS := [
	"ollie",
	"kickflip",
	"heelflip",
	"frontside_180",
	"backside_180",
	"backside_shuv",
	"tre",
]

const STUB_LENGTHS := {
	"idle": 1.0,
	"push": 0.6,
	"crouch": 0.25,
	"land": 0.35,
	"ollie": 0.45,
	"kickflip": 0.55,
	"heelflip": 0.55,
	"frontside_180": 0.5,
	"backside_180": 0.5,
	"backside_shuv": 0.5,
	"tre": 0.65,
}

## Air trick hotkeys (physical) — beta only until Controller owns a trick map.
const AIR_TRICK_KEYS := {
	KEY_J: "kickflip",
	KEY_K: "heelflip",
	KEY_U: "frontside_180",
	KEY_I: "backside_180",
	KEY_O: "backside_shuv",
	KEY_P: "tre",
}

static func all_stub_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for n in LOCOMOTION:
		out.append(n)
	for n in V1_TRICKS:
		out.append(n)
	return out


static func pretty_name(trick_name: String) -> String:
	if trick_name == "tre":
		return "Tre Flip"
	if trick_name == "backside_shuv":
		return "Backside Shuv"
	var parts := trick_name.split("_")
	for i in parts.size():
		if parts[i].is_valid_int():
			continue
		parts[i] = parts[i].capitalize()
	return " ".join(parts)
