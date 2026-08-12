# 13 — Pengaturan

## Referensi PRD: Modul 3.15

## Deskripsi
Konfigurasi sistem dan profil toko yang bisa diubah oleh admin.

---

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Profil Toko | Nama toko, alamat, no. telp | ✅ Selesai |
| Logo Toko | Untuk struk & laporan | ✅ Selesai |
| Printer Default | Pilih printer struk & label | ✅ Selesai |
| Pajak | Persentase pajak, aktif/nonaktif | ✅ Selesai |
| Mata Uang & Format Tanggal | Konfigurasi locale | ❌ Belum (hardcoded id_ID) |
| Pengaturan Scanner | Mode input, delay threshold | ✅ Selesai |
| Batas Diskon Tanpa Approval | Maksimum diskon yang boleh tanpa PIN admin | ✅ Selesai |
| Kebijakan Stok Minus | Boleh/tidak boleh transaksi jika stok = 0 | ✅ Selesai |

---

## Status Implementasi Saat Ini

- ✅ Tabel `settings` sudah ada di database (key-value pair).
- ✅ Halaman `SettingsScreen` dengan form profil toko dan persentase pajak.
- ✅ Perubahan pajak langsung berlaku di halaman POS secara dinamis.
- ✅ Upload logo toko diimplementasikan (mengkopi gambar ke `DashDock_Assets` lokal).
- ✅ Konfigurasi printer mendeteksi list printer lokal via package `printing`.
- ✅ Pengaturan scanner (delay), batas diskon, dan saklar stok minus sudah ditambahkan.

## File Terkait

- `lib/screens/settings_screen.dart`
- `lib/database/database_helper.dart` (methods: `getSettings()`, `saveSetting()`)
