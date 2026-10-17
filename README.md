# Dodge 'em All

Tugas kuliah Pemrograman Game (kelompok 3 orang). Game *survival arena shooter*
2D berbasis demo resmi Godot **Dodge the Creeps**
(`godot-demo-projects/2d/dodge_the_creeps`, commit `b761b4c`).

- **Engine:** Godot 4.7 (semua anggota pakai versi yang sama)
- **Scene utama:** `main.tscn`
- **Kontrol:** panah / WASD untuk bergerak

## Konsep
Pemain bertahan dari gelombang (*wave*) musuh yang makin sulit, bisa menembak,
memungut power-up, dan melawan boss di akhir wave tertentu.

## Fitur
| Wajib | Opsional (kalau sempat) |
|---|---|
| HP + invincibility frame | Boss dengan pola serangan |
| Pemain bisa menembak | Toko upgrade antar-wave |
| 2 jenis musuh baru | Pilihan karakter |
| Sistem wave | Leaderboard |
| 2-3 power-up | Tingkat kesulitan |
| Menu, pause, game over, high score | |

## Pembagian tugas
| Anggota | Area | File utama |
|---|---|---|
| A | Player: HP, menembak, power-up | `player.*`, `bullet.*`, `powerups/` |
| B | Musuh: jenis baru, AI, wave, boss | `mob.*`, `enemies/`, `main.gd` (spawn) |
| C | UI & sistem: menu, pause, high score, audio | `hud.*`, `ui/` |

Satu scene `.tscn` hanya diedit oleh pemiliknya, supaya tidak terjadi konflik
merge.

## Jadwal (3 minggu)
1. **Minggu 1, fondasi:** pelajari kode demo, setup Git, player bisa menembak,
   punya HP, dan ada 1 musuh baru.
2. **Minggu 2, fitur utama:** power-up, musuh dan wave, menu, pause, high score.
   Akhir minggu: game bisa dimainkan dari awal sampai akhir.
3. **Minggu 3, polish:** balancing, audio dan efek, perbaikan bug, export,
   laporan dan presentasi. **Tidak ada fitur baru.**

## Cara kerja Git
1. `git pull` sebelum mulai kerja.
2. Buat branch per fitur: `git checkout -b fitur/nama-fitur`.
3. Commit kecil dan sering, lalu buka Pull Request ke `main`.
4. Folder `.godot/` tidak di-commit (sudah ada di `.gitignore`).

## Kredit
Kode dan aset dasar dari
[godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects)
(lisensi di `LICENSE`, font Xolonium di `fonts/LICENSE.txt`). README asli
demo disimpan di `README.original.md`.
