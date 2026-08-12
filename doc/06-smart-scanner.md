# 06 — Smart Context-Aware Scanner

## Referensi PRD: Modul 3.4.1 (Fitur Unggulan)

## Deskripsi
Satu unit scanner fisik melayani seluruh aplikasi. Hasil scan diarahkan secara otomatis oleh software sesuai konteks layar yang sedang aktif — tanpa pengguna perlu mengganti mode secara manual.

---

## Perilaku Berdasarkan Konteks

| Konteks Layar Aktif | Perilaku Scan Otomatis | Status |
|---|---|---|
| Form Tambah/Edit Produk | Barcode mengisi field "Barcode" pada form (mode registrasi) | ✅ Selesai |
| Halaman Barang Masuk | Barcode mencari produk & mengisi baris input barang masuk | ❌ Belum (menunggu UI InventoryScreen) |
| Halaman Barang Keluar / Stock Opname | Barcode mencari produk & mengisi baris input sesuai konteks | ❌ Belum (menunggu UI InventoryScreen) |
| **Semua layar lain (default)** | Barcode = penjualan → cari produk → masuk keranjang | ✅ Selesai |

---

## Komponen Teknis

| Komponen | Detail | Status |
|---|---|---|
| Global Scanner Listener | Satu `HardwareKeyboard` handler di root widget tree | ✅ Selesai |
| Scan Detection | Bedakan input scanner vs ketikan manual (threshold kecepatan < 30-50ms) | ✅ Selesai |
| Context Registry (Scanner Mode Stack) | Halaman mendaftarkan diri sebagai "active scan context" | ✅ Selesai |
| Fallback: Produk Tidak Ditemukan | Dialog "Daftarkan sekarang?" saat scan gagal di mode penjualan | ✅ Selesai |
| Global Mini-Cart Persistence | Keranjang tersimpan di state global (tidak hilang saat pindah halaman) | ✅ Selesai |
| Indikator Mode Aktif (UX) | Badge "Mode: Penjualan" / "Mode: Input Produk" di pojok layar | ✅ Selesai |

---

## Acceptance Criteria

- [x] Scan barcode di halaman default → masuk keranjang dalam < 300ms.
- [x] Scan barcode saat form Tambah Produk → tidak tercatat sebagai penjualan.
- [x] Berpindah halaman tidak menghapus isi keranjang transaksi.
- [x] Ketikan manual di kolom pencarian tidak salah terpicu sebagai scan.

---

## File Terkait

- `lib/services/scanner_service.dart`
- `lib/main.dart` (listener dipasang di root)
