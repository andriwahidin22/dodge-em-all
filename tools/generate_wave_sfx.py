#!/usr/bin/env python3
"""
Generator Efek Suara Sintetis Wave (CC0 / Public Domain)
Dodge 'em All - Tugas Pemrograman Game

Menghasilkan 4 efek suara 16-bit mono 44,1 kHz:
- wave_start.wav: Nada naik pemicu awal wave
- subwave_start.wav: Notifikasi singkat sub-wave
- wave_cleared.wav: Jingle melodi berhasil menyelesaikan wave
- game_won.wav: Fanfare kemenangan akhir permainan

Ditambah 2 efek suara menembak (fitur 7):
- shoot.wav: Bunyi "pew" pendek saat pemain menembak
- enemy_hit.wav: Bunyi "pop" saat peluru mengenai musuh

Skrip ini murni menggunakan modul bawaan Python (wave, math, struct)
tanpa dependensi eksternal, sehingga portabel di semua platform.
"""

import os
import math
import random
import struct
import wave

SAMPLE_RATE = 44100


def write_wav(path, samples):
	"""Menyimpan array sample float [-1.0, 1.0] ke file WAV 16-bit mono."""
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	with wave.open(path, "wb") as wf:
		wf.setnchannels(1)
		wf.setsampwidth(2)
		wf.setframerate(SAMPLE_RATE)
		frames = bytearray()
		for s in samples:
			clamped = max(-1.0, min(1.0, s))
			frames.extend(struct.pack("<h", int(clamped * 32767.0)))
		wf.writeframes(frames)
	print(f"Berhasil dibuat: {path} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f} dtk)")


def create_wave_start():
	"""Nada naik bertenaga tanda dimulainya wave (sweep 260Hz -> 520Hz)."""
	duration = 0.65
	total_samples = int(SAMPLE_RATE * duration)
	samples = []
	phase = 0.0
	for i in range(total_samples):
		t = i / SAMPLE_RATE
		# Linear pitch sweep
		freq = 260.0 + (520.0 - 260.0) * (t / duration)
		phase += 2.0 * math.pi * freq / SAMPLE_RATE
		# Sine + 2nd harmonic (warm square-like feel)
		val = 0.7 * math.sin(phase) + 0.3 * math.sin(phase * 2.0)
		# Envelope: quick attack (0.05s) + sustained decay
		if t < 0.05:
			env = t / 0.05
		else:
			env = math.exp(-2.5 * (t - 0.05))
		samples.append(val * env * 0.8)
	return samples


def create_subwave_start():
	"""Bip dua nada pendek (D5 587Hz -> A5 880Hz) tanda sub-wave baru."""
	duration = 0.35
	total_samples = int(SAMPLE_RATE * duration)
	samples = []
	phase1 = 0.0
	phase2 = 0.0
	for i in range(total_samples):
		t = i / SAMPLE_RATE
		if t < 0.15:
			phase1 += 2.0 * math.pi * 587.33 / SAMPLE_RATE
			val = math.sin(phase1)
			env = math.exp(-12.0 * t)
		else:
			t2 = t - 0.15
			phase2 += 2.0 * math.pi * 880.0 / SAMPLE_RATE
			val = math.sin(phase2) + 0.25 * math.sin(phase2 * 2.0)
			env = math.exp(-10.0 * t2)
		samples.append(val * env * 0.75)
	return samples


def create_wave_cleared():
	"""Arpeggio ceria nada C-E-G-C menandakan wave berhasil dibersihkan."""
	notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
	note_duration = 0.18
	samples = []
	for note_idx, freq in enumerate(notes):
		note_samples = int(SAMPLE_RATE * note_duration)
		phase = 0.0
		for i in range(note_samples):
			t = i / SAMPLE_RATE
			phase += 2.0 * math.pi * freq / SAMPLE_RATE
			val = 0.8 * math.sin(phase) + 0.2 * math.sin(phase * 3.0)
			env = math.exp(-8.0 * t)
			samples.append(val * env * 0.75)
	return samples


def create_game_won():
	"""Fanfare kemenangan yang ceria dan mantap."""
	melody = [
		(523.25, 0.20),   # C5
		(659.25, 0.20),   # E5
		(783.99, 0.20),   # G5
		(659.25, 0.15),   # E5
		(783.99, 0.25),   # G5
		(1046.50, 0.70),  # C6 panjang
	]
	samples = []
	for freq, dur in melody:
		count = int(SAMPLE_RATE * dur)
		phase = 0.0
		for i in range(count):
			t = i / SAMPLE_RATE
			# Sedikit vibrato di nada panjang
			vibrato = 1.0
			if dur > 0.4 and t > 0.1:
				vibrato = 1.0 + 0.012 * math.sin(2.0 * math.pi * 5.0 * t)
			phase += 2.0 * math.pi * (freq * vibrato) / SAMPLE_RATE
			val = 0.7 * math.sin(phase) + 0.25 * math.sin(phase * 2.0) + 0.1 * math.sin(phase * 3.0)
			if t < 0.02:
				env = t / 0.02
			else:
				decay = 2.0 if dur > 0.4 else 6.0
				env = math.exp(-decay * (t - 0.02))
			samples.append(val * env * 0.8)
	return samples


def create_shoot():
	"""Bunyi "pew" laser: nada turun cepat 1400Hz -> 350Hz, sekitar 0,12 detik.
	Sengaja pendek dan tidak terlalu keras karena bisa diputar berkali-kali per detik."""
	duration = 0.12
	total_samples = int(SAMPLE_RATE * duration)
	samples = []
	phase = 0.0
	for i in range(total_samples):
		t = i / SAMPLE_RATE
		# Sweep eksponensial (terdengar lebih "laser" daripada sweep linear)
		freq = 1400.0 * math.pow(350.0 / 1400.0, t / duration)
		phase += 2.0 * math.pi * freq / SAMPLE_RATE
		# Sine + harmonik ke-3 lemah supaya sedikit "berdesis" seperti gelombang kotak
		val = 0.8 * math.sin(phase) + 0.2 * math.sin(phase * 3.0)
		# Envelope: attack 3 ms supaya tidak "klik", lalu decay cepat
		if t < 0.003:
			env = t / 0.003
		else:
			env = math.exp(-28.0 * (t - 0.003))
		samples.append(val * env * 0.7)
	return samples


def create_enemy_hit():
	"""Bunyi "pop" musuh tertembak: semburan noise singkat + dentum nada rendah 260Hz -> 90Hz."""
	rng = random.Random(7)  # seed tetap supaya hasil file selalu sama setiap dibuat ulang
	duration = 0.16
	total_samples = int(SAMPLE_RATE * duration)
	samples = []
	phase = 0.0
	noise = 0.0
	for i in range(total_samples):
		t = i / SAMPLE_RATE
		freq = 260.0 * math.pow(90.0 / 260.0, t / duration)
		phase += 2.0 * math.pi * freq / SAMPLE_RATE
		thump = math.sin(phase) * math.exp(-18.0 * t)
		# Noise disaring low-pass sederhana supaya tidak terlalu tajam di telinga
		noise += 0.35 * (rng.uniform(-1.0, 1.0) - noise)
		burst = noise * math.exp(-45.0 * t)
		attack = min(1.0, t / 0.002)
		samples.append((0.75 * thump + 0.6 * burst) * attack * 0.85)
	return samples


def main():
	base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
	out_dir = os.path.join(base_dir, "art", "audio")
	print(f"Membuat aset efek suara wave sintetis di: {out_dir}")

	write_wav(os.path.join(out_dir, "wave_start.wav"), create_wave_start())
	write_wav(os.path.join(out_dir, "subwave_start.wav"), create_subwave_start())
	write_wav(os.path.join(out_dir, "wave_cleared.wav"), create_wave_cleared())
	write_wav(os.path.join(out_dir, "game_won.wav"), create_game_won())
	write_wav(os.path.join(out_dir, "shoot.wav"), create_shoot())
	write_wav(os.path.join(out_dir, "enemy_hit.wav"), create_enemy_hit())
	print("Semua file audio WAV berhasil dibuat!")


if __name__ == "__main__":
	main()
