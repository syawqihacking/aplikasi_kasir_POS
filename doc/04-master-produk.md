# 04 — Master Produk

## Referensi PRD: Modul 3.3

## Deskripsi
Pengelolaan data produk yang dijual di toko, termasuk harga, stok, kategori, dan foto.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Tambah Produk | Form input produk dengan validasi field wajib | ✅ Selesai |
| Edit Produk | Ubah data produk yang sudah ada | ✅ Selesai |
| Hapus Produk (Soft-delete) | Nonaktifkan produk (`is_active = 0`), bukan hapus permanen | ✅ Selesai |
| Upload Foto Produk | Simpan path lokal, preview di form | ✅ Selesai |
| Barcode, Nama, SKU, Kategori, Satuan | Field wajib saat input produk | ✅ Selesai |
| Harga Beli & Harga Jual | Validasi harga jual ≥ harga beli (warning) | ✅ Selesai |
| Minimum Stok | Trigger notifikasi stok menipis (icon warning di tabel) | ✅ Selesai |
| Lokasi Rak (opsional) | Free text atau kode rak | ✅ Selesai |
| Status Aktif/Nonaktif | Produk nonaktif tidak muncul di pencarian transaksi, bisa di-filter | ✅ Selesai |
| Tier Pricing | Harga bertingkat berdasarkan qty (grosir) | ❌ Belum (fitur lanjutan) |
| Riwayat Perubahan Harga | Log perubahan harga (`price_history`) | ✅ Selesai |

---

## Acceptance Criteria

- [x] Produk bisa ditambah, diedit, dan dinonaktifkan.
- [x] Produk nonaktif tidak muncul di halaman POS.
- [x] Validasi: harga jual < harga beli menampilkan warning.
- [x] Riwayat perubahan harga tercatat di tabel `price_history`.

---

## Status Implementasi Saat Ini

- ✅ Tabel `products`, `categories`, dan `price_history` sudah terintegrasi.
- ✅ Halaman `ProductsScreen` menampilkan daftar lengkap (termasuk produk nonaktif).
- ✅ Pencarian produk berdasarkan nama, barcode, dan SKU.
- ✅ Filter berdasarkan kategori dan status aktif/nonaktif.
- ✅ Dialog Add/Edit produk dengan semua field (cost price, sell price, unit, min stock, rack, photo).
- ✅ Soft-delete dengan konfirmasi + reactivation.
- ✅ Price warning muncul jika sell price < cost price.
- ✅ Riwayat harga bisa dilihat dengan klik icon di kolom Sell Price.
- ✅ Indikator low-stock (icon warning) di kolom Stock.
- ❌ Tier pricing (harga grosir bertingkat) belum diimplementasikan.

## File Terkait

- `lib/screens/products_screen.dart`
- `lib/screens/widgets/add_product_dialog.dart`
- `lib/database/database_helper.dart` (methods: `insertProduct()`, `updateProduct()`, `softDeleteProduct()`, `reactivateProduct()`, `logPriceChange()`, `getPriceHistory()`, `getAllProductsIncludingInactive()`)
