# MyGarage

**Buku servis digital untuk pemilik kendaraan bermotor** — catat riwayat perbaikan, biaya, dan dapatkan pengingat kapan servis berikutnya. Data tersimpan di Cloud Firestore, jadi tetap ada setelah aplikasi ditutup atau browser di-refresh.

| | |
|---|---|
| Mahasiswa | Anggaradyan Jannes Minardi |
| NIM / Kelas | 22.01.65.0002 / A1 (Pagi) |
| Mata kuliah | Mobile and Web Application Development — UNISBANK, Ganjil 2026/2027 |
| Platform | Mobile + Web (Flutter cross-platform) |
| Wireframe | [2201650002 - MyGarage - Wireframe (Figma)](https://www.figma.com/design/S5iVPGaOGy1oqVoXQYsrmH/2201650002-MyGarage-Wireframe) |

## Deskripsi

Pemilik kendaraan saat ini mengandalkan nota kertas yang mudah hilang dan ingatan untuk jadwal servis. Akibatnya perawatan telat dan biaya perbaikan membengkak. MyGarage menggantinya dengan buku servis digital: setiap selesai dari bengkel, pengguna mencatat jenis perbaikan, tanggal, kilometer, dan biaya — aplikasi menampilkan riwayat terurut dan indikator pengingat (hijau = sudah servis, merah = sudah ≥3 bulan sejak servis terakhir).

## Fitur (MVP)

- **K1 — Login** (MUST): masuk/daftar dengan email + kata sandi lewat **Firebase Authentication**; galat ditampilkan dalam Bahasa Indonesia, email terdaftar tidak dibocorkan, tersedia reset kata sandi.
- **K2 — Tambah Catatan Servis** (MUST): form Nama Perbaikan, Kendaraan (pilihan dari collection `kendaraan`), Tanggal (date picker), Kilometer, Biaya (Rp) — validasi: jenis wajib, biaya wajib, biaya > 0 (tanpa plafon biaya).
- **K3 — Riwayat Servis** (MUST): daftar urut dari tanggal terbaru, dibaca real-time per pengguna (`StreamBuilder`), dengan keadaan loading / galat / kosong.
- **K4 — Indikator Pengingat** (MUST): blok hijau/merah di Beranda berdasarkan tanggal servis terakhir (≥3 bulan = merah).
- **K5 — Responsif** (SHOULD): versi web memakai sidebar + tabel; versi mobile memakai bottom navigation + kartu.
- **K6 — Push Notification** (WON'T): sengaja tidak dibuat (melanggar batasan Firebase Spark tanpa billing).

## Screenshot

| Login | Beranda | Form Tambah | Riwayat Servis |
|---|---|---|---|
| ![](docs/screenshots/login.png) | ![](docs/screenshots/beranda.png) | ![](docs/screenshots/tambah.png) | ![](docs/screenshots/riwayat.png) |

## Tech stack

- **Flutter + Dart** — UI dan logika (satu basis kode untuk Android & web)
- **Firebase Spark (gratis)** — Authentication (email/password) + **Cloud Firestore** (`cloud_firestore` 7.1.0) untuk seluruh data
- **Figma** — wireframe & style guide (#0D47A1 navy, Inter 24/18/14/12, radius 10, target sentuh 48 px)
- **GitHub** — versi kode

## Struktur data (Cloud Firestore)

Tiga collection top-level. Nama kendaraan **disalin (denormalisasi)** ke setiap catatan servis karena Firestore tidak mendukung JOIN antar-collection.

```
users/{uid}                     Doc ID = uid Firebase Authentication
  id_pengguna:   string
  nama_lengkap:  string
  email:         string
  nomor_telepon: string
  peran:         string
  dibuat_pada:   timestamp

kendaraan/{id_kendaraan}        master data, di-seed otomatis sekali
  id_kendaraan:  string
  nama_kendaraan:string
  merek:         string
  tahun:         number
  plat_nomor:    string

servis/{id_catatan}             Doc ID = id_catatan (string)
  id_catatan:    number
  id_pengguna:   string         <- pemilik (uid); dasar filter & isolasi data
  id_kendaraan:  string
  nama_kendaraan:string        <- denormalisasi dari collection kendaraan
  jenis:         string
  tanggal:       timestamp
  kilometer:     number?        (opsional)
  biaya:         number         (rupiah)
  dibuat_pada:   timestamp
```

Setiap pengguna hanya melihat catatannya sendiri: query memakai satu `.where('id_pengguna', isEqualTo: uid)` dan pengurutan dilakukan di sisi Dart, sehingga tidak butuh composite index.

### Aturan bisnis: tolak catatan ganda

Satu jenis servis tidak boleh dicatat dua kali pada tanggal yang sama oleh pengguna yang sama (adaptasi aturan "tolak jadwal bentrok" pada studi kasus modul). Pelanggaran ditolak sebelum menulis dokumen dan ditampilkan sebagai SnackBar merah; form tetap terbuka dengan isian utuh.

### Security Rules

`firestore.rules` (disalin apa adanya dari Firebase Console, sudah dipublikasi):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Struktur kode

| Berkas | Isi |
|---|---|
| `lib/main.dart` | UI: Login, Beranda, Riwayat, Form Tambah/Ubah, navigasi mobile & web |
| `lib/models.dart` | Model `Pengguna`, `Kendaraan`, `CatatanServis` + `toMap`/`fromMap` |
| `lib/services/layanan_firestore.dart` | Satu pintu ke database: `LayananData` (abstrak), `LayananFirestore`, `LayananMemori` (untuk widget test tanpa Firebase) |
| `firestore.rules` | Security Rules yang dipublikasi di Console |
| `test/` | 40 test: unit aturan validasi, unit auth, form K01–K12, status pengingat, layanan Firestore (F01–F10), golden screenshot |

## Cara menjalankan

```bash
flutter pub get
flutter run -d chrome --web-port 8080   # versi web
flutter run                             # pilih device/emulator Android
```

Untuk melihat tampilan mobile di browser: Chrome → F12 → Toggle device toolbar (Ctrl+Shift+M) → ukuran 412x917.

## Pengujian

```bash
flutter analyze   # No issues found
flutter test      # 40 kasus, semua lulus
```

Rincian: 5 unit `periksaCatatan` · 3 unit validasi login + pesan galat · 5 widget login L01–L05 · 3 unit `statusPengingat` · 12 widget form K01–K12 · 10 test Firestore F01–F10 · 1 golden screenshot (4 layar 412×917).

### Tabel uji Cloud Firestore

Kolom "Cara verifikasi": **REST** = panggilan langsung ke Firestore dengan token akun uji (bukti data di server), **test** = `flutter test`, **Chrome** = diuji manual di browser.

| # | Kasus uji | Langkah | Hasil yang diharapkan | Hasil nyata | Cara verifikasi |
|---|---|---|---|---|---|
| 1 | Tambah data valid | Login → Beranda → Tambah Servis → isi Nama Perbaikan, Kendaraan, Tanggal, Biaya → Simpan | SnackBar hijau "Catatan servis disimpan"; kartu muncul di Riwayat; dokumen masuk collection `servis` dengan `id_pengguna` = uid | Dokumen tertulis `HTTP 200` dan terbaca kembali sebagai `['Ganti Oli Mesin']` oleh pemiliknya; kartu Riwayat muncul di test widget | REST + test |
| 2 | Tolak catatan ganda | Simpan "Ganti Oli Mesin" tanggal X, lalu simpan lagi jenis sama tanggal sama | SnackBar merah "Catatan servis untuk tanggal ini sudah ada"; form tetap terbuka; dokumen tidak bertambah | `CatatanDuplikatException` terlempar; SnackBar merah tampil; jumlah kartu tetap 1 | test (F04, F07) |
| 3 | Bertahan saat refresh | Simpan catatan → tekan F5 di Chrome (atau login ulang) | Data tetap tampil karena dibaca dari Firestore, bukan memori | Dokumen tetap ada saat dibaca dengan token baru (sesi baru), jadi sumber datanya server | REST + test |
| 4 | Isolasi antar akun | Akun A simpan catatan → keluar → masuk akun B → buka Riwayat | Riwayat B kosong; catatan A tidak terlihat | Akun B membaca `servis` → `200` dengan **0 dokumen** milik A | REST (dua akun uji) |
| 5 | Security Rules | Akses tanpa login; lalu ulangi dengan token | Tanpa login `permission-denied`; dengan login `200` | Tanpa token `403 PERMISSION_DENIED`; dengan token `200` | REST |

Catatan: baris 1–5 sudah diverifikasi dari sisi server; klik-uji manual di Chrome tetap disarankan sekali untuk merekam tangkapan layar Console (isi ketiga collection) sebagai lampiran.
