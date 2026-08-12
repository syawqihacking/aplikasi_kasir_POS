# 08 — Manajemen Kas / Shift

## Referensi PRD: Modul 3.6

## Deskripsi
Sistem pencatatan kas laci kasir per shift kerja, termasuk pembukaan, penutupan, dan rekonsiliasi uang fisik vs sistem.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Buka Kasir | Input modal awal sebelum kasir bisa mulai transaksi | ✅ Selesai |
| Tutup Kasir | Rekonsiliasi: total sistem vs total fisik, selisih otomatis tercatat | ✅ Selesai |
| Setoran/Penarikan Kas | Pencatatan uang masuk/keluar dari laci selama shift | ✅ Selesai |
| Laporan per Shift | Rekap penjualan, kas masuk/keluar, selisih per shift per kasir | ✅ Selesai |

---

## Alur Tutup Kasir

```
Kasir pilih "Tutup Kasir" → Sistem hitung total penjualan cash otomatis
→ Kasir input jumlah fisik uang di laci → Sistem tampilkan selisih
→ Kasir/Admin konfirmasi → Shift ditutup, laporan shift ter-generate
```

---

## Status Implementasi Saat Ini

- ✅ Tabel `cash_shifts` sudah ada di database.
- ✅ Halaman Shift Management dengan tombol Open/Close Shift.
- ✅ Kalkulasi otomatis: Opening Balance + Total Cash Sales + Cash In - Cash Out = Expected in Drawer.
- ✅ Dialog Close Shift dengan input fisik dan selisih otomatis.
- ✅ Tabel `cash_movements` (setor/tarik kas) sudah dibuat dan diintegrasikan di UI.
- ✅ Laporan per shift (ringkasan) muncul saat konfirmasi penutupan.
- ✅ Pencegahan akses POS jika shift belum dibuka sudah diaktifkan.

## File Terkait

- `lib/screens/shift_screen.dart`
- `lib/database/database_helper.dart` (methods: `openShift()`, `closeShift()`, `getActiveShift()`)
