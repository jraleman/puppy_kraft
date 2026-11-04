extends RefCounted

## Original short, soft bark cues; the shared SFX bus owns volume and muting.

const SAMPLE_RATE := 22050

static var _cache: Dictionary[int, AudioStreamWAV] = {}


static func bark(level: int) -> AudioStreamWAV:
	assert(level >= 1 and level <= 3, "Only Yip, Woof and Ruff are implemented.")
	if _cache.has(level):
		return _cache[level]
	var duration: float = [0.16, 0.23, 0.32][level - 1]
	var frequency: float = [640.0, 330.0, 190.0][level - 1]
	var count := ceili(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 7136 + level
	var phase := 0.0
	for index in count:
		var fraction := float(index) / count
		var attack := minf(1.0, float(index) / (SAMPLE_RATE * 0.008))
		var envelope := attack * pow(1.0 - fraction, 1.8)
		phase += TAU * frequency * (1.2 - fraction * 0.65) / SAMPLE_RATE
		var voice := sin(phase) + 0.35 * sin(phase * 2.0) + 0.18 * sin(phase * 3.0)
		var breath := random.randf_range(-0.1, 0.1)
		var sample := clampf((voice + breath) * envelope * 0.55, -0.95, 0.95)
		pcm.encode_s16(index * 2, roundi(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	_cache[level] = stream
	return stream
