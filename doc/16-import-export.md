# 16 — Import & Export Data

## Referensi PRD: Modul 3.18

## Deskripsi
Fitur untuk mengimpor dan mengekspor data master (produk, supplier) via file Excel, memudahkan migrasi data atau input data massal.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Import Produk via Excel | Template standar + validasi baris error sebelum commit | ✅ Selesai |
| Export Produk via Excel | Export daftar produk ke file `.xlsx` | ✅ Selesai |
| Import Supplier | Import data supplier dari file Excel | ✅ Selesai |
| Export Supplier | Export daftar supplier ke file `.xlsx` | ✅ Selesai |

---

## Acceptance Criteria

- [x] Import memvalidasi setiap baris dan menampilkan error sebelum commit ke database.
- [x] Template Excel bisa diunduh dari aplikasi.
- [x] Export menghasilkan file `.xlsx` yang valid.

---

## Status Implementasi Saat Ini

- ✅ `ImportExportService` telah dibuat dengan fitur export, import, dan download template untuk produk dan supplier.
- ✅ Tombol "Import / Export" tersedia di halaman Products dan Suppliers.
- ✅ Import memvalidasi baris per baris (nama wajib ada, kategori otomatis dibuat jika belum ada).
- ✅ Hasil import menampilkan dialog dengan jumlah sukses dan daftar error per baris.
- ✅ Semua aksi import/export tercatat di Audit Trail.

## File Terkait

- `lib/services/import_export_service.dart`
- `lib/screens/products_screen.dart`
- `lib/screens/suppliers_screen.dart`
