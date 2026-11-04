extends SceneTree

## Full-width seed round trips and stable arbitrary UTF-8 seed text.

const Seeds = preload("res://games/puppy_kraft/sim/seed_words.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	var words := {}
	for index in Seeds.WORD_COUNT:
		var word := Seeds.word_at(index)
		_expect(not words.has(word) and word.find("-") == -1,
			"The fixed friendly word list must have no ambiguous or duplicate words.")
		words[word] = true
	var seeds: Array[int] = [0, 42, -1, 9223372036854775807, -9223372036854775807 - 1]
	var random := RandomNumberGenerator.new()
	random.seed = 751
	for sample in 32:
		seeds.append((int(random.randi()) << 32) | int(random.randi()))
	for seed in seeds:
		var words_for_seed := Seeds.to_words(seed)
		_expect(Seeds.from_text(words_for_seed) == seed
			and Seeds.from_text(words_for_seed.to_lower()) == seed,
			"Canonical words must retain every seed bit, including the sign: %d." % seed)
	_expect(Seeds.from_text("hello") == 0x0ea3b05fba4df22c,
		"Arbitrary text must keep the documented SHA-256 little-endian seed mapping.")
	_expect(Seeds.from_text("hello") != Seeds.from_text("Hello")
		and Seeds.from_text("caf\u00e9") != Seeds.from_text("cafe"),
		"Arbitrary text must preserve case and UTF-8, rather than collapse distinct seeds.")
	_expect(Seeds.from_text("  hello  ") == Seeds.from_text("hello"),
		"Whitespace around typed seed text must not accidentally change a world.")
	var invalid_number := "BRIGHTACORN-BRIGHTACORN-BRIGHTACORN-17179869184"
	_expect(Seeds.from_text(invalid_number) != 0,
		"A noncanonical numeric suffix must hash as text, not overflow into the zero seed.")
	if _failures.is_empty():
		print("Puppy Kraft seed-word tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
