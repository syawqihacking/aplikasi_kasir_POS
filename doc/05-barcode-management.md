# 05 — Barcode Management

## Referensi PRD: Modul 3.4

## Deskripsi
Manajemen barcode produk, termasuk scan, generate, cetak label, dan registrasi produk baru.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Scan Barcode | Input dari scanner (keyboard wedge) langsung ke field pencarian | ✅ Selesai |
| Generate Barcode | Auto-generate kode internal (EAN-13 custom prefix) untuk produk tanpa barcode | ✅ Selesai |
| Cetak Label Barcode | Print ke printer label/thermal, template ukuran bisa disesuaikan | ✅ Selesai |
| Status Produk Tanpa Barcode | Ditandai di list produk + notifikasi dashboard | ✅ Selesai |
| Tombol "Daftarkan Barcode" | Shortcut cepat dari halaman produk atau saat scan gagal | ✅ Selesai |

---

## Acceptance Criteria

- [x] Scanner keyboard wedge langsung memproses barcode di halaman POS.
- [x] Produk tanpa barcode ditandai secara visual di daftar produk.
- [x] Barcode bisa di-generate otomatis dan dicetak ke printer label.

---

## Status Implementasi Saat Ini

- ✅ Scanner listener global (`ScannerService`) sudah aktif.
- ✅ Barcode scanner bisa menambahkan produk ke keranjang POS.
- ✅ Barcode bisa di-generate otomatis menggunakan algoritma checksum EAN-13 (ikon auto-generate di AddProductDialog).
- ✅ Produk tanpa barcode memiliki badge warning merah "No Barcode" di `ProductsScreen`.
- ✅ Label barcode bisa dicetak dalam bentuk PDF dengan ukuran kertas stiker (50x30 mm) dari `ProductsScreen`.
- ✅ Tombol "Daftarkan Barcode" akan muncul ketika kasir menscan barcode tak dikenal di POS, dan akan langsung mengisi input form barcode produk baru.

## File Terkait

- `lib/services/scanner_service.dart`
- `lib/screens/pos_screen.dart`
- `lib/screens/products_screen.dart`
- `lib/screens/widgets/add_product_dialog.dart`
- `lib/screens/widgets/print_barcode_dialog.dart`
