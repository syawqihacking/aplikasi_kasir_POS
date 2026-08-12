# Product Requirements Document (PRD)
# Aplikasi Kasir Desktop (POS System)

| | |
|---|---|
| **Nama Produk** | (isi nama aplikasi) |
| **Platform** | Windows Desktop |
| **Framework** | Flutter Desktop |
| **Database** | SQLite (Offline-first) |
| **Versi Dokumen** | 1.0 |
| **Tanggal** | Juli 2026 |
| **Status** | Draft |

---

## 1. Ringkasan Produk (Executive Summary)

Aplikasi kasir (Point of Sale) berbasis desktop yang berjalan **offline penuh** menggunakan database lokal SQLite, ditujukan untuk toko retail (sembako, elektronik, apotek, dsb.) yang membutuhkan sistem transaksi cepat, manajemen stok akurat, dan pelaporan yang andal tanpa ketergantungan koneksi internet.

### 1.1 Tujuan Produk
- Mempercepat proses transaksi kasir dengan dukungan barcode scanner.
- Mengurangi kesalahan pencatatan stok manual.
- Menyediakan laporan penjualan & keuangan yang akurat dan real-time.
- Menjamin akuntabilitas melalui sistem hak akses dan audit trail.
- Tetap dapat beroperasi penuh tanpa internet (offline-first).

### 1.2 Target Pengguna
| Role | Deskripsi |
|---|---|
| **Admin/Owner** | Kontrol penuh: master data, laporan, pengaturan, user management |
| **Kasir** | Akses terbatas: transaksi penjualan, retur (dengan approval), lihat stok |
| **Gudang/Staff (opsional)** | Barang masuk/keluar, stock opname |

### 1.3 Perangkat Pendukung
- **Scanner**: Zebra DS2208 / Honeywell Voyager XP 1470G (mode keyboard wedge / USB HID)
- **Printer**: Thermal ESC/POS (58mm/80mm, via USB/Serial)
- **OS**: Windows 10/11 (64-bit)

---

## 2. Arsitektur Sistem

### 2.1 Tech Stack
| Layer | Teknologi |
|---|---|
| UI/Frontend | Flutter Desktop (Windows) |
| State Management | Provider / Riverpod / Bloc (pilih salah satu, konsisten) |
| Database Lokal | SQLite (`sqflite_common_ffi` untuk desktop) |
| ORM/Query Layer | Drift (recommended) atau raw SQL dengan helper class |
| Printer | Package ESC/POS (`esc_pos_printer`, `esc_pos_utils`) |
| Barcode Scanner | Input via keyboard wedge (RawKeyboard listener), bukan library kamera |
| Global Scanner Service | Listener tunggal di root aplikasi (`HardwareKeyboard`/`KeyboardListener`) + context registry untuk mode scan otomatis (lihat 3.4.1) |
| Barcode Generator | `barcode` / `barcode_widget` package |
| Export Excel | `excel` package |
| Export PDF | `pdf` + `printing` package |
| Backup File | Native file copy + kompresi (`archive` package) |
| Local Auth/PIN | Hashing dengan `bcrypt`/`crypto` |

### 2.2 Prinsip Arsitektur
1. **Offline-first mutlak** — seluruh fitur inti harus berjalan tanpa internet.
2. **Single source of truth** — SQLite lokal sebagai satu-satunya sumber data (tidak ada dual-write ke cloud pada MVP).
3. **Transactional integrity** — semua operasi yang mengubah stok (penjualan, retur, barang masuk/keluar, stock opname) wajib dibungkus dalam SQLite transaction agar tidak ada data korup saat aplikasi crash di tengah proses.
4. **Audit-first design** — setiap tabel penting punya kolom `created_by`, `created_at`, `updated_by`, `updated_at`.
5. **Separation of concern** — layer UI, business logic (services/use case), dan data access (repository) dipisah agar mudah di-maintain dan di-test.
6. **Context-aware input** — satu scanner fisik melayani banyak fungsi; software yang menentukan perilaku scan berdasarkan halaman/mode yang sedang aktif, bukan hardware yang berganti mode (lihat 3.4.1).

### 2.3 Skema Database (Ringkasan Tabel Inti)

```
users (id, username, password_hash, role, full_name, is_active, created_at)
roles_permissions (id, role, module, can_view, can_create, can_edit, can_delete)
products (id, barcode, sku, name, category_id, unit, cost_price, sell_price,
          min_stock, current_stock, rack_location, photo_path, is_active,
          created_by, created_at, updated_by, updated_at)
categories (id, name, description)
suppliers (id, name, phone, address, email)
price_history (id, product_id, old_price, new_price, changed_by, changed_at)

transactions (id, invoice_no, cashier_id, customer_id?, subtotal, discount_total,
              tax_total, grand_total, paid_amount, change_amount, payment_method,
              status[completed/held/voided], shift_id, created_at)
transaction_items (id, transaction_id, product_id, qty, unit_price, discount, subtotal)
transaction_payments (id, transaction_id, method, amount)   -- untuk split payment
returns (id, transaction_id, reason, refund_amount, approved_by, created_at)
return_items (id, return_id, product_id, qty)

stock_in (id, product_id, supplier_id, qty, cost_price, invoice_no, received_at, created_by)
stock_out (id, product_id, qty, reason[damaged/lost/internal_use/supplier_return/adjustment],
           notes, created_by, created_at)
stock_opname (id, opname_date, product_id, system_qty, physical_qty, difference,
              adjusted, created_by)
stock_history (id, product_id, change_type, qty_change, reference_id, changed_by, changed_at, notes)

cash_shifts (id, cashier_id, opening_balance, closing_balance_system,
             closing_balance_physical, difference, opened_at, closed_at, status)
cash_movements (id, shift_id, type[in/out], amount, reason, created_by, created_at)

activity_logs (id, user_id, action, module, description, ip/device_info, created_at)
settings (key, value)
```

---

## 3. Modul & Fitur Detail

### 3.1 Login & Hak Akses
**Deskripsi:** Sistem autentikasi lokal berbasis username/password dengan role-based access control (RBAC).

| Fitur | Detail |
|---|---|
| Login Admin/Kasir | Autentikasi lokal, password di-hash (bcrypt), session timeout otomatis |
| Manajemen User | CRUD user, reset password, nonaktifkan user (bukan hapus permanen) |
| Role & Permission | Matrix permission per modul (View/Create/Edit/Delete) yang bisa dikustomisasi per role |
| **PIN Otorisasi** | PIN terpisah untuk aksi sensitif: void transaksi, diskon di atas batas, hapus produk, edit harga langsung di kasir |
| Lock Screen | Auto-lock setelah idle X menit, butuh re-login untuk lanjut |

**Acceptance Criteria:**
- Password salah 5x → akun terkunci sementara (lockout 5 menit).
- Kasir tidak bisa mengakses menu Laporan Keuntungan & Pengaturan.
- Setiap perubahan role langsung berlaku tanpa perlu restart aplikasi.

---

### 3.2 Dashboard
Ringkasan informasi real-time saat aplikasi dibuka:
- Total Produk, Kategori, Supplier
- Penjualan & Pendapatan Hari Ini
- Produk Stok Menipis (di bawah `min_stock`)
- Produk Tanpa Barcode
- Grafik Penjualan (harian/mingguan, line/bar chart)
- 10 Transaksi Terakhir
- **[Tambahan]** Status Shift Kasir Aktif (siapa yang sedang login, sudah buka kasir atau belum)
- **[Tambahan]** Ringkasan kas hari ini (jika shift aktif)

---

### 3.3 Master Produk
| Fitur | Detail |
|---|---|
| Tambah/Edit/Hapus Produk | Hapus bersifat **soft-delete** (nonaktifkan) agar histori transaksi lama tidak rusak referensinya |
| Upload Foto Produk | Simpan path lokal, thumbnail otomatis untuk performa |
| Barcode, Nama, SKU, Kategori, Satuan | Field wajib |
| Harga Beli & Harga Jual | Validasi harga jual ≥ harga beli (warning, bukan blocking) |
| Minimum Stok | Trigger notifikasi stok menipis |
| Lokasi Rak (opsional) | Free text atau kode rak |
| Status Aktif/Nonaktif | Produk nonaktif tidak muncul di pencarian transaksi |
| **[Tambahan] Tier Pricing** | Harga bertingkat berdasarkan qty (misal >12 pcs = harga grosir) |
| **[Tambahan] Riwayat Perubahan Harga** | Log siapa mengubah harga, dari berapa ke berapa, kapan (tabel `price_history`) |

---

### 3.4 Barcode Management
| Fitur | Detail |
|---|---|
| Scan Barcode | Input dari scanner (keyboard wedge) langsung ke field pencarian |
| Generate Barcode | Auto-generate kode internal (format: `EAN-13` custom prefix) untuk produk tanpa barcode dari pabrik |
| Cetak Label Barcode | Print ke printer label/thermal, template ukuran bisa disesuaikan |
| Status & Peringatan Produk Tanpa Barcode | Ditandai di list produk + notifikasi dashboard |
| Tombol "Daftarkan Barcode" | Shortcut cepat dari halaman produk atau dari transaksi (saat scan gagal ketemu) |

---

### 3.4.1 Smart Context-Aware Scanner **(Fitur Tambahan — Unggulan)**

**Deskripsi:** Satu unit scanner fisik (Zebra DS2208 / Honeywell Voyager) melayani seluruh aplikasi, tetapi hasil scan diarahkan secara otomatis oleh software sesuai konteks layar yang sedang aktif — tanpa kasir/staff perlu mengganti mode secara manual.

**Prinsip kerja:**
Scanner secara hardware selalu berfungsi sebagai keyboard wedge (mengirim karakter + Enter). Yang membedakan perilakunya adalah **listener global di level aplikasi** yang mengecek "halaman apa yang sedang aktif" sebelum memutuskan mau diapakan hasil scan tersebut.

| Konteks Layar Aktif | Perilaku Scan Otomatis |
|---|---|
| Form Tambah/Edit Produk terbuka | Barcode mengisi field "Barcode" pada form (mode registrasi produk) |
| Halaman Barang Masuk terbuka | Barcode mencari produk & mengisi baris input barang masuk |
| Halaman Barang Keluar / Stock Opname terbuka | Barcode mencari produk & mengisi baris input sesuai konteks (rusak/hilang/opname) |
| **Semua layar lain (default/idle)** | Barcode dianggap **penjualan** → cari produk → otomatis masuk ke Keranjang Belanja transaksi aktif |

**Komponen teknis:**
1. **Global Scanner Listener** — satu `KeyboardListener`/`HardwareKeyboard` handler terpasang di root widget tree (bukan per-halaman), aktif selamanya selama aplikasi berjalan.
2. **Scan Detection (bukan ketikan manual)** — bedakan input scanner vs ketikan manual berdasarkan kecepatan antar-karakter (scanner umumnya <30–50ms/karakter, diakhiri Enter/Tab). Jika jeda antar-karakter melebihi threshold, input diabaikan oleh listener global (dianggap ketikan biasa di field lain, mencegah bentrok).
3. **Context Registry (Scanner Mode Stack)** — setiap halaman yang punya kebutuhan scan mendaftarkan dirinya sebagai "active scan context" saat dibuka (`onMount`) dan melepas diri saat ditutup (`onDispose`). Scanner service selalu merujuk ke context teratas dalam stack untuk menentukan aksi.
4. **Fallback: Produk Tidak Ditemukan** — jika barcode di-scan dalam mode default (penjualan) tapi produk belum terdaftar di database, tampilkan dialog cepat: *"Produk tidak ditemukan — daftarkan sekarang?"* → langsung membuka form Tambah Produk dengan field barcode sudah terisi otomatis.
5. **Global Mini-Cart Persistence** — keranjang belanja transaksi aktif tetap tersimpan di state global (bukan state lokal halaman), sehingga jika kasir sempat berpindah layar sebentar (misal cek stok), item yang sudah di-scan tidak hilang.
6. **Indikator Mode Aktif (UX)** — tampilkan badge kecil di pojok layar (misal "Mode: Penjualan" / "Mode: Input Produk") supaya kasir/staff selalu tahu ke mana hasil scan berikutnya akan diarahkan, mengurangi kebingungan.

**Acceptance Criteria:**
- Scan barcode di halaman manapun selain form input produk/barang masuk/opname → otomatis tercatat sebagai penjualan dan masuk keranjang dalam < 300ms.
- Scan barcode saat form Tambah Produk terbuka → tidak pernah tercatat sebagai transaksi penjualan, murni mengisi field barcode.
- Berpindah halaman tidak menghapus isi keranjang transaksi yang sedang berjalan.
- Ketikan manual pengguna di kolom pencarian/nama produk tidak pernah salah terpicu sebagai hasil scan.

---

### 3.5 Transaksi Penjualan
Modul paling kritis — harus dioptimalkan untuk kecepatan.

| Fitur | Detail |
|---|---|
| Scan Barcode | Auto-focus ke kolom scan setiap saat, auto-add ke keranjang |
| Pencarian Produk | Fallback jika barcode tidak terbaca (search by nama/SKU) |
| Keranjang Belanja | Edit qty, hapus item, lihat subtotal real-time |
| Diskon Item & Diskon Total | Nominal atau persentase, dengan batas maksimum yang butuh PIN admin jika dilampaui |
| Pajak (opsional) | PPN otomatis berdasarkan pengaturan toko |
| **Multi Metode Pembayaran** | Cash, QRIS, Transfer |
| **[Tambahan] Split Payment** | Kombinasi lebih dari satu metode dalam satu transaksi (misal cash + QRIS) |
| Hitung Kembalian | Otomatis, dengan **[Tambahan] breakdown pecahan uang** untuk membantu kasir |
| Hold Transaksi | Simpan transaksi sementara (misal pelanggan lupa bawa uang), lanjutkan nanti |
| Lanjutkan Transaksi | Ambil kembali transaksi yang di-hold |
| Cetak Struk & Cetak Ulang Struk | Format struk bisa dikustomisasi (logo, footer promosi) |
| Retur Penjualan | Retur sebagian/seluruh item, kembalikan stok otomatis, butuh alasan |
| **[Tambahan] Undo Transaksi Terakhir** | Batalkan transaksi yang *belum* selesai dibayar/dicetak (beda dari void) |
| **[Tambahan] Void Transaksi** | Batalkan transaksi yang *sudah selesai*, wajib PIN admin + alasan wajib diisi, tercatat di audit trail |
| **[Tambahan] Favorit/Fast Button** | Grid tombol cepat untuk produk terlaris, kustomisasi per kasir |

**Acceptance Criteria:**
- Waktu dari scan barcode sampai item masuk keranjang < 300ms.
- Transaksi tidak bisa disimpan jika stok produk = 0 (kecuali diizinkan lewat pengaturan "boleh minus stok").
- Struk tercetak otomatis mengandung: nama toko, no. invoice, tanggal, daftar item, subtotal, diskon, pajak, total, metode bayar, kembalian.

---

### 3.6 Manajemen Kas / Shift **(Modul Tambahan — Direkomendasikan Wajib)**
| Fitur | Detail |
|---|---|
| Buka Kasir | Input modal awal sebelum kasir bisa mulai transaksi |
| Tutup Kasir | Rekonsiliasi: total sistem vs total fisik dihitung kasir, selisih otomatis tercatat |
| Setoran/Penarikan Kas | Pencatatan uang masuk/keluar dari laci selama shift (misal ambil uang untuk kembalian dari kasir lain) |
| Laporan per Shift | Rekap penjualan, kas masuk/keluar, selisih per shift per kasir |

---

### 3.7 Barang Masuk
- Scan Barcode, Input Supplier, Harga Beli, Jumlah, Tanggal, No. Invoice
- Update stok otomatis ke `products.current_stock`
- Tercatat di `stock_history`

### 3.8 Barang Keluar
- Barang Rusak, Barang Hilang, Pemakaian Internal, Retur Supplier, Koreksi Stok
- Semua wajib alasan (notes) dan tercatat siapa yang input

### 3.9 Stock Opname
- Hitung stok fisik vs sistem
- Selisih otomatis dihitung, penyesuaian bisa manual approve (bukan langsung auto-apply, untuk mencegah kesalahan input massal)
- Riwayat opname per periode

### 3.10 Riwayat Stok
- Log lengkap: barang masuk, keluar, siapa, kapan, keterangan
- Filter by produk, tanggal, jenis perubahan

### 3.11 Supplier
- CRUD: Nama, No. Telp, Alamat, Email
- **[Tambahan]** Riwayat pembelian per supplier (opsional, untuk evaluasi supplier)

### 3.12 Kategori Produk
- CRUD sederhana (Tambah/Edit/Hapus)

---

### 3.13 Laporan
| Laporan | Detail |
|---|---|
| Penjualan Harian/Bulanan/Tahunan | Filter rentang tanggal custom |
| Laporan Keuntungan | Selisih harga jual vs harga beli, per produk/kategori/periode |
| Barang Terlaris & Tidak Laku | Ranking berdasarkan qty terjual dalam periode |
| Laporan Barang Masuk/Keluar | Rekap per supplier/per alasan |
| Laporan Stok | Snapshot stok saat ini + nilai stok (qty × harga beli) |
| **[Tambahan] Laporan per Shift/Kasir** | Evaluasi performa & kejujuran kasir |
| Export Excel & PDF | Semua laporan bisa diekspor |
| Print Laporan | Cetak langsung ke printer biasa (bukan thermal) |

---

### 3.14 Backup & Restore
| Fitur | Detail |
|---|---|
| Backup Database | Export file `.db`/`.zip` ke lokasi pilihan (termasuk flashdisk/HDD eksternal) |
| Restore Database | Import kembali dengan validasi integritas file sebelum overwrite |
| Backup Otomatis | Terjadwal (harian/mingguan), simpan N backup terakhir (rolling backup) |
| **[Tambahan]** Notifikasi jika backup terakhir sudah lebih dari X hari |

---

### 3.15 Pengaturan
- Profil Toko (nama, alamat, no. telp)
- Logo Toko (untuk struk & laporan)
- Printer Default (struk & label)
- Pajak (persentase, aktif/nonaktif)
- Mata Uang & Format Tanggal
- Pengaturan Scanner (mode input, delay)
- **[Tambahan]** Batas maksimum diskon tanpa approval
- **[Tambahan]** Kebijakan stok minus (boleh/tidak boleh transaksi jika stok 0)

### 3.16 Notifikasi
- Stok Hampir Habis
- Produk Tanpa Barcode
- Backup Belum Dilakukan
- Barang Kadaluarsa (jika diperlukan — butuh field `expiry_date` opsional di produk)
- **[Tambahan]** Shift belum ditutup di akhir hari

### 3.17 Log Aktivitas / Audit Trail
Semua aksi penting tercatat: Login/Logout, Edit/Hapus Produk, Retur, Void Transaksi, Stock Opname, Backup Database, Perubahan Harga, Perubahan Permission.

**Format log:** `[Timestamp] [User] [Aksi] [Modul] [Detail perubahan: before → after]`

### 3.18 Import & Export
- Import/Export Produk via Excel (dengan template standar + validasi baris error sebelum commit)
- Import/Export Supplier

### 3.19 Fitur Pendukung
- Shortcut Keyboard (F1-F12 untuk aksi cepat di kasir: bayar, hold, batal, cari produk)
- Auto Focus ke Kolom Scan
- Dark Mode / Light Mode
- Auto Save (draft transaksi)
- Auto Refresh Data
- Pencarian Cepat & Filter/Sorting Produk

### 3.20 Fitur Khusus Offline
- Database SQLite Lokal penuh
- Semua transaksi tanpa internet
- Sinkronisasi Manual (opsional, untuk pengembangan online di masa depan — desain skema DB sudah harus siap untuk future sync, misal pakai UUID bukan auto-increment id agar tidak konflik saat sync nanti)
- Backup ke Flashdisk/Harddisk

---

## 4. Fitur Nilai Tambah (Direkomendasikan)

| Fitur | Alasan |
|---|---|
| Undo Transaksi Terakhir | Cegah human error saat scan salah sebelum transaksi selesai |
| Favorit/Fast Button | Percepat transaksi untuk produk yang sering dijual (warung/minimarket) |
| Riwayat Perubahan Harga | Transparansi & audit — siapa ubah harga, kapan |
| Audit Trail Lengkap | Akuntabilitas penuh semua aktivitas user |
| Multi Printer | Struk + printer dapur (future-proof jika berkembang ke F&B) |
| Touch Mode | Antisipasi jika nanti pakai monitor sentuh |
| Database Maintenance | VACUUM SQLite berkala agar performa stabil dalam jangka panjang |
| **Manajemen Kas/Shift** | Kontrol kas fisik vs sistem — sangat sering jadi sumber masalah di lapangan |
| **Void dengan Approval PIN** | Cegah penyalahgunaan pembatalan transaksi oleh kasir |
| **Split Payment** | Realita pembayaran pelanggan sering campur cash+non-cash |
| **Tier Pricing** | Dibutuhkan toko dengan pembeli grosir & eceran |

---

## 5. Non-Functional Requirements

| Kategori | Requirement |
|---|---|
| **Performa** | Pencarian produk dari 10.000+ item < 500ms; transaksi tersimpan < 1 detik |
| **Reliabilitas** | Tidak boleh ada data hilang jika aplikasi crash saat transaksi (gunakan DB transaction) |
| **Keamanan** | Password di-hash, PIN admin terpisah, tidak ada akses langsung edit database dari luar aplikasi |
| **Usability** | Kasir baru bisa dilatih operasional dasar < 15 menit |
| **Portabilitas** | Instalasi via installer `.exe`, tidak butuh instalasi runtime tambahan yang rumit |
| **Maintainability** | Skema DB terversi (migration script), kode terstruktur per layer |
| **Skalabilitas Data** | Mampu menangani histori transaksi multi-tahun tanpa penurunan performa signifikan (index yang tepat di kolom tanggal, barcode, foreign key) |
| **Recoverability** | Restore dari backup < 5 menit tanpa kehilangan data setelah titik backup |

---

## 6. Alur Kerja Utama (User Flow Ringkas)

### 6.1 Alur Transaksi Penjualan
```
Kasir Login → Buka Kasir (input modal) → Scan/Cari Produk → Item masuk keranjang
→ (opsional) Diskon/Hold → Pilih Metode Bayar (bisa split) → Hitung Kembalian
→ Simpan Transaksi (DB transaction: kurangi stok + insert transaksi) → Cetak Struk
```

### 6.2 Alur Barang Masuk
```
Staff Login → Pilih Supplier → Scan/Input Produk → Input Qty & Harga Beli
→ Input No. Invoice → Simpan → Stok bertambah otomatis → Tercatat di stock_history
```

### 6.3 Alur Tutup Kasir
```
Kasir pilih "Tutup Kasir" → Sistem hitung total penjualan cash otomatis
→ Kasir input jumlah fisik uang di laci → Sistem tampilkan selisih
→ Kasir/Admin konfirmasi → Shift ditutup, laporan shift ter-generate
```

---

## 7. Roadmap Pengembangan (Bertahap)

### Fase 1 — MVP (Wajib untuk rilis awal)
- Login & Hak Akses dasar
- Master Produk, Kategori, Supplier
- Transaksi Penjualan (single payment dulu)
- Barang Masuk/Keluar
- Cetak Struk
- Dashboard dasar
- Backup manual

### Fase 2 — Operasional Lengkap
- Manajemen Kas/Shift
- Split Payment
- Retur & Void dengan approval
- Stock Opname
- Laporan lengkap + export Excel/PDF
- Log Aktivitas / Audit Trail

### Fase 3 — Penyempurnaan
- Barcode Management (generate & cetak label)
- Notifikasi sistem
- Import/Export Excel
- Backup otomatis terjadwal
- Dark Mode, Shortcut Keyboard

### Fase 4 — Nilai Tambah / Future-proofing
- Tier Pricing, Riwayat Harga
- Favorit/Fast Button
- Multi Printer, Touch Mode
- Database Maintenance (VACUUM otomatis)
- Kesiapan sinkronisasi online (opsional)

---

## 8. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Data korup akibat crash saat transaksi | Gunakan SQLite transaction (atomic) untuk setiap operasi multi-tabel |
| Kehilangan data karena laptop/PC rusak tanpa backup | Wajibkan reminder backup + backup otomatis terjadwal |
| Kasir menyalahgunakan diskon/void | PIN otorisasi admin untuk aksi sensitif + audit log |
| Database membengkak setelah bertahun-tahun | VACUUM berkala + arsipkan data transaksi lama (>2 tahun) ke file terpisah |
| Scanner tidak terbaca / salah konfigurasi | Halaman pengaturan scanner + fallback pencarian manual selalu tersedia |

---

## 9. Lampiran: Daftar Singkatan
- **PRD** — Product Requirements Document
- **POS** — Point of Sale
- **RBAC** — Role-Based Access Control
- **ESC/POS** — Standar perintah printer thermal
- **SKU** — Stock Keeping Unit
- **UUID** — Universally Unique Identifier

---

*Dokumen ini adalah dokumen hidup (living document) dan dapat diperbarui seiring pengembangan aplikasi berlangsung.*
