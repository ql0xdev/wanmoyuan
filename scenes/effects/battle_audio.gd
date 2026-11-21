extends Node

enum Cue { SWORD, LIGHTNING, HIT, LEVEL_UP, PURCHASE }

const SAMPLE_RATE := 22050
const DURATIONS := [0.13, 0.27, 0.18, 0.45, 0.26]
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for cue in range(DURATIONS.size()):
		var player := AudioStreamPlayer.new()
		player.stream = _make_sound(cue, DURATIONS[cue])
		player.max_polyphony = 2
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)


func play_cue(cue: int) -> void:
	_players[cue].play()


func _make_sound(cue: int, duration: float) -> AudioStreamWAV:
	var samples := PackedByteArray()
	var frames := roundi(duration * SAMPLE_RATE)
	samples.resize(frames * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 6587 + cue
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var p := t / duration
		var sample := 0.0
		match cue:
			Cue.SWORD:
				sample = (0.6 * sin(TAU * (1080.0 * t - 2500.0 * t * t)) + 0.28 * noise.randf_range(-1.0, 1.0)) * pow(1.0 - p, 2)
			Cue.LIGHTNING:
				sample = (0.65 * noise.randf_range(-1.0, 1.0) + 0.35 * sin(TAU * 81.0 * t)) * pow(1.0 - p, 3)
			Cue.HIT:
				sample = (0.72 * sin(TAU * (138.0 * t - 240.0 * t * t)) + 0.20 * noise.randf_range(-1.0, 1.0)) * pow(1.0 - p, 2)
			Cue.LEVEL_UP:
				sample = _note(t, 0.0, 523.25, 0.21) + _note(t, 0.09, 659.25, 0.22) + _note(t, 0.17, 783.99, 0.28)
			Cue.PURCHASE:
				sample = _note(t, 0.0, 880.0, 0.12) + _note(t, 0.065, 1318.51, 0.19)
		sample *= minf(t / 0.005, 1.0)
		samples.encode_s16(i * 2, roundi(clampf(sample, -1.0, 1.0) * 24000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.data = samples
	return sound


func _note(t: float, start: float, hz: float, length: float) -> float:
	var age := t - start
	if age < 0.0 or age >= length:
		return 0.0
	var phase := TAU * hz * age
	var envelope := minf(age / 0.007, 1.0) * pow(1.0 - age / length, 2)
	return (sin(phase) * 0.50 + sin(2.0 * phase) * 0.12) * envelope
