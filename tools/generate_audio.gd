extends SceneTree

## Synthesises every sound the game uses and writes them to assets/audio/ as
## 16-bit mono WAV files. There are no recorded or downloaded sounds: the
## files are built from sine waves, filtered noise and envelopes, which also
## suits the low-poly look. The same seed always gives the same files.
##
##   godot --headless --path . --script res://tools/generate_audio.gd
##
## Looping sounds (ambience, music) are made seamless here, and their import
## settings set forward looping (see LOOPED in sound_bank.gd).

const RATE := 22050
const OUT := "res://assets/audio/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 2026
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Player and guard footsteps: four variations each.
	for i in 4:
		_save("player_step_%d" % (i + 1), _step(0.075, 900.0 + i * 120.0, 95.0 + i * 8.0, 0.55))
		_save("guard_step_%d" % (i + 1), _mix([_step(0.1, 620.0 + i * 70.0, 70.0 + i * 6.0, 0.8), _click(0.02, 2400.0 + i * 300.0, 0.18)]))
	_save("guard_keys", _keys())
	_save("guard_radio", _radio())
	# Interaction and objectives.
	_save("card_pickup", _mix([_bell(1318.5, 0.55, 0.5), _delay(_bell(1975.5, 0.45, 0.35), 0.07)]))
	_save("objective_complete", _mix([_bell(659.3, 0.6, 0.45), _delay(_bell(987.8, 0.6, 0.45), 0.12)]))
	_save("checkpoint", _mix([_soft(523.3, 0.9, 0.3), _delay(_soft(659.3, 0.8, 0.3), 0.1), _delay(_soft(784.0, 0.7, 0.3), 0.2)]))
	_save("door_locked", _rattle())
	_save("door_open", _mix([_sweep_noise(0.7, 300.0, 1800.0, 0.35), _delay(_bell(784.0, 0.8, 0.35), 0.15)]))
	# Detection feedback.
	_save("notice", _bell(1480.0, 0.25, 0.3))
	_save("suspicious", _mix([_tri(493.9, 0.18, 0.4), _delay(_tri(740.0, 0.3, 0.4), 0.15)]))
	_save("alarm", _alarm())
	_save("lost_track", _mix([_tri(587.3, 0.2, 0.3), _delay(_tri(392.0, 0.4, 0.3), 0.18)]))
	_save("caught", _caught())
	_save("victory", _victory())
	# UI.
	_save("ui_hover", _click(0.03, 2000.0, 0.25))
	_save("ui_click", _tri(880.0, 0.08, 0.4))
	_save("ui_pause", _sweep_tone(0.25, 700.0, 350.0, 0.35))
	_save("ui_resume", _sweep_tone(0.25, 350.0, 700.0, 0.35))
	# Environment.
	_save("amb_room_tone", _loopable(_room_tone(8.0), 0.5))
	_save("amb_clock_tick", _clock(2.0))
	_save("amb_page_turn", _sweep_noise(0.45, 2500.0, 5000.0, 0.25))
	_save("amb_book_thud", _step(0.22, 500.0, 80.0, 0.6))
	_save("amb_chair_creak", _creak())
	# Music layers.
	_save("music_tension", _loopable(_tension(8.0), 0.5))
	_save("music_chase", _chase(4.0))
	print("Generated sounds in %s" % OUT)
	quit(0)


# --- Building blocks (all return PackedFloat32Array at RATE, range −1..1) -------------------

func _n(seconds: float) -> int:
	return int(seconds * RATE)


func _env(i: int, n: int, attack := 0.005, curve := 4.0) -> float:
	var t := float(i) / RATE
	var a := minf(t / attack, 1.0) if attack > 0.0 else 1.0
	return a * pow(1.0 - float(i) / n, curve)


func _step(length: float, cutoff: float, thump_hz: float, gain: float) -> PackedFloat32Array:
	var n := _n(length * 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var k := 1.0 - exp(-TAU * cutoff / RATE)
	for i in n:
		lp += k * (_rng.randf_range(-1.0, 1.0) - lp)
		var thump := sin(TAU * thump_hz * i / RATE) * pow(1.0 - float(i) / n, 6.0)
		out[i] = (lp * 1.6 * _env(i, _n(length), 0.002, 3.0) * float(i < _n(length)) + thump * 0.7) * gain
	return out


func _click(length: float, hz: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sin(TAU * hz * i / RATE) * _env(i, n, 0.001, 3.0) * gain
	return out


func _bell(hz: float, length: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var mod := sin(TAU * hz * 2.0 * t) * 1.5 * exp(-t * 6.0)
		out[i] = sin(TAU * hz * t + mod) * _env(i, n, 0.003, 2.5) * gain
	return out


func _soft(hz: float, length: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)) * _env(i, n, 0.04, 2.0) * gain
	return out


func _tri(hz: float, length: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var phase := fmod(hz * i / RATE, 1.0)
		out[i] = (4.0 * absf(phase - 0.5) - 1.0) * _env(i, n, 0.01, 1.5) * gain
	return out


func _sweep_tone(length: float, from_hz: float, to_hz: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		phase += lerpf(from_hz, to_hz, float(i) / n) / RATE
		out[i] = sin(TAU * phase) * _env(i, n, 0.01, 1.5) * gain
	return out


func _sweep_noise(length: float, from_hz: float, to_hz: float, gain: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var cutoff := lerpf(from_hz, to_hz, float(i) / n)
		var k := 1.0 - exp(-TAU * cutoff / RATE)
		lp += k * (_rng.randf_range(-1.0, 1.0) - lp)
		hp += 0.05 * (lp - hp)
		var shape := sin(PI * float(i) / n)
		out[i] = (lp - hp) * shape * gain * 2.0
	return out


func _keys() -> PackedFloat32Array:
	var parts: Array = []
	for j in 3:
		var hz := _rng.randf_range(3200.0, 5200.0)
		parts.append(_delay(_click(0.12, hz, 0.12), j * 0.035 + _rng.randf_range(0.0, 0.02)))
	return _mix(parts)


func _radio() -> PackedFloat32Array:
	var n := _n(0.55)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		lp += 0.35 * (_rng.randf_range(-1.0, 1.0) - lp)
		hp += 0.08 * (lp - hp)
		var gate := 1.0 if int(float(i) / RATE * 22.0) % 3 != 0 else 0.3
		out[i] = (lp - hp) * gate * 0.35 * sin(PI * float(i) / n)
	return _mix([out, _delay(_click(0.09, 1000.0, 0.25), 0.44)])


func _rattle() -> PackedFloat32Array:
	var parts: Array = [_step(0.05, 400.0, 60.0, 0.7)]
	for j in 3:
		var hit := PackedFloat32Array()
		var n := _n(0.1)
		hit.resize(n)
		for i in n:
			var t := float(i) / RATE
			hit[i] = (sin(TAU * 310.0 * t) + 0.6 * sin(TAU * 437.0 * t)) * _env(i, n, 0.001, 4.0) * 0.3
		parts.append(_delay(hit, 0.06 + j * 0.11))
	return _mix(parts)


func _alarm() -> PackedFloat32Array:
	var n := _n(0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var sq := signf(sin(TAU * 440.0 * t)) * 0.5 + signf(sin(TAU * 466.2 * t)) * 0.5
		var trem := 0.65 + 0.35 * sin(TAU * 14.0 * t)
		out[i] = sq * trem * _env(i, n, 0.005, 1.2) * 0.28
	return _lowpass(out, 2500.0)


func _caught() -> PackedFloat32Array:
	var n := _n(1.1)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		phase += lerpf(110.0, 40.0, float(i) / n) / RATE
		out[i] = sin(TAU * phase) * _env(i, n, 0.002, 1.8) * 0.8
	return _mix([out, _step(0.15, 700.0, 55.0, 0.7), _delay(_tri(233.1, 0.6, 0.2), 0.05)])


func _victory() -> PackedFloat32Array:
	var notes := [523.3, 659.3, 784.0, 1046.5]
	var parts: Array = []
	for j in notes.size():
		parts.append(_delay(_bell(notes[j], 1.4 - j * 0.15, 0.32), j * 0.13))
	parts.append(_delay(_soft(523.3, 1.4, 0.22), 0.52))
	return _mix(parts)


func _creak() -> PackedFloat32Array:
	var n := _n(0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += (420.0 - 160.0 * t + 25.0 * sin(TAU * 31.0 * t)) / RATE
		out[i] = (fmod(phase, 1.0) * 2.0 - 1.0) * sin(PI * float(i) / n) * 0.12
	return _lowpass(out, 1800.0)


func _room_tone(length: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + _rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		var hum := 0.05 * sin(TAU * 50.0 * t) + 0.025 * sin(TAU * 100.0 * t) + 0.012 * sin(TAU * 150.0 * t)
		out[i] = brown * 0.55 + hum
	return _lowpass(out, 900.0)


func _clock(length: float) -> PackedFloat32Array:
	var tick := _mix([_click(0.025, 3100.0, 0.35), _click(0.04, 900.0, 0.2)])
	var tock := _mix([_click(0.025, 2500.0, 0.3), _click(0.04, 700.0, 0.2)])
	var out := PackedFloat32Array()
	out.resize(_n(length))
	_add(out, tick, 0)
	_add(out, tock, _n(length / 2.0))
	return out


func _tension(length: float) -> PackedFloat32Array:
	var n := _n(length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.6 + 0.4 * sin(TAU * t / length * 2.0)
		lp += 0.02 * (_rng.randf_range(-1.0, 1.0) - lp)
		out[i] = (0.35 * sin(TAU * 55.0 * t) + 0.22 * sin(TAU * 82.4 * t) + 0.08 * sin(TAU * 110.0 * t + sin(TAU * 0.25 * t))) * lfo + lp * 0.6
	return _lowpass(out, 600.0)


## Two bars at 120 bpm (4 s): driving eighth-note bass on A with a hi-hat tick. Exactly loopable.
func _chase(length: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(length))
	var eighth := length / 16.0
	var bass_notes := [55.0, 55.0, 55.0, 65.4, 55.0, 55.0, 73.4, 65.4]
	for j in 16:
		var hz: float = bass_notes[j % 8]
		var note := PackedFloat32Array()
		var n := _n(eighth * 0.9)
		note.resize(n)
		for i in n:
			var t := float(i) / RATE
			var saw := fmod(hz * t, 1.0) * 2.0 - 1.0
			note[i] = saw * _env(i, n, 0.004, 1.5) * 0.35
		_add(out, _lowpass(note, 700.0), _n(j * eighth))
		if j % 2 == 1:
			_add(out, _sweep_noise(0.05, 6000.0, 8000.0, 0.15), _n(j * eighth))
		if j % 4 == 0:
			_add(out, _step(0.08, 300.0, 50.0, 0.5), _n(j * eighth))
	return out


# --- Utilities ---------------------------------------------------------------------------------

func _delay(sound: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(seconds) + sound.size())
	_add(out, sound, _n(seconds))
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for p in parts:
		length = maxi(length, p.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for p in parts:
		_add(out, p, 0)
	return out


func _add(into: PackedFloat32Array, sound: PackedFloat32Array, at: int) -> void:
	for i in sound.size():
		if at + i < into.size():
			into[at + i] += sound[i]


func _lowpass(sound: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var k := 1.0 - exp(-TAU * cutoff / RATE)
	var lp := 0.0
	var out := sound.duplicate()
	for i in out.size():
		lp += k * (out[i] - lp)
		out[i] = lp
	return out


## Crossfades the last `fade` seconds into the start so the sound loops without a click.
func _loopable(sound: PackedFloat32Array, fade: float) -> PackedFloat32Array:
	var f := _n(fade)
	var n := sound.size() - f
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = sound[i]
	for i in f:
		var w := float(i) / f
		out[i] = sound[i] * w + sound[n + i] * (1.0 - w)
	return out


func _save(name: String, sound: PackedFloat32Array) -> void:
	var peak := 0.0
	for s in sound:
		peak = maxf(peak, absf(s))
	var scale := 0.9 / peak if peak > 0.9 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(sound.size() * 2)
	for i in sound.size():
		bytes.encode_s16(i * 2, int(clampf(sound[i] * scale, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(OUT + name + ".wav")
