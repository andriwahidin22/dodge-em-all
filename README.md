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

> Nyawa, item hati, dan pilihan di akhir wave belum diimplementasikan (fitur #3 dan #6).
> Untuk sementara, saat tertabrak muncul kuis hidup-lagi (sekali per wave); jawaban benar
> = lanjut bermain, salah = game over.

## Kontrol

| Aksi | Keyboard / gamepad | Layar sentuh |
| --- | --- | --- |
| Bergerak | WASD, tombol panah, D-pad, stik kiri | Sentuh di mana saja lalu geser; karakter ikut sejauh jari bergeser |
| Mulai | Enter, Spasi | Tap tombol Start |
| Pause | Esc, Start (gamepad) | Tombol pause, tombol Back |

Di laptop, kontrol sentuh bisa dicoba dengan klik dan seret mouse.

## Status fitur

*Terakhir diperbarui: 3 November 2026.*

| # | Fitur | Pemilik | Status | Catatan |
| --- | --- | --- | --- | --- |
| – | Dasar dari demo Dodge the Creeps | – | Selesai | |
| – | Orientasi potret, layar penuh, kontrol sentuh | – | Selesai | |
| 1 | High score tersimpan | C | Selesai | |
| 2 | Tombol pause | C | Selesai | Esc / Start gamepad / tombol Back; pause otomatis saat aplikasi kehilangan fokus |
| 3 | Nyawa (3) + item nyawa gratis | A | Belum | Saat ini sekali tertabrak langsung kuis hidup-lagi (#9) atau game over |
| 4 | Jenis musuh berbeda (min. 3 dari 5) | B | Selesai | Kelima jenis sudah ada: Walker, Swimmer, Chaser, Dasher, Splitter |
| 5 | Wave dan sub-wave, 10 wave | B | Selesai | Termasuk komposisi musuh per sub-wave, batas musuh di layar, debug F2 |
| 6 | Simpan progress di akhir wave | A + C | Belum | `WaveManager.start_waves(n)` sudah siap untuk "Lanjutkan"; layar akhir wave dan `SaveManager.save_progress()` belum ada. Wave saat ini otomatis lanjut |
| 7 | Menembak | A | Ditunda, kalau masih ada waktu | Sprite musuh terkena tembakan (`art/enemies/*_hit.png`) sudah tersedia |
| 8 | Latar luar angkasa prosedural & tema visual | – | Selesai | |
| 9 | Kuis hidup-lagi (1x per wave) & dialog modal | – | Selesai | |
| 10 | Layar credit | C | Selesai | |
| 11 | Audio tambahan per wave | C | Selesai | Pitch musik naik per wave + SFX awal wave, sub-wave, wave selesai, menang |

Perbarui kolom Status setiap fitur masuk ke branch `master`.

### Sisa pekerjaan

- [ ] **#3 Nyawa + item hati** (A). Putuskan bersama cara menggabungkannya dengan kuis
      hidup-lagi (#9), misalnya kuis baru muncul saat nyawa terakhir habis.
- [ ] **#6 Simpan progress** (A + C). Layar akhir wave (Lanjut / Simpan & Keluar / Keluar),
      tombol "Lanjutkan" dan "Main Baru" di layar judul, simpan dan hapus progress di `save_manager.gd`.
- [ ] **HUD sub-wave** (C). Tampilkan "Wave n/10 · s/3" dan pesan "Sub-wave 2" / "Sub-wave 3".
- [ ] **Balancing** (B). Mainkan sampai wave 10 di HP (gunakan F2 untuk melompati wave), lalu atur
      `MAX_MOBS_*`, bobot di `WAVES`, dan kecepatan musuh di `wave_manager.gd`.
- [ ] **APK release, video demo, presentasi** (lihat Jadwal dan Pengumpulan).

## Aturan permainan

**Wave.** Satu wave = 3 sub-wave masing-masing 20 detik, dengan jeda 2 detik di
antaranya. Setiap wave makin cepat dan padat:

- Interval spawn = max(0,2; 0,6 × 0,9^(wave−1)) detik
- Kecepatan musuh = acak(150, 250) × (1 + 0,1 × (wave−1)) px/detik
- Batas musuh di layar sekaligus = 5 + (wave−1); giliran spawn dilewati kalau sudah penuh

Saat menguji dari editor (build debug), tekan **F2** untuk langsung menyelesaikan wave
yang sedang berjalan.

**Jenis musuh.**

| Jenis | Sprite | Perilaku | Mulai muncul |
| --- | --- | --- | --- |
| Walker | Lalat | Lurus dengan arah acak | Wave 1 |
| Swimmer | Ikan hijau | Maju sambil bergelombang | Wave 1 |
| Chaser | Kelelawar | Lambat, membelok ke arah pemain selama 5 detik | Wave 2 |
| Dasher | Lebah | Diam 1 detik sambil berkedip, lalu melesat ke posisi pemain | Wave 3 |
| Splitter | Slime hijau | Lambat, pecah jadi 2 slime biru kecil setelah 2 detik | Wave 4 |

Jenis baru diperkenalkan berdua dengan Walker dulu, baru dicampur di sub-wave
berikutnya. Wave 5–10 memakai campuran acak dari semua jenis. Komposisinya ada di
tabel `WAVES` di `wave_manager.gd`.

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
├── enemies/                 # walker, swimmer, chaser, dasher, splitter (+ splitter_small)
├── wave_manager.gd          # 10 wave × 3 sub-wave, komposisi musuh, kesulitan, batas musuh
├── hud.tscn / hud.gd        # skor, pesan, tombol, pause
├── credits.gd               # kartu credit dan logika tampilan/skip credit
├── quiz_bank.gd             # bank soal kuis hidup-lagi
├── quiz_panel.gd            # dialog modal kuis hidup-lagi
├── save_manager.gd          # autoload: simpan/muat high score
├── space_background.*       # latar luar angkasa prosedural dan event acak
├── space_theme.gd           # warna dan gaya UI tema luar angkasa
├── wave_audio.gd            # pengatur audio adaptif wave (pitch naik, WAVE_MUSIC, sfx)
├── validate_quiz.py         # skrip cek kunci jawaban bank soal
├── tools/                   # skrip pembantu (generator sfx sintetis)
├── art/, fonts/             # aset visual dan audio (art/audio/)
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
- Aset tambahan, semuanya berlisensi CC0:
  - Ikon pause, resume, keluar, simpan: [Kenney Game Icons](https://opengameart.org/content/game-icons)
  - Tombol dan panel menu: [Kenney UI Pack](https://kenney.nl/assets/ui-pack)
  - Ikon nyawa: [25x25 Hearts](https://opengameart.org/content/25x25-hearts) oleh Min
  - Pemain dan musuh: [Kenney Platformer Pack Redux](https://opengameart.org/content/platformer-pack-redux-360-assets)
    dan [Kenney Platformer Art: More Animations & Enemies](https://opengameart.org/content/platformer-art-more-animations-and-enemies)
  - Musik latar "House In a Forest Loop" oleh [HorrorPen](https://opengameart.org/content/loop-house-in-a-forest) (CC-BY 3.0)
  - Efek suara sintetis wave (`art/audio/*.wav`) dibuat dengan skrip generator Python `tools/generate_wave_sfx.py` (CC0 / Public Domain)
