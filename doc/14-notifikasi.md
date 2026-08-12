# 14 — Notifikasi

## Referensi PRD: Modul 3.16

## Deskripsi
Sistem notifikasi internal untuk mengingatkan pengguna tentang kondisi penting yang perlu perhatian.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Stok Hampir Habis | Alert saat stok produk di bawah `min_stock` | ✅ Selesai |
| Produk Tanpa Barcode | Peringatan produk yang belum punya barcode | ✅ Selesai |
| Backup Belum Dilakukan | Reminder jika backup terakhir > X hari | ✅ Selesai |
| Barang Kadaluarsa | Peringatan (jika field `expiry_date` diaktifkan) | ⚠️ (Field Belum Ada) |
| Shift Belum Ditutup | Peringatan di akhir hari jika shift masih OPEN | ✅ Selesai |

---

## Status Implementasi Saat Ini

- ✅ `NotificationService` telah diimplementasikan untuk melakukan validasi *low stock*, absen *barcode*, peringatan *backup*, dan *open shift*.
- ✅ Menggunakan tombol/ikon notifikasi bawaan yang sudah ada di kanan atas (`Header` widget).
- ✅ *Badge* jumlah notifikasi muncul secara dinamis pada ikon lonceng tersebut, dan ikon dapat di-klik untuk membuka modal peringatan terpusat.
- ⚠️ *Barang Kadaluarsa* dilewati sementara karena model produk belum memiliki atribut `expiry_date`.

## File Terkait

- `lib/services/notification_service.dart`
- `lib/screens/widgets/header.dart`
