# Fitur Shift POS

## 1. Buka Shift

Digunakan untuk memulai shift kasir.

Fitur:

* Pilih kasir
* Input modal/kas awal
* Waktu mulai otomatis
* Tombol Mulai Shift

## 2. Shift Aktif

Menampilkan informasi shift yang sedang berjalan.

Informasi:

* Nama kasir
* Nomor shift
* Waktu mulai
* Modal awal
* Status shift

Aksi:

* Cash In
* Cash Out
* Tutup Shift

## 3. Tutup Shift

Digunakan untuk mengakhiri shift kasir.

Fitur:

* Menampilkan kas yang seharusnya
* Input kas aktual
* Menghitung selisih kas
* Input catatan penutupan
* Konfirmasi tutup shift
* Waktu selesai otomatis

## 4. Riwayat Shift

Digunakan untuk melihat seluruh shift yang pernah dilakukan.

Informasi:

* Nomor shift
* Nama kasir
* Tanggal
* Waktu mulai
* Waktu selesai
* Modal awal
* Status shift

## 5. Cash In

Digunakan untuk menambahkan uang ke kas selama shift.

Contoh:

* Tambahan modal
* Penambahan uang kas

Data:

* Jumlah
* Alasan
* Waktu
* Kasir

## 6. Cash Out

Digunakan untuk mengeluarkan uang dari kas selama shift.

Contoh:

* Pengeluaran operasional
* Pengambilan uang oleh owner
* Pembelian kebutuhan toko

Data:

* Jumlah
* Alasan
* Waktu
* Kasir

## 7. Detail Shift

Digunakan untuk melihat informasi lengkap dari satu shift.

Informasi:

* Nomor shift
* Kasir
* Waktu mulai
* Waktu selesai
* Modal awal
* Cash In
* Cash Out
* Kas yang seharusnya
* Kas aktual
* Selisih
* Catatan
* Status

## Alur Shift

```text
Buka Shift
     ↓
Shift Aktif
     ↓
Cash In / Cash Out
     ↓
Tutup Shift
     ↓
Shift Selesai
     ↓
Riwayat Shift
```

## Fitur Wajib

Untuk POS sederhana, fitur yang wajib dibuat:

1. Buka Shift
2. Shift Aktif
3. Tutup Shift
4. Riwayat Shift

Cash In, Cash Out, dan Detail Shift dapat menjadi fitur tambahan.

struktur shiftnya 
SHIFT
│
├── Buka Shift
├── Shift Aktif
│   ├── Cash In
│   ├── Cash Out
│   └── Tutup Shift
│
├── Detail Shift
└── Riwayat Shift