# 01 — Arsitektur & Database

## Tech Stack

| Layer | Teknologi |
|---|---|
| UI/Frontend | Flutter Desktop (Windows/Linux) |
| State Management | StatefulWidget (lokal state) |
| Database Lokal | SQLite (`sqflite_common_ffi` untuk desktop) |
| Query Layer | Raw SQL dengan helper class (`DatabaseHelper`) |
| Printer | Package ESC/POS (`esc_pos_printer`, `esc_pos_utils`) |
| Barcode Scanner | Input via keyboard wedge (`HardwareKeyboard` listener) |
| Barcode Generator | `barcode` / `barcode_widget` package |
| Export Excel | `excel` package |
| Export PDF | `pdf` + `printing` package |
| Backup File | Native file copy + kompresi (`archive` package) |
| Local Auth/PIN | Hashing dengan `bcrypt`/`crypto` |

---

## Prinsip Arsitektur

1. **Offline-first mutlak** — seluruh fitur inti berjalan tanpa internet.
2. **Single source of truth** — SQLite lokal sebagai satu-satunya sumber data.
3. **Transactional integrity** — semua operasi multi-tabel dibungkus dalam SQLite transaction.
4. **Audit-first design** — tabel penting punya kolom `created_by`, `created_at`, `updated_by`, `updated_at`.
5. **Separation of concern** — pemisahan layer UI, business logic, dan data access.
6. **Context-aware input** — scanner fisik melayani banyak fungsi berdasarkan konteks halaman aktif.

---

## Skema Database (Ringkasan Tabel Inti)

```
users              (id, username, password_hash, role, full_name, is_active, created_at)
roles_permissions  (id, role, module, can_view, can_create, can_edit, can_delete)
categories         (id, name, description)
suppliers          (id, name, phone, address, email)

products           (id, barcode, sku, name, category_id, unit, cost_price, sell_price,
                    min_stock, current_stock, rack_location, photo_path, is_active,
                    created_by, created_at, updated_by, updated_at)
price_history      (id, product_id, old_price, new_price, changed_by, changed_at)

transactions       (id, invoice_no, cashier_id, customer_id, subtotal, discount_total,
                    tax_total, grand_total, paid_amount, change_amount, payment_method,
                    status, shift_id, created_at)
transaction_items  (id, transaction_id, product_id, qty, unit_price, discount, subtotal)
transaction_payments (id, transaction_id, method, amount)
returns            (id, transaction_id, reason, refund_amount, approved_by, created_at)
return_items       (id, return_id, product_id, qty)

stock_in           (id, product_id, supplier_id, qty, cost_price, invoice_no, received_at, created_by)
stock_out          (id, product_id, qty, reason, notes, created_by, created_at)
stock_opname       (id, opname_date, product_id, system_qty, physical_qty, difference, adjusted, created_by)
stock_history      (id, product_id, change_type, qty_change, reference_id, changed_by, changed_at, notes)

cash_shifts        (id, cashier_id, opening_balance, closing_balance_system,
                    closing_balance_physical, difference, opened_at, closed_at, status)
cash_movements     (id, shift_id, type, amount, reason, created_by, created_at)

activity_logs      (id, user_id, action, module, description, device_info, created_at)
settings           (key, value)
```

---

## Status Implementasi

| Item | Status |
|---|---|
| SQLite dengan `sqflite_common_ffi` | ✅ Selesai |
| Singleton `DatabaseHelper` | ✅ Selesai |
| Migrasi database terversi (v1–v8) | ✅ Selesai |
| Tabel `users` | ✅ Selesai |
| Tabel `categories` | ✅ Selesai |
| Tabel `products` | ✅ Selesai |
| Tabel `transactions` + `transaction_items` | ✅ Selesai |
| Tabel `stock_in` | ✅ Selesai |
| Tabel `cash_shifts` | ✅ Selesai |
| Tabel `settings` | ✅ Selesai |
| Tabel `roles_permissions` | ✅ Selesai |
| Tabel `suppliers` | ✅ Selesai |
| Tabel `price_history` | ✅ Selesai |
| Tabel `transaction_payments` (split payment) | ✅ Selesai |
| Tabel `returns` + `return_items` | ✅ Selesai |
| Tabel `stock_out` | ✅ Selesai |
| Tabel `stock_opname` | ✅ Selesai |
| Tabel `stock_history` | ✅ Selesai |
| Tabel `cash_movements` | ✅ Selesai |
| Tabel `activity_logs` | ✅ Selesai |
