# 10 — Supplier & Kategori

## Referensi PRD: Modul 3.11 & 3.12

---

## 10.1 Supplier (PRD 3.11)

## Deskripsi
Pengelolaan data supplier/pemasok barang.

| Fitur | Detail | Status |
|---|---|---|
| CRUD Supplier | Tambah, edit, hapus data supplier | ✅ Selesai |
| Field: Nama, No. Telp, Alamat, Email | Data kontak supplier | ✅ Selesai |
| Riwayat Pembelian per Supplier | Evaluasi supplier (opsional) | ❌ Belum |

### Status
- ✅ Tabel `suppliers` sudah dibuat di database.
- ✅ Halaman Supplier tersedia di menu Master Data.

---

## 10.2 Kategori Produk (PRD 3.12)

## Deskripsi
Pengelolaan kategori produk (CRUD sederhana).

| Fitur | Detail | Status |
|---|---|---|
| Tambah Kategori | Input nama dan deskripsi | ✅ Selesai |
| Edit Kategori | Ubah nama/deskripsi | ✅ Selesai |
| Hapus Kategori | Hapus kategori (dengan validasi referensi produk) | ✅ Selesai |
| Tampilkan di Dropdown | Saat tambah/edit produk | ✅ Selesai |

### Status
- ✅ Tabel `categories` sudah ada di database.
- ✅ Data seed kategori (Food, Beverages, Electronics, Clothing) tersedia.
- ✅ Halaman khusus untuk manajemen kategori tersedia di menu Master Data.
- ✅ Dropdown kategori di form produk sudah ada.

## File Terkait

- `lib/database/database_helper.dart` (tabel `categories`)
