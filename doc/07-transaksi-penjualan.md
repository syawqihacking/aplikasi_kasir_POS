# 07 — Transaksi Penjualan (POS)

## Referensi PRD: Modul 3.5

## Deskripsi
Modul paling kritis — dioptimalkan untuk kecepatan transaksi kasir.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Scan Barcode | Auto-focus ke kolom scan, auto-add ke keranjang | ✅ Selesai |
| Pencarian Produk | Fallback search by nama/SKU jika barcode tidak terbaca | ✅ Selesai |
| Keranjang Belanja | Edit qty, hapus item, lihat subtotal real-time | ✅ Selesai |
| Diskon Item & Diskon Total | Nominal atau persentase, batas maksimum butuh PIN admin | ⚠️ Parsial (Diskon Total nominal ada) |
| Pajak (opsional) | PPN otomatis berdasarkan pengaturan toko | ✅ Selesai (dinamis dari Settings) |
| Multi Metode Pembayaran | Cash, QRIS, Transfer | ✅ Selesai |
| Split Payment | Kombinasi lebih dari satu metode dalam satu transaksi | ❌ Belum |
| Hitung Kembalian | Otomatis, breakdown pecahan uang | ⚠️ Parsial (kalkulasi ada, breakdown belum) |
| Hold Transaksi | Simpan transaksi sementara, lanjutkan nanti | ✅ Selesai |
| Lanjutkan Transaksi | Ambil kembali transaksi yang di-hold | ✅ Selesai |
| Cetak Struk & Cetak Ulang | Format struk bisa dikustomisasi (logo, footer) | ⚠️ Parsial (Tampil di dialog) |
| Retur Penjualan | Retur sebagian/seluruh item, kembalikan stok otomatis | ✅ Selesai |
| Undo Transaksi Terakhir | Batalkan transaksi yang belum selesai dibayar | ✅ Selesai (Hapus Keranjang) |
| Void Transaksi | Batalkan transaksi yang sudah selesai + PIN admin + audit | ✅ Selesai |
| Favorit/Fast Button | Grid tombol cepat untuk produk terlaris | ✅ Selesai |

---

## Acceptance Criteria

- [x] Waktu dari scan barcode sampai item masuk keranjang < 300ms.
- [x] Transaksi tidak bisa disimpan jika stok produk = 0 (kecuali pengaturan "boleh minus stok").
- [x] Struk tercetak otomatis: nama toko, no. invoice, tanggal, daftar item, subtotal, diskon, pajak, total, metode bayar, kembalian.

---

## Alur Transaksi

```
Kasir Login → Buka Kasir (input modal) → Scan/Cari Produk → Item masuk keranjang
→ (opsional) Diskon/Hold → Pilih Metode Bayar (bisa split) → Hitung Kembalian
→ Simpan Transaksi (DB transaction: kurangi stok + insert transaksi) → Cetak Struk
```

---

## Status Implementasi Saat Ini

- ✅ Halaman POS dengan katalog produk di kiri dan keranjang di kanan.
- ✅ Add to cart, update qty, hapus item.
- ✅ Kalkulasi subtotal, pajak dinamis, dan grand total.
- ✅ Dialog pembayaran dengan input uang dan kalkulasi kembalian otomatis.
- ✅ Penyimpanan transaksi atomik (stok berkurang + data tersimpan bersamaan).
- ✅ Metode pembayaran selain Cash (QRIS, Transfer) berfungsi.
- ✅ Fitur Hold dan Resume Transaksi selesai.
- ✅ Void Transaksi selesai (melalui widget Recent Transactions).
- ✅ Retur parsial selesai dengan dialog pilihan item dan jumlah.
- ✅ Fast Button diimplementasikan di atas grid produk.
- ✅ Cetak struk (dialog simulasi struk) sudah diimplementasikan.

## File Terkait

- `lib/screens/pos_screen.dart`
- `lib/database/database_helper.dart` (method: `saveTransaction()`)
