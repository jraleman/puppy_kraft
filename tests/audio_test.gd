extends SceneTree

## Generated bark cues contain bounded, click-free PCM rather than silent placeholders.

const Sound = preload("res://games/puppy_kraft/audio/bark_audio.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	for level in range(1, 4):
		var stream := Sound.bark(level)
		_expect(stream.get_length() >= 0.1 and stream.get_length() < 0.5
			and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"Every bark must be a short, finite cue without a repeating playback loop.")
		var pcm := stream.data
		var count := pcm.size() / 2
		var power := 0.0
		var peak := 0
		for index in count:
			var sample := pcm.decode_s16(index * 2)
			power += float(sample) * sample
			peak = maxi(peak, absi(sample))
		_expect(sqrt(power / count) > 400.0 and peak < 32000,
			"Level %d must be audible original PCM without clipped full-scale samples." % level)
		_expect(absi(pcm.decode_s16(0)) < 50
			and absi(pcm.decode_s16((count - 1) * 2)) < 50,
			"Bark envelopes must start and finish quietly instead of clicking.")
	if _failures.is_empty():
		print("Puppy Kraft bark-audio tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
