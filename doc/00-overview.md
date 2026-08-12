# Ringkasan Proyek — Aplikasi Kasir Desktop (POS System)

## Informasi Umum

| | |
|---|---|
| **Platform** | Desktop (Windows / Linux) |
| **Framework** | Flutter Desktop |
| **Database** | SQLite (Offline-first) |
| **Versi Dokumen** | 1.0 |
| **Tanggal** | Juli 2026 |

---

## Deskripsi Produk

Aplikasi kasir (Point of Sale) berbasis desktop yang berjalan **offline penuh** menggunakan database lokal SQLite, ditujukan untuk toko retail (sembako, elektronik, apotek, dsb.) yang membutuhkan sistem transaksi cepat, manajemen stok akurat, dan pelaporan yang andal tanpa ketergantungan koneksi internet.

## Tujuan Produk

1. Mempercepat proses transaksi kasir dengan dukungan barcode scanner.
2. Mengurangi kesalahan pencatatan stok manual.
3. Menyediakan laporan penjualan & keuangan yang akurat dan real-time.
4. Menjamin akuntabilitas melalui sistem hak akses dan audit trail.
5. Tetap dapat beroperasi penuh tanpa internet (offline-first).

## Target Pengguna

| Role | Deskripsi |
|---|---|
| **Admin/Owner** | Kontrol penuh: master data, laporan, pengaturan, user management |
| **Kasir** | Akses terbatas: transaksi penjualan, retur (dengan approval), lihat stok |
| **Gudang/Staff (opsional)** | Barang masuk/keluar, stock opname |

## Perangkat Pendukung

- **Scanner**: Zebra DS2208 / Honeywell Voyager XP 1470G (mode keyboard wedge / USB HID)
- **Printer**: Thermal ESC/POS (58mm/80mm, via USB/Serial)
- **OS**: Windows 10/11 (64-bit) / Linux

---

## Daftar Modul

| No | Modul | Dokumen |
|---|---|---|
| 1 | Arsitektur & Database | [01-arsitektur-database.md](01-arsitektur-database.md) |
| 2 | Login & Hak Akses | [02-login-hak-akses.md](02-login-hak-akses.md) |
| 3 | Dashboard | [03-dashboard.md](03-dashboard.md) |
| 4 | Master Produk | [04-master-produk.md](04-master-produk.md) |
| 5 | Barcode Management | [05-barcode-management.md](05-barcode-management.md) |
| 6 | Smart Context-Aware Scanner | [06-smart-scanner.md](06-smart-scanner.md) |
| 7 | Transaksi Penjualan (POS) | [07-transaksi-penjualan.md](07-transaksi-penjualan.md) |
| 8 | Manajemen Kas / Shift | [08-manajemen-kas-shift.md](08-manajemen-kas-shift.md) |
| 9 | Manajemen Stok | [09-manajemen-stok.md](09-manajemen-stok.md) |
| 10 | Supplier & Kategori | [10-supplier-kategori.md](10-supplier-kategori.md) |
| 11 | Laporan | [11-laporan.md](11-laporan.md) |
| 12 | Backup & Restore | [12-backup-restore.md](12-backup-restore.md) |
| 13 | Pengaturan | [13-pengaturan.md](13-pengaturan.md) |
| 14 | Notifikasi | [14-notifikasi.md](14-notifikasi.md) |
| 15 | Audit Trail | [15-audit-trail.md](15-audit-trail.md) |
| 16 | Import & Export Data | [16-import-export.md](16-import-export.md) |
| 17 | Fitur Pendukung | [17-fitur-pendukung.md](17-fitur-pendukung.md) |
| 18 | Roadmap & Risiko | [18-roadmap-risiko.md](18-roadmap-risiko.md) |

---

## Status Pengembangan

> Lihat masing-masing dokumen modul untuk status progres per fitur.
