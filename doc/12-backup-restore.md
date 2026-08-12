# 12 — Backup & Restore

## Referensi PRD: Modul 3.14

## Deskripsi
Sistem pencadangan dan pemulihan database untuk mencegah kehilangan data.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Backup Database | Export file `.db`/`.zip` ke lokasi pilihan (flashdisk/HDD eksternal) | ✅ Selesai |
| Restore Database | Import kembali dengan validasi integritas file sebelum overwrite | ✅ Selesai |
| Backup Otomatis | Terjadwal (harian/mingguan), simpan N backup terakhir (rolling) | ✅ Selesai |
| Notifikasi Backup | Peringatan jika backup terakhir sudah lebih dari X hari | ✅ Selesai |

---

## Acceptance Criteria

- [x] Backup menghasilkan file yang bisa direstore tanpa kehilangan data.
- [x] Restore database < 5 menit tanpa kehilangan data setelah titik backup.
- [x] Rolling backup menyimpan N file terbaru dan menghapus yang lama.
- [x] Notifikasi muncul jika backup terakhir > X hari.

---

## Status Implementasi Saat Ini

- ✅ Halaman `BackupRestoreScreen` telah dibuat dan ditambahkan di bagian TOOLS pada Sidebar.
- ✅ Logic backup `BackupService` diimplementasikan (mencadangkan `.db` langsung dari sqflite path).
- ✅ Menggunakan limit MAX_BACKUPS (5 file) untuk *rolling backup* lokal, otomatis terhapus yang lebih lama.
- ✅ Terdapat fitur *Export ke Folder* (menggunakan FilePicker) jika pengguna ingin menyimpan ke eksternal disk.
- ✅ Layar menampilkan peringatan otomatis apabila backup terakhir sudah melebihi 7 hari.

## File Terkait

- _(Belum ada)_
