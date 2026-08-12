# 03 — Dashboard

## Referensi PRD: Modul 3.2

## Deskripsi
Ringkasan informasi real-time saat aplikasi dibuka setelah login.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Total Produk, Kategori, Supplier | Angka ringkasan di stat cards | ✅ Selesai |
| Penjualan & Pendapatan Hari Ini | Jumlah transaksi dan total omset hari ini | ✅ Selesai |
| Produk Stok Menipis | Daftar produk yang stoknya di bawah `min_stock` | ✅ Selesai |
| Produk Tanpa Barcode | Peringatan produk yang belum punya barcode | ✅ Selesai |
| Grafik Penjualan | Line/bar chart harian/mingguan | ❌ Digantikan oleh list aksi (Action Needed) |
| 10 Transaksi Terakhir | Tabel riwayat transaksi terbaru | ✅ Selesai |
| Status Shift Kasir Aktif | Info siapa yang login dan apakah shift sudah dibuka | ✅ Selesai |
| Ringkasan Kas Hari Ini | Total kas masuk jika shift aktif | ✅ Selesai |

---

## Acceptance Criteria

- [x] Data dashboard di-refresh otomatis setiap kali halaman dibuka.
- [x] Stat cards menampilkan angka real dari database.
- [x] Produk stok menipis ditampilkan sebagai daftar alert.

---

## Status Implementasi Saat Ini

- ✅ Fitur dashboard sepenuhnya menggunakan data *real-time* dari SQLite.
- ✅ Menambahkan `ActiveShiftSummary` untuk melacak status kas/shift saat ini.
- ✅ Menambahkan `RecentTransactions` untuk melihat histori 10 penjualan terakhir.
- ✅ Menambahkan `ActionNeededList` yang berisi daftar produk stok menipis & tanpa barcode.
- ✅ Stat cards menampilkan performa penjualan hari ini dan total entitas database (Produk/Supplier/Kategori).

## File Terkait

- `lib/screens/dashboard_content.dart`
- `lib/screens/widgets/stat_cards.dart`
- `lib/screens/widgets/active_shift_summary.dart`
- `lib/screens/widgets/recent_transactions.dart`
- `lib/screens/widgets/action_needed_list.dart`
