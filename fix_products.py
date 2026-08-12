import sys

with open("lib/screens/products_screen.dart", "r") as f:
    content = f.read()

start_str = "                        : SingleChildScrollView("
end_str = "                          ),"

if start_str in content and end_str in content:
    start_idx = content.find(start_str)
    # find the very last occurrence of the end string if needed, or find the correct one.
    # The end of the block is around line 596. Let's find "}).toList()," which is very unique.
    unique_end_marker = "                              }).toList(),"
    if unique_end_marker in content:
        end_idx = content.find(unique_end_marker)
        # advance past the close brackets
        remainder = content[end_idx:]
        end_idx += remainder.find("                        )") + len("                        )")
        
        new_content = """                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final p = _filteredProducts[index];
                              final isActive = p['is_active'] == 1;
                              final isLowStock = (p['current_stock'] ?? 0) <= (p['min_stock'] ?? 0);
                              
                              return Card(
                                color: Colors.white,
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isActive ? AppColors.primary.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.inventory_2, color: isActive ? AppColors.primary : AppColors.danger),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'],
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${p['sku'] ?? '-'} • ${p['category_name'] ?? 'Uncategorized'}',
                                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Jual: Rp ${p['sell_price'] ?? 0}',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.success),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Beli: Rp ${p['cost_price'] ?? 0}',
                                              style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'Stok: ${p['current_stock']} ${p['unit'] ?? ''}',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textDark),
                                                ),
                                                if (isLowStock) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.warning_amber, size: 16, color: AppColors.danger),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isActive ? 'Active' : 'Inactive',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: isActive ? AppColors.success : AppColors.danger,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.history, color: AppColors.textLight, size: 20),
                                            tooltip: 'Riwayat Harga',
                                            onPressed: () => _showPriceHistory(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.print_outlined, color: Colors.blueGrey, size: 20),
                                            tooltip: 'Print Label',
                                            onPressed: () {
                                              if (p['barcode'] != null && p['barcode'].toString().isNotEmpty) {
                                                # Need to escape or just use what I can 
                                                pass
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                            tooltip: 'Edit',
                                            onPressed: () => _showAddProductDialog(p),
                                          ),
                                          if (isActive)
                                            IconButton(
                                              icon: const Icon(Icons.block, color: AppColors.danger, size: 20),
                                              tooltip: 'Nonaktifkan',
                                              onPressed: () => _confirmSoftDelete(p),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                                              tooltip: 'Aktifkan Kembali',
                                              onPressed: () => _confirmReactivate(p),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )"""
        
        # fix the python script escaping for currency format inside string
        new_content = new_content.replace("Rp ${p['sell_price'] ?? 0}", "${currencyFormat.format(p['sell_price'] ?? 0)}")
        new_content = new_content.replace("Rp ${p['cost_price'] ?? 0}", "${currencyFormat.format(p['cost_price'] ?? 0)}")
        new_content = new_content.replace("pass", """showDialog(context: context, builder: (context) => PrintBarcodeDialog(product: p));} else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please generate a barcode first.'), backgroundColor: AppColors.warning));""")
        
        with open("lib/screens/products_screen.dart", "w") as f:
            f.write(content[:start_idx] + new_content + content[end_idx:])
        print("Replaced successfully")
    else:
        print("Could not find unique end marker")
else:
    print("Could not find start or end strings")
