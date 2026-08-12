# Spec: Fitur "Smart Assistant" (Chatbot Offline Rule-Based)
**Aplikasi:** DashDock (POS/Kasir)
**Target platform:** Flutter/Dart (sesuaikan dengan arsitektur project DashDock yang sudah ada)
**Tujuan dokumen:** Menjadi acuan presisi bagi AI/dev untuk mengimplementasikan fitur Smart Assistant tanpa ambiguitas.

---

## 0. ATURAN WAJIB (JANGAN DILANGGAR)

1. **100% offline.** Tidak boleh ada network call, tidak boleh memanggil API AI (OpenAI, Gemini, Groq, dll), tidak boleh memanggil layanan cloud apa pun.
2. **Rule-based, bukan generative.** Semua respons berasal dari template teks + data database lokal. Tidak ada LLM di-runtime.
3. **Sumber data hanya dari database lokal** yang sudah dipakai DashDock (produk, transaksi, kategori, supplier, shift, dll). Jangan buat sumber data baru yang terpisah/duplikat.
4. **Tidak boleh mengubah skema database inti** yang sudah ada. Jika perlu tabel baru (misal log percakapan), buat tabel terpisah, additive, tidak breaking.
5. Semua string yang tampil ke user harus Bahasa Indonesia (ikuti bahasa dominan di modul Laporan Bisnis/Manajemen Stok yang sudah ada), kecuali label kode/variabel.

---

## 1. Arsitektur

Buat modul terpisah bernama `smart_assistant` (folder `lib/features/smart_assistant/`) dengan struktur berikut:

```
lib/features/smart_assistant/
├── data/
│   └── assistant_repository.dart      # Query ke database lokal (read-only)
├── domain/
│   ├── intent.dart                    # Enum/class daftar Intent
│   ├── intent_matcher.dart            # Logika pencocokan keyword -> Intent
│   └── command_handler.dart           # Eksekusi Intent -> ambil data -> format respons
├── presentation/
│   ├── chat_screen.dart               # UI utama chat
│   ├── widgets/
│   │   ├── chat_bubble.dart
│   │   ├── quick_action_bar.dart
│   │   └── report_card.dart           # Kartu hasil ringkasan/laporan di dalam chat
│   └── chat_controller.dart           # State management (sesuaikan: Provider/Riverpod/Bloc — ikuti yang dipakai project existing)
└── models/
    ├── chat_message.dart
    └── assistant_response.dart
```

Alur eksekusi wajib mengikuti pipeline berikut, urutan tidak boleh diubah:

```
User Input (teks/tap quick action)
   -> IntentMatcher.match(input)        // cocokkan ke salah satu Intent terdaftar
   -> jika tidak match -> FallbackResponse
   -> jika match -> CommandHandler.execute(intent, params)
   -> CommandHandler ambil data dari AssistantRepository (query lokal)
   -> Format ke AssistantResponse (teks + optional widget: tabel/chart/tombol aksi)
   -> Tampilkan sebagai ChatBubble di ChatScreen
```

---

## 2. Model Data Wajib

### `ChatMessage`
```dart
class ChatMessage {
  final String id;
  final String text;
  final bool isFromUser;
  final DateTime timestamp;
  final AssistantResponse? response; // null jika pesan dari user
}
```

### `AssistantResponse`
```dart
class AssistantResponse {
  final String summaryText;           // teks jawaban utama
  final ResponseType type;            // enum: text, table, chart, actionButtons, fileDownload
  final Map<String, dynamic>? payload; // data pendukung (list produk, angka, dsb)
}

enum ResponseType { text, table, chart, actionButtons, fileDownload }
```

### `Intent` (daftar lengkap — WAJIB semua ada, jangan dikurangi)

| Intent enum | Contoh trigger keyword (case-insensitive, partial match) | Sumber data |
|---|---|---|
| `salesToday` | "penjualan hari ini", "omzet hari ini" | tabel transactions, filter tanggal = today |
| `salesByPeriod` | "penjualan bulan ini", "penjualan minggu ini", "laporan penjualan" | transactions, filter by date range parsed dari kata "hari ini/minggu ini/bulan ini/tahun ini" |
| `expenseToday` | "pengeluaran hari ini" | tabel expenses/cash_out, filter today |
| `expenseByPeriod` | "pengeluaran bulan ini", "pengeluaran minggu ini" | expenses, filter date range |
| `profitToday` | "laba hari ini", "untung hari ini", "keuntungan hari ini" | (harga jual - harga beli) * qty terjual, filter today |
| `stockCheck` | "stok [nama produk]", "cek stok" | products, match nama produk (fuzzy/substring) |
| `lowStockProducts` | "stok menipis", "barang hampir habis" | products where stok <= threshold |
| `bestSellingProducts` | "produk terlaris", "barang terlaris" | agregasi qty terjual dari transaction_items, order desc |
| `slowMovingProducts` | "produk tidak laku", "barang tidak laku" | products yang tidak muncul di transaction_items dalam periode X hari |
| `transactionSearch` | "cari transaksi INV-xxxx", "transaksi [nama pelanggan]", "transaksi tanggal [tanggal]" | transactions, match invoice_no / customer_name / date |
| `customerInfo` | "data pelanggan [nama]", "riwayat pembelian [nama]" | customers + transactions join |
| `topCustomers` | "pelanggan paling sering belanja", "pelanggan terbaik" | agregasi total transaksi per customer, order desc |
| `businessStats` | "statistik bisnis", "rata-rata transaksi", "pertumbuhan penjualan" | agregasi transactions (avg, growth % vs periode sebelumnya) |
| `salesTrend` | "tren penjualan", "grafik penjualan" | transactions grouped by day/week/month -> return payload untuk chart |
| `generateReport` | "buat laporan [jenis] [periode]", "rekap penjualan harian/bulanan", "rekap stok", "rekap pengeluaran" | routing ke report generator sesuai jenis |
| `downloadReport` | "download laporan", "unduh sebagai pdf/excel/csv" | ambil report terakhir yang di-generate di sesi ini -> export file |
| `printReport` | "cetak laporan", "print laporan" | kirim ke print service/plugin cetak yang sudah ada di app |
| `navigate` | "buka [nama halaman]" (dashboard, produk, penjualan, pengeluaran, pengaturan) | trigger navigator.pushNamed sesuai mapping halaman |
| `fallback` | tidak cocok dengan intent manapun | tampilkan pesan default + saran quick action |

---

## 3. Intent Matching — Logika Presisi

**Wajib pakai pendekatan berlapis, bukan hanya `contains()` polos:**

1. **Normalisasi input**: lowercase, trim, hapus tanda baca berlebih.
2. **Deteksi periode waktu** (dipakai lintas intent): buat helper `DateRangeParser` yang mengenali kata kunci berikut dan mengembalikan `DateTimeRange`:
   - "hari ini" → today 00:00–23:59
   - "kemarin" → yesterday
   - "minggu ini" → Senin–Minggu minggu berjalan
   - "bulan ini" → tanggal 1 s/d akhir bulan berjalan
   - "tahun ini" → 1 Jan s/d 31 Des tahun berjalan
   - Jika tidak ada kata kunci periode → default ke "hari ini"
3. **Deteksi entity** (nama produk / nama pelanggan / no invoice): ekstrak substring setelah keyword pemicu (contoh: setelah kata "stok " ambil sisanya sebagai nama produk untuk query `LIKE %query%`).
4. **Prioritas matching**: jika input cocok dengan lebih dari satu intent (misal mengandung kata "penjualan" dan "stok" sekaligus), pilih intent dengan jumlah keyword exact-match terbanyak. Jika tetap seri, minta klarifikasi ke user (jangan menebak).
5. **Tidak ada fuzzy typo-correction di versi awal** (out of scope) — cukup exact/substring match. Boleh ditambahkan levenshtein distance di iterasi berikutnya sebagai enhancement opsional, bukan wajib di versi pertama.

---

## 4. Floating Chat Button (Entry Point)

Chatbot **tidak berupa halaman/menu terpisah di sidebar**, melainkan widget mengambang (floating) yang selalu bisa diakses dari halaman mana pun di dalam aplikasi.

**Spesifikasi perilaku:**

- **Posisi:** pojok kanan bawah layar (`bottom: 24, right: 24` atau setara), konsisten di semua halaman (Dashboard, POS, Products, Transactions, dll).
- **Komponen:** `FloatingActionButton` (atau custom container) berbentuk lingkaran/pill, warna ungu sesuai brand color DashDock, dengan icon chat/asisten (misal `Icons.support_agent` atau `Icons.chat_bubble_outline`).
- **Z-index/layer:** harus selalu berada di layer paling atas (di atas konten halaman), tidak boleh tertutup elemen lain, tapi juga tidak boleh menutupi tombol aksi penting yang sudah ada di pojok kanan bawah pada halaman tertentu (misal tombol "Pay Now" di POS) — cek dan sesuaikan posisi/offset per halaman jika ada konflik.
- **Interaksi tap:**
  - Jika chat window tertutup → tap membuka chat window (animasi expand dari tombol, bukan pindah halaman baru / route baru).
  - Jika chat window terbuka → icon berubah jadi tombol close (X) di posisi yang sama, tap untuk menutup.
- **Badge notifikasi (opsional, jika relevan):** bisa menampilkan badge kecil saat ada "Action Needed" penting (misal stok menipis) yang belum dilihat user, mengambil data dari sumber yang sama dengan card "Action Needed" di Dashboard. Ini opsional, bukan wajib di versi pertama.
- **Chat window saat terbuka:**
  - Muncul sebagai panel/card mengambang di atas konten halaman (bukan full-screen page), ukuran kira-kira 380–420px lebar x 500–600px tinggi di desktop/tablet; di layar mobile sempit bisa full-height dari bawah (bottom sheet style).
  - Posisi panel: menempel di pojok kanan bawah, tepat di atas tombol floating.
  - Header panel berisi: judul "Smart Assistant", tombol minimize/close.
  - Body panel: history chat (scrollable).
  - Footer panel: Quick Action Bar (lihat Section 5) + input text field + tombol kirim.
  - State chat (riwayat pesan dalam sesi) **tetap tersimpan** selama app tidak di-restart, walau user pindah halaman lalu buka lagi widget-nya (gunakan state management level aplikasi/root, bukan state lokal per halaman).
- **Tidak boleh mengganggu navigasi utama** — pastikan floating button tidak overlap dengan bottom navigation bar (jika ada versi mobile dengan bottom nav).

---

## 5. Quick Action Bar (UI)

Tampilkan sebagai row scrollable horizontal di atas chat input, berisi tombol berikut (urutan tetap):

1. Penjualan Hari Ini
2. Pengeluaran Hari Ini
3. Laporan Penjualan
4. Stok Barang
5. Produk Terlaris
6. Laba Hari Ini
7. Riwayat Transaksi
8. Data Pelanggan

Setiap tombol saat di-tap = mengirim pesan user otomatis dengan teks yang sama persis dengan intent trigger di tabel Section 2, lalu diproses lewat pipeline yang sama seperti input manual (tidak boleh ada jalur pintas berbeda — supaya konsisten dan mudah ditest).

---

## 6. Format Respons per Jenis Intent

- **Ringkasan angka (salesToday, profitToday, expenseToday, dll)** → `ResponseType.text` dengan format:
  ```
  📊 Penjualan Hari Ini ([tanggal])
  Total Transaksi: X
  Total Penjualan: RpXXX.XXX
  Diskon: RpXXX
  Pajak: RpXXX
  Pendapatan Bersih: RpXXX.XXX
  ```
- **List data (produk terlaris, stok menipis, dsb)** → `ResponseType.table`, payload berupa `List<Map<String,dynamic>>`, render sebagai tabel ringkas max 10 baris + teks "lihat semua di menu [X]" jika data lebih banyak.
- **Tren penjualan** → `ResponseType.chart`, payload berupa list `{date, total}` untuk dirender pakai `fl_chart` (LineChart/BarChart, ikuti style chart yang sudah dipakai di halaman Dashboard).
- **generateReport / downloadReport** → `ResponseType.fileDownload`, payload berisi path file sementara + tombol aksi "Download PDF / Excel / CSV".
- **navigate** → `ResponseType.actionButtons` dengan satu tombol "Buka Halaman [X]" yang saat ditekan memanggil navigator.

---

## 7. Generate & Export Laporan

Gunakan package berikut (sesuaikan versi dengan pubspec project):
- PDF: `pdf` + `printing` (untuk export & preview cetak)
- Excel: `excel`
- CSV: `csv`

Alur `generateReport`:
1. Tentukan jenis laporan dari kata kunci (penjualan/pengeluaran/stok/produk terlaris).
2. Tentukan periode dari `DateRangeParser`.
3. Query data dari repository terkait (jangan buat query baru yang beda hasil dari halaman Laporan Bisnis yang sudah ada — reuse service/query yang sama agar angka konsisten).
4. Simpan hasil generate sementara di state controller (`lastGeneratedReport`) supaya intent `downloadReport`/`printReport` berikutnya bisa langsung dipakai tanpa generate ulang.
5. Render `ResponseType.fileDownload` dengan 3 tombol format (PDF/Excel/CSV).

Alur `printReport`:
- Reuse service print yang sudah dipakai di modul lain (jika DashDock sudah punya print struk/laporan, panggil service yang sama — jangan implementasi print baru dari nol).

---

## 8. Navigasi

Mapping kata kunci → route (sesuaikan nama route dengan yang sudah ada di `main.dart`/router DashDock):

| Kata kunci | Route |
|---|---|
| "buka dashboard" | `/dashboard` |
| "buka penjualan" / "buka kasir" / "buka pos" | `/pos` |
| "buka produk" | `/products` |
| "buka pengeluaran" | (sesuaikan jika modul expense terpisah dari transactions) |
| "buka pengaturan" | `/settings` |
| "buka laporan" | `/reports` |
| "buka stok" / "buka inventory" | `/inventory` |

Jika kata kunci tidak dikenali persis tapi mengandung "buka", tampilkan list halaman yang tersedia sebagai `actionButtons` daripada menebak.

---

## 9. Fallback & Empty State

Jika tidak ada intent yang cocok:
```
Maaf, saya belum mengerti maksud Anda 🙏
Coba salah satu perintah berikut:
[Quick Action Bar ditampilkan ulang]
```

Jika intent cocok tapi hasil query kosong (misal stok produk tidak ditemukan):
```
Produk "[query]" tidak ditemukan. Periksa kembali nama produk atau cek di menu Products.
```

---

## 10. Non-Goals (Eksplisit di luar scope versi ini)

- Tidak ada voice input/output.
- Tidak ada multi-turn context memory (setiap pesan diproses independen, tidak ada "ingat pertanyaan sebelumnya").
- Tidak ada personalisasi per user/role di versi pertama (semua role admin melihat data yang sama).
- Tidak ada koneksi ke AI generatif apa pun, walau hanya sebagai fallback.

---

## 11. Checklist Definition of Done

- [ ] Semua 18 Intent di Section 2 terimplementasi dan bisa ditrigger baik lewat quick action maupun teks manual.
- [ ] Tidak ada import package network (http, dio, dsb) di dalam folder `smart_assistant/`.
- [ ] Semua angka yang ditampilkan di chat sama persis dengan angka di halaman Dashboard/Laporan Bisnis untuk periode yang sama (cross-check manual).
- [ ] Export PDF/Excel/CSV bisa dibuka dan datanya sesuai dengan yang ditampilkan di chat.
- [ ] Fallback response muncul untuk input acak/tidak dikenali.
- [ ] UI chat konsisten dengan design system DashDock (warna ungu, font, spacing) yang sudah dipakai di halaman lain.
- [ ] Tidak ada crash saat database kosong (misal belum ada transaksi sama sekali).
- [ ] Floating button muncul konsisten di semua halaman, tidak overlap dengan tombol aksi penting lain (cek khusus halaman POS/Kasir).
- [ ] Riwayat chat tetap tersimpan saat user pindah halaman selama sesi aplikasi berjalan.

---

## Instruksi untuk AI/Developer yang Mengerjakan

Ikuti dokumen ini sebagai kontrak fitur. Jika ada bagian yang ambigu terhadap struktur project DashDock yang sebenarnya (nama tabel, nama route, package state management yang dipakai), **tanyakan dulu sebelum berasumsi**, jangan membuat struktur baru yang menyimpang dari project yang sudah ada. Prioritaskan reuse repository/query/service yang sudah ada di modul Dashboard, Laporan Bisnis, Products, dan Transactions — jangan duplikasi logika query.
