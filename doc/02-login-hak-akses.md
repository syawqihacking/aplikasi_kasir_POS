# 02 — Login & Hak Akses

## Referensi PRD: Modul 3.1

## Deskripsi
Sistem autentikasi lokal berbasis username/password dengan role-based access control (RBAC).

---

## Fitur Detail

## Fitur Detail

| Fitur | Detail | Status |
|---|---|---|
| Login Admin/Kasir | Autentikasi lokal, password di-hash (crypto sha256), session timeout otomatis | ✅ Selesai |
| Manajemen User | CRUD user, reset password, nonaktifkan user (bukan hapus permanen) | ✅ Selesai |
| Role & Permission | Matrix permission per modul (View/Create/Edit/Delete) per role | ✅ Selesai |
| PIN Otorisasi | PIN terpisah untuk aksi sensitif: void transaksi, diskon di atas batas, hapus produk | ❌ Belum |
| Lock Screen | Auto-lock setelah idle X menit, butuh re-login | ✅ Selesai |

---

## Acceptance Criteria

- [x] Password salah 5x → akun terkunci sementara (lockout 5 menit).
- [x] Kasir tidak bisa mengakses menu Laporan Keuntungan & Pengaturan.
- [x] Setiap perubahan role langsung berlaku tanpa perlu restart aplikasi.

---

## Status Implementasi Saat Ini

- ✅ Tabel `users` sudah ada di database.
- ✅ `LoginScreen` sebagai entry point aplikasi.
- ✅ Default user tersedia (`admin`/`admin123` dan `kasir`/`kasir123`).
- ✅ Password di-hash dengan crypto sha256.
- ✅ Pembatasan akses menu menggunakan `AuthService` dan matrix tabel `roles_permissions`.
- ✅ Fitur manajemen user (CRUD) via `UsersScreen`.
- ❌ Belum ada PIN otorisasi (Akan diurus di modul transaksi).
- ✅ Lock screen / session timeout 10 menit idle (via `Listener` di `MainLayout`).

## File Terkait

- `lib/screens/login_screen.dart`
- `lib/database/database_helper.dart` (method: `login()`)
