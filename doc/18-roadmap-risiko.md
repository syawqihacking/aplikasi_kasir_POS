# 18 — Roadmap & Risiko

## Referensi PRD: Bagian 4, 5, 6, 7, 8

---

## Roadmap Pengembangan (Bertahap)

### Fase 1 — MVP (Wajib untuk rilis awal)

| Fitur | Status |
|---|---|
| Login & Hak Akses dasar | ✅ Selesai |
| Master Produk | ✅ Selesai |
| Kategori | ✅ Selesai |
| Supplier | ✅ Selesai |
| Transaksi Penjualan (single payment) | ✅ Selesai |
| Barang Masuk/Keluar | ✅ Selesai |
| Cetak Struk | ✅ Selesai |
| Dashboard dasar | ✅ Selesai |
| Backup manual | ✅ Selesai |

### Fase 2 — Operasional Lengkap

| Fitur | Status |
|---|---|
| Manajemen Kas/Shift | ✅ Selesai |
| Split Payment | ✅ Selesai |
| Retur & Void dengan approval | ✅ Selesai |
| Stock Opname | ✅ Selesai |
| Laporan lengkap + export Excel/PDF | ✅ Selesai |
| Log Aktivitas / Audit Trail | ✅ Selesai |

### Fase 3 — Penyempurnaan

| Fitur | Status |
|---|---|
| Barcode Management (generate & cetak label) | ✅ Selesai |
| Notifikasi sistem | ✅ Selesai |
| Import/Export Excel | ✅ Selesai |
| Backup otomatis terjadwal | ✅ Selesai |
| Dark Mode, Shortcut Keyboard | ✅ Selesai |

### Fase 4 — Nilai Tambah / Future-proofing

| Fitur | Status |
|---|---|
| Tier Pricing, Riwayat Harga | ✅ Parsial (Riwayat Harga selesai) |
| Favorit/Fast Button | ✅ Selesai |
| Multi Printer, Touch Mode | ❌ Belum |
| Database Maintenance (VACUUM otomatis) | ✅ Selesai |
| Kesiapan sinkronisasi online | ❌ Belum |

---

## Fitur Nilai Tambah (Direkomendasikan)

| Fitur | Alasan | Status |
|---|---|---|
| Undo Transaksi Terakhir | Cegah human error saat scan salah | ❌ Belum |
| Favorit/Fast Button | Percepat transaksi produk terlaris | ✅ Selesai |
| Riwayat Perubahan Harga | Transparansi & audit | ✅ Selesai |
| Audit Trail Lengkap | Akuntabilitas penuh | ✅ Selesai |
| Multi Printer | Future-proof untuk F&B | ❌ Belum |
| Touch Mode | Antisipasi monitor sentuh | ❌ Belum |
| Database Maintenance | VACUUM berkala untuk performa stabil | ✅ Selesai |
| Manajemen Kas/Shift | Kontrol kas fisik vs sistem | ✅ Selesai |
| Void dengan Approval PIN | Cegah penyalahgunaan | ✅ Selesai |
| Split Payment | Cash + non-cash | ✅ Selesai |
| Tier Pricing | Grosir & eceran | ❌ Belum |

---

## Non-Functional Requirements

| Kategori | Requirement | Status |
|---|---|---|
| Performa | Pencarian produk < 500ms; transaksi < 1 detik | ✅ Terpenuhi |
| Reliabilitas | Tidak ada data hilang saat crash (SQLite transaction) | ✅ Terpenuhi |
| Keamanan | Password di-hash, PIN admin terpisah | ✅ Terpenuhi (Password hash sudah ada) |
| Usability | Kasir baru bisa dilatih < 15 menit | ✅ Terpenuhi |
| Portabilitas | Instalasi via installer `.exe` | ❌ Belum |
| Maintainability | Skema DB terversi (migration script) | ✅ Terpenuhi (v1–v7) |
| Skalabilitas Data | Multi-tahun tanpa penurunan performa | ⚠️ Belum diuji |
| Recoverability | Restore dari backup < 5 menit | ✅ Terpenuhi (backup sudah ada) |

---

## Risiko & Mitigasi

| Risiko | Mitigasi | Status Mitigasi |
|---|---|---|
| Data korup akibat crash saat transaksi | SQLite transaction (atomic) | ✅ Sudah diterapkan |
| Kehilangan data (PC rusak tanpa backup) | Reminder backup + backup otomatis | ✅ Parsial (Backup manual via GUI ada) |
| Kasir menyalahgunakan diskon/void | PIN otorisasi admin + audit log | ✅ Selesai |
| Database membengkak setelah bertahun-tahun | VACUUM berkala + arsipkan data lama | ✅ Parsial (VACUUM berkala selesai) |
| Scanner tidak terbaca / salah konfigurasi | Halaman pengaturan scanner + fallback manual | ⚠️ Parsial (fallback ada) |

---

## Ringkasan Progres Keseluruhan

| Fase | Target | Selesai | Progres |
|---|---|---|---|
| Fase 1 (MVP) | 9 fitur | 9 fitur | 100% |
| Fase 2 (Operasional) | 6 fitur | 6 fitur | 100% |
| Fase 3 (Penyempurnaan) | 5 fitur | 5 fitur | 100% |
| Fase 4 (Nilai Tambah) | 5 fitur | 3 fitur | 60% |
| **Total** | **25 fitur** | **23 fitur** | **92%** |

> **Catatan:** Sebagian besar fitur inti dan fungsionalitas pendukung (UX, import/export, audit trail, shift kasir, backup) sudah terintegrasi dan beroperasi stabil. Tahap pengembangan selanjutnya lebih difokuskan pada skenario khusus (multi-printer, split payment, dan notifikasi).
