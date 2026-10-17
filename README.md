# Dodge 'em All

Game bertahan hidup 2D untuk tugas kuliah Pemrograman Game (kelompok 3 orang).
Pemain menghindari gelombang (*wave*) musuh dengan perilaku berbeda-beda,
dengan 3 nyawa, sampai menyelesaikan wave 10. Dibangun dari demo resmi Godot
**Dodge the Creeps** (`godot-demo-projects/2d/dodge_the_creeps`, commit `b761b4c`).

- **Engine:** Godot 4.7 (semua anggota memakai versi yang sama)
- **Platform:** Android (utama) dan desktop
- **Scene utama:** `main.tscn`
- **Batas pengumpulan:** sebelum 19 November 2026 (target 18 November)

## Cara main

- Hindari semua musuh. Setiap tersentuh musuh, nyawa berkurang 1 dan karakter
  kebal sebentar. Nyawa habis = game over.
- Ambil item hati yang sesekali muncul untuk menambah nyawa (maksimal 3).
- Skor: +1 per detik bertahan, ditambah bonus 10 × nomor wave setiap wave selesai.
- Selesaikan wave 10 untuk menang. Di akhir setiap wave, pilih lanjut, simpan
  lalu keluar, atau keluar.

## Kontrol

| Aksi | Keyboard / gamepad | Layar sentuh |
| --- | --- | --- |
| Bergerak | WASD, tombol panah, D-pad, stik kiri | Sentuh di mana saja lalu geser; karakter ikut sejauh jari bergeser |
| Mulai | Enter, Spasi | Tap tombol Start |
| Pause *(rencana)* | Esc | Tombol pause, tombol Back |

Di laptop, kontrol sentuh bisa dicoba dengan klik dan seret mouse.

## Status fitur

| # | Fitur | Pemilik | Status |
| --- | --- | --- | --- |
| – | Dasar dari demo Dodge the Creeps | – | Selesai |
| – | Orientasi potret, layar penuh, kontrol sentuh | – | Selesai |
| 1 | High score tersimpan | C | Belum |
| 2 | Tombol pause | C | Belum |
| 3 | Nyawa (3) + item nyawa gratis | A | Belum |
| 4 | Jenis musuh berbeda (min. 3 dari 5) | B | Belum |
| 5 | Wave dan sub-wave, 10 wave | B | Belum |
| 6 | Simpan progress di akhir wave | A + C | Belum |
| 7 | Menembak | A | Ditunda, kalau masih ada waktu |

Perbarui kolom Status setiap fitur masuk ke branch `master`.

## Aturan permainan

**Wave.** Satu wave = 3 sub-wave masing-masing 20 detik, dengan jeda 2 detik di
antaranya. Setiap wave makin cepat dan padat:

- Interval spawn = max(0,2; 0,6 × 0,9^(wave−1)) detik
- Kecepatan musuh = acak(150, 250) × (1 + 0,1 × (wave−1)) px/detik

**Jenis musuh.**

| Jenis | Perilaku | Mulai muncul |
| --- | --- | --- |
| Walker | Lurus dengan arah acak | Wave 1 |
| Swimmer | Maju sambil bergelombang | Wave 1 |
| Chaser | Lambat, membelok ke arah pemain selama 5 detik | Wave 2 |
| Dasher | Diam 1 detik sambil berkedip, lalu melesat ke posisi pemain | Wave 3 |
| Splitter | Lambat, pecah jadi 2 musuh kecil setelah 2 detik | Wave 4 |

**Nyawa.** 3 nyawa awal (maksimal 3), kebal 1,5 detik setelah tertabrak. Item
nyawa muncul acak setiap 10–20 detik hanya kalau nyawa belum penuh, bertahan
6 detik.

**Simpan progress.** Satu slot simpanan (wave berikutnya, skor, nyawa). Simpanan
dihapus saat game over, menang, atau saat memilih Main Baru (dengan konfirmasi).

## Pembagian tugas

| Anggota | Area | File utama |
| --- | --- | --- |
| A | Player: nyawa, item nyawa, logika simpan progress, (menembak) | `player.*`, `life_pickup.*`, `save_manager.gd` |
| B | Musuh dan wave: jenis musuh, sub-wave, kesulitan | `mob.*`, `enemies/`, `wave_manager.gd` |
| C | UI dan sistem: high score, pause, HUD, layar akhir wave dan judul | `hud.*`, `ui/` |

Satu scene `.tscn` hanya diedit oleh pemiliknya, supaya tidak terjadi konflik merge.

## Jadwal

| Tanggal | Target |
| --- | --- |
| 23 Okt | Fondasi selesai: high score, pause, nyawa, jenis musuh |
| 30 Okt | Semua fitur wajib (1–6) lengkap |
| 2–7 Nov | Menembak (opsional, dihentikan kalau belum stabil 7 Nov) |
| 2–13 Nov | Balancing, perbaikan bug, APK |
| 9–16 Nov | Presentasi (C), video demo (B), repo + README + APK final (A) |
| 17 Nov | Cek akhir paket pengumpulan |
| 18 Nov | Kumpul (batas: sebelum 19 Nov) |

Setiap Jumat (23 Okt, 30 Okt, 6 Nov, 13 Nov): gabungkan semua branch ke
`master` dan mainkan bersama di HP.

## Pengumpulan

| Item | Isi | Link |
| --- | --- | --- |
| Repository GitHub | Kode lengkap, README ini, tag rilis `v1.0` | *(isi link)* |
| APK final | `dodge-em-all-v1.0.apk`, release, di GitHub Releases | *(isi link)* |
| Video demo | 2–3 menit, semua fitur utama sampai layar menang | *(isi link)* |
| Presentasi | 10–12 slide | *(isi link)* |

## Build APK Android

1. Install OpenJDK 17 dan Android SDK (lewat Android Studio).
2. Godot: **Editor → Editor Settings → Export → Android**, isi `Java SDK Path` dan `Android SDK Path`.
3. **Editor → Manage Export Templates → Download and Install**.
4. **Project → Export → Android**, simpan ke folder `export/` (tidak ikut di-commit).

Untuk tes cepat: aktifkan USB debugging di HP, sambungkan kabel, lalu klik ikon
Android di kanan atas editor.

## Struktur project

```
dodge-em-all/
├── main.tscn / main.gd      # aturan permainan, spawn, skor
├── player.tscn / player.gd  # karakter pemain, kontrol keyboard dan sentuh
├── mob.tscn / mob.gd        # musuh dasar
├── hud.tscn / hud.gd        # skor, pesan, tombol
├── enemies/                 # (rencana) jenis musuh tambahan
├── ui/                      # (rencana) panel pause, akhir wave, konfirmasi
├── art/, fonts/             # aset
└── export/                  # hasil export (diabaikan Git)
```

## Cara kerja Git

1. `git pull` sebelum mulai kerja.
2. Buat branch per fitur: `git checkout -b fitur/nama-fitur`.
3. Commit kecil dan sering, lalu buka Pull Request ke `master`.
4. Folder `.godot/` dan `export/` tidak di-commit (sudah ada di `.gitignore`).

## Kredit

- Kode dan aset dasar dari
  [godotengine/godot-demo-projects](https://github.com/godotengine/godot-demo-projects)
  (lisensi di `LICENSE`, font Xolonium di `fonts/LICENSE.txt`). README asli
  demo disimpan di `README.original.md`.
- Aset tambahan berlisensi CC0 *(tambahkan nama paket dan link setiap kali
  memakai aset baru, misalnya dari [Kenney](https://kenney.nl/assets) atau
  [OpenGameArt](https://opengameart.org))*.
