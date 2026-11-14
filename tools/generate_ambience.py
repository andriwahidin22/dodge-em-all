#!/usr/bin/env python3
"""
generate_ambience.py - Generator Audio Ambience Loop Sintetis untuk Dodge 'em All.
Menghasilkan 4 file audio ambience loop mulus (seamless):
  1. art/audio/ambience/space.wav  (Angkasa: sub drone, pad evolusi, denting lembut)
  2. art/audio/ambience/planet.wav (Planet: angin berdesir, dengung alien rendah)
  3. art/audio/ambience/ocean.wav  (Lautan: gemuruh air teredam, gelembung, nada paus)
  4. art/audio/ambience/city.wav   (Kota: dengung lalu lintas jauh, hum malam, desis angin)

Format: Mono, 22.050 Hz, 16-bit PCM WAV.
Panjang: 24 detik per file (loop panjang, terasa lebih alami).
Seamless looping dicapai via crossfade window di batas akhir-ke-awal.

Pastikan .import juga digenerate ulang dengan compress/mode=0 (PCM 16-bit)
agar Godot bisa melakukan seamless loop dengan benar.
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
DURATION = 24.0          # durasi target (detik) - lebih panjang = lebih natural
CROSSFADE_SEC = 3.0      # panjang overlap crossfade untuk loop mulus
TOTAL_DURATION = DURATION + CROSSFADE_SEC
TOTAL_SAMPLES = int(SAMPLE_RATE * TOTAL_DURATION)
TARGET_SAMPLES = int(SAMPLE_RATE * DURATION)
CROSSFADE_SAMPLES = int(SAMPLE_RATE * CROSSFADE_SEC)

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art", "audio", "ambience")


def make_seamless_loop(samples: list) -> list:
    """Menerapkan crossfade antara ekor dan kepala sinyal untuk loop sempurna."""
    result = list(samples[:TARGET_SAMPLES])
    for i in range(CROSSFADE_SAMPLES):
        t = i / float(CROSSFADE_SAMPLES)
        # Cosine crossfade untuk daya konstan (equal-power)
        gain_head = math.sin(t * (math.pi / 2.0))
        gain_tail = math.cos(t * (math.pi / 2.0))
        head_sample = samples[i]
        tail_sample = samples[TARGET_SAMPLES + i]
        result[i] = head_sample * gain_head + tail_sample * gain_tail
    return result


def low_pass_filter(samples: list, alpha: float) -> list:
    """Filter low-pass sederhana satu-pole."""
    out = [0.0] * len(samples)
    prev = 0.0
    for i, s in enumerate(samples):
        prev = prev + alpha * (s - prev)
        out[i] = prev
    return out


def write_wav(filename: str, samples: list):
    """Menulis array sampel (-1.0 s/d 1.0) ke file WAV 16-bit PCM mono."""
    filepath = os.path.join(OUTPUT_DIR, filename)
    # Normalisasi puncak ke -1.5 dB (±0.84) agar tidak clipping
    peak = max(abs(s) for s in samples) if samples else 1.0
    norm_factor = (0.84 / peak) if peak > 0.001 else 1.0

    with wave.open(filepath, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        packed_data = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * norm_factor * 32767.0)))
            packed_data.extend(struct.pack("<h", val))
        wf.writeframes(packed_data)
    size_kb = os.path.getsize(filepath) / 1024.0
    n_frames = len(samples)
    print(f"Generated: {filename} ({n_frames} frames, {n_frames/SAMPLE_RATE:.1f}s, {size_kb:.1f} KB)")


def write_import_file(wav_filename: str, uid_suffix: str):
    """Menulis file .import yang sesuai untuk Godot 4 agar loop bekerja (compress/mode=0 = PCM)."""
    wav_path = os.path.join(OUTPUT_DIR, wav_filename)
    import_path = wav_path + ".import"
    # Hitung hash sederhana dari nama file untuk membuat nama file .sample unik
    import hashlib
    name_hash = hashlib.md5(wav_filename.encode()).hexdigest()
    sample_name = f"{wav_filename.replace('.wav', '')}.wav-{name_hash}.sample"
    content = f"""[remap]

importer="wav"
type="AudioStreamWAV"
uid="uid://{uid_suffix}"
path="res://.godot/imported/{sample_name}"

[deps]

source_file="res://art/audio/ambience/{wav_filename}"
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
    with open(import_path, "w") as f:
        f.write(content)
    print(f"Generated import: {wav_filename}.import (compress/mode=0, loop_mode=1)")


# ---------------- Generator Sintetis Tiap Tema ----------------

def generate_space() -> list:
    """Angkasa: sub-drone 55 Hz & 110 Hz, pad harmonik lembut, denting samar, noise kosmik."""
    random.seed(42)
    raw = [0.0] * TOTAL_SAMPLES

    for i in range(TOTAL_SAMPLES):
        t = i / float(SAMPLE_RATE)

        # Sub-drone fundamental - tebal dan rendah
        d1 = math.sin(2.0 * math.pi * 55.0 * t) * 0.30
        d2 = math.sin(2.0 * math.pi * 110.0 * t + 0.5) * 0.18
        d3 = math.sin(2.0 * math.pi * 82.5 * t + 1.1) * 0.10

        # Evolving ambient pad dengan modulasi lambat
        lfo1 = 0.5 + 0.5 * math.sin(t * 0.23)
        lfo2 = 0.5 + 0.5 * math.cos(t * 0.17 + 1.0)
        p1 = math.sin(2.0 * math.pi * 220.0 * t) * (0.07 * lfo1)
        p2 = math.sin(2.0 * math.pi * 330.0 * t + 1.2) * (0.05 * lfo2)
        p3 = math.sin(2.0 * math.pi * 440.0 * t + 2.4) * (0.03 * (0.5 + 0.5 * math.sin(t * 0.11)))

        # Shimmer pad - harmonis tinggi yang berevolusi
        shimmer = math.sin(2.0 * math.pi * 659.3 * t + 0.7) * (0.015 * lfo1 * lfo2)

        raw[i] = d1 + d2 + d3 + p1 + p2 + p3 + shimmer

    # Denting resonansi lembut ruang angkasa (seperti sinyal radio)
    chime_times = [2.5, 7.0, 12.0, 17.0, 21.5]
    chime_freqs = [880.0, 1174.6, 740.0, 987.7, 1318.5]
    chime_vols  = [0.045, 0.030, 0.040, 0.025, 0.035]
    for ct, cf, cv in zip(chime_times, chime_freqs, chime_vols):
        start_idx = int(ct * SAMPLE_RATE)
        dur_s = int(3.0 * SAMPLE_RATE)
        for j in range(dur_s):
            idx = start_idx + j
            if idx >= TOTAL_SAMPLES:
                break
            env = math.exp(-j / (SAMPLE_RATE * 0.8))
            raw[idx] += math.sin(2.0 * math.pi * cf * (j / float(SAMPLE_RATE))) * cv * env

    # Noise kosmik sangat halus (di-filter rendah)
    noise_buf = [random.gauss(0, 0.012) for _ in range(TOTAL_SAMPLES)]
    noise_filtered = low_pass_filter(noise_buf, 0.008)
    for i in range(TOTAL_SAMPLES):
        raw[i] += noise_filtered[i]

    return make_seamless_loop(raw)


def generate_planet() -> list:
    """Planet: desisan angin alien bergelombang, nada rendah berdenyut, gemuruh badai."""
    random.seed(101)
    raw = [0.0] * TOTAL_SAMPLES

    # Pre-generate white noise
    white_noise = [random.uniform(-1.0, 1.0) for _ in range(TOTAL_SAMPLES)]

    # Low-pass filter untuk suara angin planet (cutoff ~300 Hz)
    wind_filtered = low_pass_filter(white_noise, 0.055)

    # Band-pass kasar: satu low-pass lagi (double filter) untuk terdengar lebih teredam
    wind_filtered2 = low_pass_filter(wind_filtered, 0.08)

    for i in range(TOTAL_SAMPLES):
        t = i / float(SAMPLE_RATE)

        # Modulasi kekuatan angin (hembusan acak-periodik)
        wind_swell = (0.4 + 0.3 * math.sin(t * 0.6)
                      + 0.2 * math.cos(t * 0.35 + 0.8)
                      + 0.1 * math.sin(t * 1.1 + 1.5))
        wind = wind_filtered2[i] * 0.9 * max(0.0, wind_swell)

        # Nada rendah alien berdenyut dengan vibrato
        vibrato = math.sin(2.0 * math.pi * 0.22 * t) * 2.5
        alien_drone = math.sin(2.0 * math.pi * (68.0 + vibrato) * t) * 0.20

        # Sub bass tanah berguncang
        sub_gust = math.sin(2.0 * math.pi * 44.0 * t) * 0.14 * (0.5 + 0.5 * math.sin(t * 0.4))

        # Nada alien kedua - lebih tinggi, bergetar
        alien2 = math.sin(2.0 * math.pi * 136.0 * t) * (0.06 * (0.5 + 0.5 * math.cos(t * 0.28)))

        raw[i] = wind + alien_drone + sub_gust + alien2

    # Suara petir/kilat jauh di horizon (burst singkat)
    thunder_times = [5.5, 14.0, 20.5]
    for tt in thunder_times:
        start_idx = int(tt * SAMPLE_RATE)
        dur = int(1.8 * SAMPLE_RATE)
        for j in range(dur):
            idx = start_idx + j
            if idx >= TOTAL_SAMPLES:
                break
            tt2 = j / float(SAMPLE_RATE)
            env = math.exp(-tt2 * 2.5) * (0.5 + 0.5 * math.sin(tt2 * 180.0))
            raw[idx] += (white_noise[idx] * 0.18 * env)

    return make_seamless_loop(raw)


def generate_ocean() -> list:
    """Lautan: gemuruh bawah air dalam, gelembung naik, nyanyian paus, arus laut."""
    random.seed(202)
    raw = [0.0] * TOTAL_SAMPLES

    # Pre-generate white noise
    white_noise = [random.uniform(-1.0, 1.0) for _ in range(TOTAL_SAMPLES)]

    # Gemuruh air bawah laut (sangat low-pass, < 80 Hz)
    rumble_filtered = low_pass_filter(white_noise, 0.012)

    # Mid-range air bergerak (arus, turbulensi)
    current_filtered = low_pass_filter(white_noise, 0.035)

    for i in range(TOTAL_SAMPLES):
        t = i / float(SAMPLE_RATE)

        # Arus laut bergelombang
        surge_lfo = 0.5 + 0.4 * math.sin(t * 0.38) + 0.1 * math.cos(t * 0.65)
        surge = max(0.0, surge_lfo)

        # Gemuruh bawah laut
        sub_water = math.sin(2.0 * math.pi * 42.0 * t) * 0.22 * surge
        rumble = rumble_filtered[i] * 1.3

        # Arus tengah - seperti aliran air melewati batu karang
        current = current_filtered[i] * 0.4 * (0.6 + 0.4 * math.sin(t * 0.52))

        # Nyanyian paus jauh (3 momen di durasi berbeda)
        whale1_env = max(0.0, math.sin(math.pi * t / 8.0)) ** 2 if t < 8.0 else 0.0
        whale_freq1 = 128.0 + 20.0 * math.sin(t * 0.9)
        whale1 = math.sin(2.0 * math.pi * whale_freq1 * t) * 0.10 * whale1_env

        whale2_env = max(0.0, math.sin(math.pi * (t - 11.0) / 7.0)) ** 2 if 11.0 < t < 18.0 else 0.0
        whale_freq2 = 160.0 + 25.0 * math.sin(t * 1.1 + 2.0)
        whale2 = math.sin(2.0 * math.pi * whale_freq2 * t) * 0.09 * whale2_env

        raw[i] = rumble + sub_water + current + whale1 + whale2

    # Gelembung naik (lebih banyak dan variasi ukuran)
    bubble_data = [
        (1.5,  0.08, 420, 300), (3.2,  0.12, 580, 420), (5.8,  0.09, 350, 200),
        (7.5,  0.14, 650, 500), (9.0,  0.07, 480, 350), (11.4, 0.11, 520, 380),
        (13.0, 0.08, 400, 280), (15.5, 0.13, 600, 450), (17.8, 0.09, 460, 320),
        (20.2, 0.10, 540, 400), (22.5, 0.07, 380, 260),
    ]
    for bt, b_dur, b_f1, b_range in bubble_data:
        start_idx = int(bt * SAMPLE_RATE)
        b_len = int(b_dur * SAMPLE_RATE)
        for j in range(b_len):
            idx = start_idx + j
            if idx >= TOTAL_SAMPLES:
                break
            b_t = j / float(SAMPLE_RATE)
            # Frekuensi naik saat gelembung bergerak ke atas
            freq = b_f1 + b_range * (b_t / b_dur)
            env = math.sin(math.pi * (j / float(b_len)))
            raw[idx] += math.sin(2.0 * math.pi * freq * b_t) * 0.055 * env

    return make_seamless_loop(raw)


def generate_city() -> list:
    """Kota: dengung lalu lintas malam, hum 50 Hz listrik, sirene jauh, angin gedung."""
    random.seed(303)
    raw = [0.0] * TOTAL_SAMPLES

    # Pre-generate white noise
    white_noise = [random.uniform(-1.0, 1.0) for _ in range(TOTAL_SAMPLES)]

    # Lalu lintas jauh (low-pass kota)
    traffic_filtered = low_pass_filter(white_noise, 0.022)

    # Suara mid-range (angin di antara gedung)
    wind_filtered = low_pass_filter(white_noise, 0.065)

    for i in range(TOTAL_SAMPLES):
        t = i / float(SAMPLE_RATE)

        # Deru lalu lintas jauh bergelombang
        traffic_swell = 0.6 + 0.3 * math.sin(t * 0.25) + 0.1 * math.cos(t * 0.45)
        traffic = traffic_filtered[i] * 0.8 * max(0.3, traffic_swell)

        # Hum kelistrikan kota malam (50 Hz Indonesia + harmonik 100 Hz)
        hum = (math.sin(2.0 * math.pi * 50.0 * t) * 0.15
               + math.sin(2.0 * math.pi * 100.0 * t + 0.5) * 0.07
               + math.sin(2.0 * math.pi * 150.0 * t + 1.0) * 0.03)

        # Angin desis di sela gedung tinggi
        wind_lfo = 0.5 + 0.5 * math.sin(t * 0.38 + 0.7)
        wind = wind_filtered[i] * 0.15 * wind_lfo

        # Sirene polisi / ambulans sangat jauh dan samar (3 kemunculan)
        siren1_env = max(0.0, math.sin(math.pi * (t - 3.0) / 5.0)) ** 3 if 3.0 < t < 8.0 else 0.0
        siren1_freq = 460.0 + 70.0 * math.sin(2.0 * math.pi * 0.4 * t)
        siren1 = math.sin(2.0 * math.pi * siren1_freq * t) * 0.030 * siren1_env

        siren2_env = max(0.0, math.sin(math.pi * (t - 15.0) / 6.0)) ** 3 if 15.0 < t < 21.0 else 0.0
        siren2_freq = 440.0 + 80.0 * math.sin(2.0 * math.pi * 0.35 * t + 1.0)
        siren2 = math.sin(2.0 * math.pi * siren2_freq * t) * 0.025 * siren2_env

        raw[i] = traffic + hum + wind + siren1 + siren2

    # Suara klakson mobil samar (sesekali)
    horn_data = [(6.5, 0.4, 350.0), (13.0, 0.3, 420.0), (19.5, 0.35, 390.0)]
    for ht, h_dur, h_freq in horn_data:
        start_idx = int(ht * SAMPLE_RATE)
        h_len = int(h_dur * SAMPLE_RATE)
        for j in range(h_len):
            idx = start_idx + j
            if idx >= TOTAL_SAMPLES:
                break
            h_t = j / float(SAMPLE_RATE)
            env = math.sin(math.pi * j / float(h_len))
            raw[idx] += math.sin(2.0 * math.pi * h_freq * h_t) * 0.040 * env

    return make_seamless_loop(raw)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Menghasilkan aset ambience loop di: {OUTPUT_DIR}")
    print(f"Format: Mono, {SAMPLE_RATE} Hz, 16-bit PCM WAV, {DURATION:.0f} detik per file")
    print()

    write_wav("space.wav", generate_space())
    write_wav("planet.wav", generate_planet())
    write_wav("ocean.wav", generate_ocean())
    write_wav("city.wav", generate_city())

    print()
    print("Menulis file .import (compress/mode=0, loop_mode=1)...")
    # UID sederhana unik per file (tidak harus UUID valid — Godot akan menerima)
    write_import_file("space.wav",  "ambiencespace0001")
    write_import_file("planet.wav", "ambienceplanet001")
    write_import_file("ocean.wav",  "ambienceocean0001")
    write_import_file("city.wav",   "ambiencecity00001")

    print()
    print("Semua file ambience berhasil dibuat!")
    print("Jalankan: godot --headless --editor --quit  untuk reimport ke .godot/imported/")


if __name__ == "__main__":
    main()
