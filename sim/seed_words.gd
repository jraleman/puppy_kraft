extends RefCounted

## Three ten-bit words plus a 34-bit number round-trip every signed 64-bit seed.

const PREFIXES: Array[String] = [
	"bright", "muddy", "cozy", "sunny", "tiny", "happy", "gentle", "sleepy",
	"bouncy", "fluffy", "golden", "quiet", "brave", "sweet", "fuzzy", "merry",
	"soft", "warm", "cool", "misty", "leafy", "lucky", "snug", "calm",
	"rosy", "starry", "silky", "crisp", "mellow", "swift", "jolly", "dandy",
]
const NOUNS: Array[String] = [
	"acorn", "biscuit", "squirrel", "puppy", "meadow", "pebble", "willow", "clover",
	"cloud", "button", "muffin", "puddle", "feather", "basket", "ribbon", "blanket",
	"blossom", "lantern", "marble", "ripple", "tulip", "candle", "shell", "twig",
	"bunny", "crystal", "daisy", "cookie", "pillow", "berry", "sparrow", "mitten",
]
const WORD_COUNT := 1024
const WORD_MASK := 0x3ff
const NUMBER_MASK := 0x3ffffffff


static func word_at(index: int) -> String:
	assert(index >= 0 and index < WORD_COUNT, "Seed word index must be ten bits.")
	return (PREFIXES[index >> 5] + NOUNS[index & 31]).to_upper()


static func to_words(seed: int) -> String:
	return "%s-%s-%s-%d" % [
		word_at(seed & WORD_MASK), word_at((seed >> 10) & WORD_MASK),
		word_at((seed >> 20) & WORD_MASK), (seed >> 30) & NUMBER_MASK,
	]


static func from_text(text: String) -> int:
	var cleaned := text.strip_edges()
	var parts := cleaned.to_upper().split("-")
	if parts.size() == 4 and parts[3].is_valid_int():
		var a := _word_index(parts[0])
		var b := _word_index(parts[1])
		var c := _word_index(parts[2])
		var number := int(parts[3])
		if a >= 0 and b >= 0 and c >= 0 and number >= 0 and number <= NUMBER_MASK:
			return a | (b << 10) | (c << 20) | (number << 30)
	var digest := cleaned.sha256_buffer()
	return digest.decode_s64(0)


static func _word_index(word: String) -> int:
	for prefix in PREFIXES.size():
		for noun in NOUNS.size():
			var index := (prefix << 5) | noun
			if word_at(index) == word:
				return index
	return -1
