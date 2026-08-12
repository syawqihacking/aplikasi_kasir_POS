# 09 — Manajemen Stok

## Referensi PRD: Modul 3.7 – 3.10

## Deskripsi
Pengelolaan stok barang secara menyeluruh, meliputi barang masuk (restock), barang keluar, stock opname, dan riwayat perubahan stok.

---

## 9.1 Barang Masuk (PRD 3.7)

| Fitur | Detail | Status |
|---|---|---|
| Input Barang Masuk | Scan barcode, pilih produk, input qty, harga beli, no. invoice | ✅ Selesai |
| Update Stok Otomatis | Stok di `products.current_stock` bertambah secara atomik | ✅ Selesai |
| Histori Barang Masuk | Tercatat di tabel `stock_in` | ✅ Selesai |
| Input Supplier | Pilih supplier saat input barang masuk | ✅ Selesai |

### Alur Barang Masuk

```
Staff Login → Pilih Supplier → Scan/Input Produk → Input Qty & Harga Beli
→ Input No. Invoice → Simpan → Stok bertambah otomatis → Tercatat di stock_history
```

---

## 9.2 Barang Keluar (PRD 3.8)

| Fitur | Detail | Status |
|---|---|---|
| Barang Rusak | Catat stok keluar dengan alasan "damaged" | ✅ Selesai |
| Barang Hilang | Catat stok keluar dengan alasan "lost" | ✅ Selesai |
| Pemakaian Internal | Catat stok keluar dengan alasan "internal_use" | ✅ Selesai |
| Retur Supplier | Catat stok keluar dengan alasan "supplier_return" | ✅ Selesai |
| Koreksi Stok | Catat stok keluar dengan alasan "adjustment" | ✅ Selesai |
| Wajib Alasan & User | Semua wajib notes dan tercatat siapa yang input | ✅ Selesai |

---

## 9.3 Stock Opname (PRD 3.9)

| Fitur | Detail | Status |
|---|---|---|
| Hitung Stok Fisik vs Sistem | Input jumlah fisik, selisih dihitung otomatis | ✅ Selesai |
| Penyesuaian Manual | Approve manual (bukan auto-apply) | ✅ Selesai |
| Riwayat Opname | Per periode | ✅ Selesai |

---

## 9.4 Riwayat Stok (PRD 3.10)

| Fitur | Detail | Status |
|---|---|---|
| Log Lengkap | Barang masuk, keluar, siapa, kapan, keterangan | ✅ Selesai |
| Filter | By produk, tanggal, jenis perubahan | ⚠️ Parsial |

---

## Status Implementasi Saat Ini

- ✅ Tabel `stock_in` sudah ada di database.
- ✅ Halaman `InventoryScreen` untuk restock dengan form input.
- ✅ Method `restockProduct()` yang menambah stok secara atomik (transaction).
- ✅ Tabel `stock_out` sudah dibuat.
- ✅ Tabel `stock_opname` sudah dibuat.
- ✅ Tabel `stock_history` sudah dibuat.
- ✅ Halaman Manajemen Stok sekarang menggunakan interface tab untuk Barang Masuk, Barang Keluar, Stock Opname, dan Riwayat Stok.

## File Terkait

- `lib/screens/inventory_screen.dart` (termasuk komponen tab di dalamnya)
- `lib/database/database_helper.dart` (method: `restockProduct()`, `stockOut()`, `saveStockOpname()`, `getStockHistory()`)
