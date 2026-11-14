#!/usr/bin/env python3
"""
Generator ikon nyawa pixel-art (CC0 / Public Domain)
Dodge 'em All - Tugas Pemrograman Game

Menghasilkan 2 ikon PNG 60x60 (grid 15x15 piksel, tiap piksel diperbesar 4x):
- art/hearts/heart_full.png : hati penuh (merah-pink dengan kilap dan bayangan)
- art/hearts/heart_empty.png: hati kosong (garis tepi abu-biru, isi gelap transparan)

Hati mengisi hampir seluruh kotak (15x13 dari 15x15) supaya terlihat jelas di HUD,
dan warnanya dipilih agar kontras dengan latar luar angkasa yang gelap.

Hanya memakai modul bawaan Python (zlib, struct), tanpa dependensi eksternal.
Jalankan dari root project:  python tools/generate_hearts.py
"""

import os
import struct
import zlib

SCALE = 4  # 1 piksel grid = 4x4 piksel di PNG (tetap tajam dengan filter Nearest)

# Bentuk hati 15x13. X = bagian hati.
SHAPE = [
	"..XXX.....XXX..",
	".XXXXX...XXXXX.",
	"XXXXXXX.XXXXXXX",
	"XXXXXXXXXXXXXXX",
	"XXXXXXXXXXXXXXX",
	"XXXXXXXXXXXXXXX",
	".XXXXXXXXXXXXX.",
	"..XXXXXXXXXXX..",
	"...XXXXXXXXX...",
	"....XXXXXXX....",
	".....XXXXX.....",
	"......XXX......",
	".......X.......",
]
GRID = 15            # kanvas 15x15
TOP_PAD = 1          # hati 13 baris diletakkan mulai baris ke-1 (tengah vertikal)

# Kilap (kiri atas) dan bayangan (kanan bawah), koordinat di dalam SHAPE (kolom, baris).
HIGHLIGHT = {(2, 1), (3, 1), (1, 2), (2, 2), (1, 3)}
HIGHLIGHT_SOFT = {(4, 1), (3, 2), (2, 3), (1, 4)}

# Warna RGBA
FULL_OUTLINE = (58, 8, 26, 255)
FULL_FILL = (255, 77, 109, 255)
FULL_SHADE = (201, 24, 74, 255)
FULL_HIGHLIGHT = (255, 230, 236, 255)
FULL_HIGHLIGHT_SOFT = (255, 160, 180, 255)

EMPTY_OUTLINE = (125, 138, 168, 255)
EMPTY_FILL = (20, 26, 44, 150)


def inside(col, row):
	return 0 <= row < len(SHAPE) and 0 <= col < len(SHAPE[0]) and SHAPE[row][col] == "X"


def is_outline(col, row):
	"""Piksel hati yang bersebelahan (4 arah) dengan luar hati."""
	return any(not inside(col + dc, row + dr) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def is_shade(col, row):
	"""Bayangan: piksel dalam yang tepat di atas/kiri garis tepi kanan-bawah."""
	return (not inside(col + 1, row + 1)) or (not inside(col, row + 2) and row >= 6)


def heart_pixels(full):
	grid = [[(0, 0, 0, 0)] * GRID for _ in range(GRID)]
	for row, line in enumerate(SHAPE):
		for col, ch in enumerate(line):
			if ch != "X":
				continue
			if is_outline(col, row):
				color = FULL_OUTLINE if full else EMPTY_OUTLINE
			elif not full:
				color = EMPTY_FILL
			elif (col, row) in HIGHLIGHT:
				color = FULL_HIGHLIGHT
			elif (col, row) in HIGHLIGHT_SOFT:
				color = FULL_HIGHLIGHT_SOFT
			elif is_shade(col, row):
				color = FULL_SHADE
			else:
				color = FULL_FILL
			grid[row + TOP_PAD][col] = color
	return grid


def write_png(path, grid):
	"""Menyimpan grid RGBA ke PNG, tiap sel diperbesar SCALE x SCALE."""
	size = GRID * SCALE
	raw = bytearray()
	for row in grid:
		line = bytearray()
		for rgba in row:
			line += bytes(rgba) * SCALE
		for _ in range(SCALE):
			raw += b"\x00" + line  # filter type 0 per baris

	def chunk(tag, data):
		body = tag + data
		return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

	png = b"\x89PNG\r\n\x1a\n"
	png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))  # 8-bit RGBA
	png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
	png += chunk(b"IEND", b"")
	os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
	with open(path, "wb") as f:
		f.write(png)
	print("Ditulis:", path)


if __name__ == "__main__":
	root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
	write_png(os.path.join(root, "art", "hearts", "heart_full.png"), heart_pixels(True))
	write_png(os.path.join(root, "art", "hearts", "heart_empty.png"), heart_pixels(False))
