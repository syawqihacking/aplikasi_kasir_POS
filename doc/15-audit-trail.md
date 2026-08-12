# 15 — Audit Trail / Log Aktivitas

## Referensi PRD: Modul 3.17

## Deskripsi
Pencatatan semua aksi penting di dalam sistem untuk akuntabilitas dan keamanan.

---

## Aksi yang Dicatat

| Aksi | Detail | Status |
|---|---|---|
| Login / Logout | Catat siapa login/logout dan kapan | ✅ Selesai |
| Edit / Hapus Produk | Before → After, siapa, kapan | ✅ Selesai |
| Retur Penjualan | Detail retur + approval | ✅ Selesai |
| Void Transaksi | Alasan wajib + PIN admin | ✅ Selesai |
| Stock Opname | Selisih + penyesuaian | ✅ Selesai |
| Backup Database | Catat kapan backup dilakukan | ✅ Selesai |
| Perubahan Harga | Old price → New price | ✅ Selesai |
| Perubahan Permission | Perubahan role/akses | ✅ Selesai |

---

## Format Log

```
[Timestamp] [User] [Aksi] [Modul] [Detail perubahan: before → after]
```

---

## Status Implementasi Saat Ini

- ✅ Tabel `activity_logs` sudah dibuat di database.
- ✅ Implementasi logging diseluruh aksi utama sudah selesai.
- ✅ Halaman `AuditTrailScreen` sudah dibuat (termasuk filter rentang tanggal).

## File Terkait

- `lib/database/database_helper.dart`
- `lib/screens/audit_trail_screen.dart`
- `lib/screens/widgets/sidebar.dart`
- `lib/screens/widgets/add_product_dialog.dart`
- `lib/screens/widgets/recent_transactions.dart`
- `lib/screens/inventory/stock_opname_tab.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/backup_restore_screen.dart`
