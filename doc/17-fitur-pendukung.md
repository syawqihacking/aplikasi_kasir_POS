# 17 — Fitur Pendukung

## Referensi PRD: Modul 3.19 & 3.20

## Deskripsi
Fitur-fitur pendukung yang meningkatkan kenyamanan dan produktivitas pengguna.

---

## 17.1 Fitur Pendukung Umum (PRD 3.19)

| Fitur | Detail | Status |
|---|---|---|
| Shortcut Keyboard | F1-F12 untuk aksi cepat di kasir (bayar, hold, batal, cari) | ✅ Selesai |
| Auto Focus ke Kolom Scan | Kursor otomatis di field scan | ✅ Selesai |
| Dark Mode / Light Mode | Toggle tema gelap/terang | ✅ Selesai |
| Auto Save (draft transaksi) | Draft transaksi otomatis tersimpan | ✅ Selesai |
| Auto Refresh Data | Data otomatis diperbarui | ✅ Selesai |
| Pencarian Cepat & Filter/Sorting | Produk bisa dicari dan disortir | ✅ Selesai |

---

## 17.2 Fitur Khusus Offline (PRD 3.20)

| Fitur | Detail | Status |
|---|---|---|
| Database SQLite Lokal Penuh | Semua data di lokal | ✅ Selesai |
| Transaksi Tanpa Internet | Seluruh operasi offline | ✅ Selesai |
| Sinkronisasi Manual | Opsional untuk pengembangan online di masa depan | ❌ Belum |
| Backup ke Flashdisk/HDD | Export database ke media eksternal | ✅ Selesai |

---

## Status Implementasi Saat Ini

- ✅ Operasi offline penuh berjalan dengan SQLite.
- ✅ Pencarian produk berfungsi di POS.
- ✅ Shortcut keyboard berhasil ditambahkan (F1-F3).
- ✅ Dark mode toggle ditambahkan (tersedia di sidebar).
- ✅ Auto save draft (otomatis simpan cart ke database saat berubah).
- ✅ Backup Database (export .db) via Settings Screen.

## File Terkait

- `lib/services/scanner_service.dart` (auto-focus terkait)
- `lib/screens/pos_screen.dart` (pencarian produk)
