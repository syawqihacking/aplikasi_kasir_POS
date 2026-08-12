# 11 — Laporan

## Referensi PRD: Modul 3.13

## Deskripsi
Modul pelaporan untuk analisis bisnis, evaluasi performa, dan pembukuan.

---

## Fitur Detail

| Laporan | Detail | Status |
|---|---|---|
| Penjualan Harian/Bulanan/Tahunan | Filter rentang tanggal custom | ✅ Selesai |
| Laporan Keuntungan | Selisih harga jual vs harga beli, per produk/kategori/periode | ✅ Selesai |
| Barang Terlaris & Tidak Laku | Ranking berdasarkan qty terjual dalam periode | ✅ Selesai |
| Laporan Barang Masuk/Keluar | Rekap per supplier/per alasan | ✅ Selesai |
| Laporan Stok | Snapshot stok saat ini + nilai stok (qty × harga beli) | ✅ Selesai |
| Laporan per Shift/Kasir | Evaluasi performa & kejujuran kasir | ✅ Selesai |
| Export Excel | Semua laporan bisa diekspor ke `.xlsx` | ✅ Selesai |
| Export PDF | Semua laporan bisa diekspor ke `.pdf` | ✅ Selesai |
| Print Laporan | Cetak langsung ke printer biasa (bukan thermal) | ❌ Belum |

---

## Acceptance Criteria

- [x] Semua laporan bisa difilter berdasarkan rentang tanggal.
- [x] Export Excel menghasilkan file `.xlsx` yang valid dan bisa dibuka di Excel/Google Sheets.
- [x] Laporan keuntungan menghitung selisih sell_price vs cost_price dikali qty.
- [x] Laporan per shift menampilkan rekap kas dan selisih.

---

## Status Implementasi Saat Ini

- ✅ Halaman `TransactionsScreen` sudah ada (riwayat transaksi).
- ✅ Halaman `ReportsScreen` (Laporan Bisnis) telah dibuat dengan tab lengkap, termasuk Laporan Shift.
- ✅ Package `excel`, `pdf`, dan `printing` telah ditambahkan ke `pubspec.yaml`.
- ✅ Fungsionalitas Export Excel (.xlsx) dan PDF sudah diimplementasikan (disimpan ke folder Downloads).

## File Terkait

- `lib/screens/transactions_screen.dart`
