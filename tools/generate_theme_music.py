#!/usr/bin/env python3
"""
generate_theme_music.py - Generator Musik Game Prosedural per Tema (CC0 / Public Domain)
Dodge 'em All - Tugas Pemrograman Game

Menghasilkan 3 musik permainan (game sound) retro arcade bertempo cepat dan catchy:
  1. art/audio/music/planet_game_sound.wav (Planet: synth alien berdenyut, arpeggio kosmik)
  2. art/audio/music/ocean_game_sound.wav  (Laut: ritme bawah air, melodi marimba/lonceng cair)
  3. art/audio/music/city_game_sound.wav   (Kota: retro synthwave arcade, bass galloping, lead energik)

Format: Mono, 22.050 Hz, 16-bit PCM WAV.
Seamless looping sempurna dicapai dengan struktur birama musikal bulat dan crossfade mikro.
Juga membuat file .import otomatis (compress/mode=0, loop_mode=1).
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art", "audio", "music")


def note_to_freq(midi_note: int) -> float:
    """Konversi nomor not MIDI (69 = A4 440Hz) ke frekuensi Hz."""
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))


def write_wav(filename: str, samples: list):
    """Menyimpan sampel float [-1.0, 1.0] ke file WAV 16-bit PCM mono."""
    filepath = os.path.join(OUTPUT_DIR, filename)
    peak = max(abs(s) for s in samples) if samples else 1.0
    norm = (0.82 / peak) if peak > 0.001 else 1.0

    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        buf = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * norm * 32767.0)))
            buf.extend(struct.pack("<h", val))
        wf.writeframes(buf)

    size_kb = os.path.getsize(filepath) / 1024.0
    dur = len(samples) / SAMPLE_RATE
    print(f"Generated music: {filename} ({len(samples)} frames, {dur:.2f}s, {size_kb:.1f} KB)")


def write_import_file(filename: str, uid_suffix: str):
    """Menulis file .import Godot 4 agar file WAV di-import sebagai PCM 16-bit looping."""
    filepath = os.path.join(OUTPUT_DIR, filename + ".import")
    sample_name = f"{filename.replace('.wav', '')}.wav-theme000{uid_suffix}.sample"
    content = f"""[remap]

importer="wav"
type="AudioStreamWAV"
uid="uid://theme{uid_suffix}"
path="res://.godot/imported/{sample_name}"

[deps]

source_file="res://art/audio/music/{filename}"
dest_files=["res://.godot/imported/{sample_name}"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=1
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""
    with open(filepath, "w") as f:
        f.write(content)


def apply_loop_crossfade(samples: list, crossfade_samples: int = 2205) -> list:
    """Menerapkan crossfade pendek di awal-akhir sampel agar zero click pada titik loop."""
    n = len(samples)
    cf = min(crossfade_samples, n // 4)
    out = list(samples)
    for i in range(cf):
        t = i / float(cf)
        g_in = math.sin(t * (math.pi / 2.0))
        g_out = math.cos(t * (math.pi / 2.0))
        out[i] = samples[i] * g_in + samples[n - cf + i] * g_out
    return out[:n - cf]


# ---------------- Komposisi Musik Game Tema Planet ----------------

def generate_planet_game_sound() -> list:
    """
    Musik tema Planet: Alien Synth Survival (BPM: 132, D minor).
    Bassline synth 16th-note menghentak + lead kosmik arpeggio + drum arcade.
    """
    bpm = 132.0
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4.0
    total_bars = 8
    total_duration = bar_dur * total_bars
    total_samples = int(SAMPLE_RATE * (total_duration + 0.5))
    mix = [0.0] * total_samples

    # 1. Drum beat (Kick pada ketukan 1, 3; Snare pada 2, 4; Hi-hat setiap 16th)
    for bar in range(total_bars):
        bar_t0 = bar * bar_dur
        for beat in range(4):
            t_beat = bar_t0 + beat * beat_dur
            idx_beat = int(t_beat * SAMPLE_RATE)

            # Kick pada beat 0 dan 2
            if beat in (0, 2):
                for k in range(int(0.18 * SAMPLE_RATE)):
                    if idx_beat + k < total_samples:
                        kt = k / SAMPLE_RATE
                        freq = 140.0 * math.exp(-kt * 25.0)
                        env = math.exp(-kt * 18.0)
                        mix[idx_beat + k] += math.sin(2.0 * math.pi * freq * kt) * 0.45 * env

            # Snare pada beat 1 dan 3
            if beat in (1, 3):
                random.seed(bar * 10 + beat)
                for s in range(int(0.16 * SAMPLE_RATE)):
                    if idx_beat + s < total_samples:
                        st = s / SAMPLE_RATE
                        noise = random.uniform(-1.0, 1.0) * math.exp(-st * 22.0)
                        body = math.sin(2.0 * math.pi * 180.0 * math.exp(-st * 20.0) * st) * math.exp(-st * 24.0)
                        mix[idx_beat + s] += (noise * 0.28 + body * 0.25)

            # Hi-hat 16th notes (4 per beat)
            for sub in range(4):
                t_sub = t_beat + sub * (beat_dur / 4.0)
                idx_sub = int(t_sub * SAMPLE_RATE)
                random.seed(int(t_sub * 1000))
                for h in range(int(0.04 * SAMPLE_RATE)):
                    if idx_sub + h < total_samples:
                        ht = h / SAMPLE_RATE
                        noise = random.uniform(-1.0, 1.0) * math.exp(-ht * 80.0)
                        mix[idx_sub + h] += noise * (0.12 if sub % 2 == 1 else 0.08)

    # 2. Bassline synth 16th-note (D minor: D2 -> F2 -> G2 -> A2 -> D2 -> C2 -> Bb1 -> A1)
    bass_roots = [38, 38, 41, 43, 38, 38, 36, 45]  # D, D, F, G, D, D, C, A
    for bar in range(total_bars):
        root = bass_roots[bar]
        bar_t0 = bar * bar_dur
        for step in range(16):
            t_step = bar_t0 + step * (bar_dur / 16.0)
            idx_step = int(t_step * SAMPLE_RATE)
            pitch = root if (step % 4 != 3) else root + 12
            freq = note_to_freq(pitch)
            dur = (bar_dur / 16.0) * 0.85
            step_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(step_samples):
                if idx_step + i < total_samples:
                    it = i / SAMPLE_RATE
                    phase += 2.0 * math.pi * freq / SAMPLE_RATE
                    # Square wave sintetis hangat
                    val = 0.7 * math.sin(phase) + 0.3 * math.sin(phase * 3.0)
                    env = math.exp(-it * 12.0)
                    mix[idx_step + i] += val * env * 0.30

    # 3. Arpeggio Kosmik Lead (D minor arpeggios naik-turun)
    arp_notes = [62, 65, 69, 74, 69, 65, 62, 57]  # D4, F4, A4, D5, A4, F4, D4, A3
    for bar in range(total_bars):
        bar_t0 = bar * bar_dur
        offset_note = 0 if bar < 4 else (3 if bar in (4, 5) else -2)
        for step in range(16):
            t_step = bar_t0 + step * (bar_dur / 16.0)
            idx_step = int(t_step * SAMPLE_RATE)
            note = arp_notes[step % len(arp_notes)] + offset_note
            freq = note_to_freq(note)
            dur = (bar_dur / 16.0) * 0.9
            step_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(step_samples):
                if idx_step + i < total_samples:
                    it = i / SAMPLE_RATE
                    vibrato = math.sin(2.0 * math.pi * 5.0 * it) * 4.0 if it > 0.1 else 0.0
                    phase += 2.0 * math.pi * (freq + vibrato) / SAMPLE_RATE
                    # Blend sine + saw halus
                    saw = 2.0 * (math.fmod(phase / (2.0 * math.pi), 1.0)) - 1.0
                    val = 0.6 * math.sin(phase) + 0.4 * saw
                    env = math.exp(-it * 8.0)
                    mix[idx_step + i] += val * env * 0.22

    target_samples = int(SAMPLE_RATE * total_duration)
    return apply_loop_crossfade(mix[:target_samples])


# ---------------- Komposisi Musik Game Tema Laut ----------------

def generate_ocean_game_sound() -> list:
    """
    Musik tema Laut: Aquatic Groove (BPM: 120, A minor / E minor).
    Dentang marimba/bel kristal cair + bass sub mengalir + ketukan air berirama.
    """
    bpm = 120.0
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4.0
    total_bars = 8
    total_duration = bar_dur * total_bars
    total_samples = int(SAMPLE_RATE * (total_duration + 0.5))
    mix = [0.0] * total_samples

    # 1. Ketukan berdenyut air (Deep sub kick + watery rim click)
    for bar in range(total_bars):
        bar_t0 = bar * bar_dur
        for beat in range(4):
            t_beat = bar_t0 + beat * beat_dur
            idx_beat = int(t_beat * SAMPLE_RATE)

            # Deep aquatic kick
            if beat in (0, 2):
                for k in range(int(0.22 * SAMPLE_RATE)):
                    if idx_beat + k < total_samples:
                        kt = k / SAMPLE_RATE
                        freq = 110.0 * math.exp(-kt * 18.0)
                        env = math.exp(-kt * 12.0)
                        mix[idx_beat + k] += math.sin(2.0 * math.pi * freq * kt) * 0.40 * env

            # Rim tap cair (woodblock / bubble tap) pada beat 1 dan 3
            if beat in (1, 3):
                for r in range(int(0.08 * SAMPLE_RATE)):
                    if idx_beat + r < total_samples:
                        rt = r / SAMPLE_RATE
                        freq = 820.0 + 200.0 * (rt / 0.08)
                        env = math.sin(math.pi * (r / float(0.08 * SAMPLE_RATE)))
                        mix[idx_beat + r] += math.sin(2.0 * math.pi * freq * rt) * 0.20 * env

            # Bubbling offbeat syncopation
            for sub in [1, 3]:
                t_sub = t_beat + sub * (beat_dur / 4.0)
                idx_sub = int(t_sub * SAMPLE_RATE)
                for b in range(int(0.05 * SAMPLE_RATE)):
                    if idx_sub + b < total_samples:
                        bt = b / SAMPLE_RATE
                        freq = 600.0 + 150.0 * math.sin(bt * 40.0)
                        env = math.exp(-bt * 50.0)
                        mix[idx_sub + b] += math.sin(2.0 * math.pi * freq * bt) * 0.08 * env

    # 2. Bass mengalir lembut (A minor: A1, C2, E2, G1)
    bass_prog = [33, 33, 36, 40, 33, 33, 31, 35]  # A1, A1, C2, E2, A1, A1, G1, B1
    for bar in range(total_bars):
        root = bass_prog[bar]
        bar_t0 = bar * bar_dur
        for step in range(8):
            t_step = bar_t0 + step * (bar_dur / 8.0)
            idx_step = int(t_step * SAMPLE_RATE)
            p = root if step % 2 == 0 else root + 7
            freq = note_to_freq(p)
            dur = (bar_dur / 8.0) * 0.8
            step_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(step_samples):
                if idx_step + i < total_samples:
                    it = i / SAMPLE_RATE
                    phase += 2.0 * math.pi * freq / SAMPLE_RATE
                    val = math.sin(phase) + 0.25 * math.sin(phase * 2.0)
                    env = math.exp(-it * 7.0)
                    mix[idx_step + i] += val * env * 0.32

    # 3. Melodi Marimba Kristal Lautan (pola arpeggio bernuansa tropis bawah air)
    lead_seq = [
        [69, 72, 76, 79],  # A4, C5, E5, G5
        [69, 72, 76, 81],  # A4, C5, E5, A5
        [67, 71, 74, 79],  # G4, B4, D5, G5
        [65, 69, 72, 76],  # F4, A4, C5, E5
    ]
    for bar in range(total_bars):
        chord = lead_seq[bar % len(lead_seq)]
        bar_t0 = bar * bar_dur
        for step in range(8):
            t_step = bar_t0 + step * (bar_dur / 8.0)
            idx_step = int(t_step * SAMPLE_RATE)
            note = chord[step % len(chord)] + (12 if step >= 4 else 0)
            freq = note_to_freq(note)
            dur = 0.22
            step_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(step_samples):
                if idx_step + i < total_samples:
                    it = i / SAMPLE_RATE
                    phase += 2.0 * math.pi * freq / SAMPLE_RATE
                    # Marimba / kalimba: sin(f) + sin(3f) cepat memudar
                    val = 0.75 * math.sin(phase) + 0.25 * math.sin(phase * 3.0)
                    env = math.exp(-it * 10.0)
                    mix[idx_step + i] += val * env * 0.24

    target_samples = int(SAMPLE_RATE * total_duration)
    return apply_loop_crossfade(mix[:target_samples])


# ---------------- Komposisi Musik Game Tema Kota ----------------

def generate_city_game_sound() -> list:
    """
    Musik tema Kota: Cyber Synthwave Beat (BPM: 128, F# minor / A major).
    Galloping octave bassline, electro drum punch, dan lead synthesizer 80-an yang energik.
    """
    bpm = 128.0
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4.0
    total_bars = 8
    total_duration = bar_dur * total_bars
    total_samples = int(SAMPLE_RATE * (total_duration + 0.5))
    mix = [0.0] * total_samples

    # 1. Drum Synthwave (Punchy 80s kick + gated snare + 16th hats)
    for bar in range(total_bars):
        bar_t0 = bar * bar_dur
        for beat in range(4):
            t_beat = bar_t0 + beat * beat_dur
            idx_beat = int(t_beat * SAMPLE_RATE)

            # Punchy Kick pada setiap beat (Four on the floor!)
            for k in range(int(0.16 * SAMPLE_RATE)):
                if idx_beat + k < total_samples:
                    kt = k / SAMPLE_RATE
                    freq = 160.0 * math.exp(-kt * 28.0)
                    env = math.exp(-kt * 16.0)
                    mix[idx_beat + k] += math.sin(2.0 * math.pi * freq * kt) * 0.44 * env

            # Gated Snare pada beat 1 dan 3
            if beat in (1, 3):
                random.seed(bar * 20 + beat)
                for s in range(int(0.20 * SAMPLE_RATE)):
                    if idx_beat + s < total_samples:
                        st = s / SAMPLE_RATE
                        noise = random.uniform(-1.0, 1.0) * (0.8 if st < 0.12 else math.exp(-(st - 0.12) * 40.0))
                        body = math.sin(2.0 * math.pi * 220.0 * math.exp(-st * 25.0) * st) * math.exp(-st * 20.0)
                        mix[idx_beat + s] += (noise * 0.32 + body * 0.28)

            # Offbeat open-hat pada & (setengah beat)
            t_off = t_beat + (beat_dur / 2.0)
            idx_off = int(t_off * SAMPLE_RATE)
            random.seed(int(t_off * 1000))
            for h in range(int(0.08 * SAMPLE_RATE)):
                if idx_off + h < total_samples:
                    ht = h / SAMPLE_RATE
                    noise = random.uniform(-1.0, 1.0) * math.exp(-ht * 35.0)
                    mix[idx_off + h] += noise * 0.16

    # 2. Galloping Octave Bass (F# minor: F#2-F#3 galloping 16th notes)
    bass_chords = [42, 42, 45, 47, 42, 42, 40, 44]  # F#, F#, A, B, F#, F#, E, G#
    for bar in range(total_bars):
        root = bass_chords[bar]
        bar_t0 = bar * bar_dur
        for step in range(16):
            t_step = bar_t0 + step * (bar_dur / 16.0)
            idx_step = int(t_step * SAMPLE_RATE)
            # Pola galloping: Low - High - High - High
            octave = 0 if (step % 4 == 0) else 12
            freq = note_to_freq(root + octave)
            dur = (bar_dur / 16.0) * 0.75
            step_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(step_samples):
                if idx_step + i < total_samples:
                    it = i / SAMPLE_RATE
                    phase += 2.0 * math.pi * freq / SAMPLE_RATE
                    # Saw synth dengan envelope filter
                    saw = 2.0 * math.fmod(phase / (2.0 * math.pi), 1.0) - 1.0
                    val = 0.5 * saw + 0.5 * math.sin(phase)
                    env = math.exp(-it * 14.0)
                    mix[idx_step + i] += val * env * 0.28

    # 3. Synthwave Arcade Lead (Melodi retro 80-an yang seru dan bersemangat)
    # Melodi 8 bar
    melody = [
        # Bar 1: F#4 -> A4 -> C#5 -> B4
        [(0.0, 66), (0.5, 69), (1.0, 73), (1.5, 71)],
        # Bar 2: A4 -> F#4 -> E4 -> F#4
        [(0.0, 69), (0.5, 66), (1.0, 64), (1.5, 66)],
        # Bar 3: A4 -> B4 -> C#5 -> E5
        [(0.0, 69), (0.5, 71), (1.0, 73), (1.5, 76)],
        # Bar 4: C#5 tahan
        [(0.0, 73), (1.0, 71)],
        # Bar 5: F#4 -> A4 -> C#5 -> E5
        [(0.0, 66), (0.5, 69), (1.0, 73), (1.5, 76)],
        # Bar 6: F#5 -> E5 -> C#5 -> B4
        [(0.0, 78), (0.5, 76), (1.0, 73), (1.5, 71)],
        # Bar 7: A4 -> B4 -> C#5 -> B4
        [(0.0, 69), (0.5, 71), (1.0, 73), (1.5, 71)],
        # Bar 8: A4 -> F#4
        [(0.0, 69), (1.0, 66)],
    ]

    for bar in range(total_bars):
        bar_t0 = bar * bar_dur
        notes = melody[bar]
        for rel_beat, midi_n in notes:
            t_note = bar_t0 + rel_beat * beat_dur
            idx_note = int(t_note * SAMPLE_RATE)
            freq = note_to_freq(midi_n)
            dur = beat_dur * 0.85
            note_samples = int(dur * SAMPLE_RATE)

            phase = 0.0
            for i in range(note_samples):
                if idx_note + i < total_samples:
                    it = i / SAMPLE_RATE
                    vib = math.sin(2.0 * math.pi * 5.5 * it) * 3.5 if it > 0.12 else 0.0
                    phase += 2.0 * math.pi * (freq + vib) / SAMPLE_RATE
                    # Blend square + sine
                    sq = 1.0 if math.sin(phase) >= 0 else -1.0
                    val = 0.5 * sq + 0.5 * math.sin(phase)
                    env = math.exp(-it * 3.5) if it > 0.05 else (it / 0.05)
                    mix[idx_note + i] += val * env * 0.22

    target_samples = int(SAMPLE_RATE * total_duration)
    return apply_loop_crossfade(mix[:target_samples])


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Menghasilkan aset musik game per tema di: {OUTPUT_DIR}")

    write_wav("planet_game_sound.wav", generate_planet_game_sound())
    write_import_file("planet_game_sound.wav", "gameplanet001")

    write_wav("ocean_game_sound.wav", generate_ocean_game_sound())
    write_import_file("ocean_game_sound.wav", "gameocean0001")

    write_wav("city_game_sound.wav", generate_city_game_sound())
    write_import_file("city_game_sound.wav", "gamecity00001")

    print("Semua file musik game per tema berhasil dibuat!")


if __name__ == "__main__":
    main()
