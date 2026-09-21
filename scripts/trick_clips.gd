class_name TrickClips
## Named AnimationPlayer clips for flatground v1.
## Names match the flatground reference video's on-screen labels (regular stance first).

## Loopable locomotion — ship these stubs first.
const LOCOMOTION := [
	"idle",
	"push",
	"crouch",
	"land",
]

## Priority trick stubs for the prototype (regular stance).
const V1_TRICKS := [
	"ollie",
	"kickflip",
	"heelflip",
	"frontside_180",
	"backside_180",
	"backside_shuv",
]

## Placeholder lengths (seconds) until real keyframes land.
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
}

static func all_stub_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for n in LOCOMOTION:
		out.append(n)
	for n in V1_TRICKS:
		out.append(n)
	return out
