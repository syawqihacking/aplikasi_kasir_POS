import sys

with open("lib/screens/pos_screen.dart", "r") as f:
    content = f.read()

start_str = "  void _showPaymentDialog() {"
end_str = """    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }"""

if start_str in content and end_str in content:
    start_idx = content.find(start_str)
    end_idx = content.find(end_str) + len(end_str)
    
    new_content = """  void _showPaymentDialog() {
    double paidAmount = _selectedPaymentMethod == 'Cash' ? 0.0 : _grandTotal;
    
    String splitMethod1 = 'Cash';
    String splitMethod2 = 'Transfer';
    double splitAmount1 = 0.0;
    double splitAmount2 = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSplit = _selectedPaymentMethod == 'Split';
            
            if (isSplit) {
              paidAmount = splitAmount1 + splitAmount2;
            }
            
            final changeAmount = paidAmount - _grandTotal;
            final isSufficient = paidAmount >= _grandTotal;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 450,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Payment',
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill:', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16)),
                        Text('Rp ${_grandTotal.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isSplit) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: splitMethod1,
                              items: ['Cash', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => splitMethod1 = val);
                              },
                              decoration: InputDecoration(labelText: 'Method 1', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Amount 1 (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              onChanged: (val) {
                                setDialogState(() {
                                  splitAmount1 = double.tryParse(val) ?? 0.0;
                                  paidAmount = splitAmount1 + splitAmount2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: splitMethod2,
                              items: ['Cash', 'Transfer', 'QRIS'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => splitMethod2 = val);
                              },
                              decoration: InputDecoration(labelText: 'Method 2', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Amount 2 (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              onChanged: (val) {
                                setDialogState(() {
                                  splitAmount2 = double.tryParse(val) ?? 0.0;
                                  paidAmount = splitAmount1 + splitAmount2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else if (_selectedPaymentMethod == 'Cash')
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (Rp)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.money),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            paidAmount = double.tryParse(value) ?? 0.0;
                          });
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Awaiting $_selectedPaymentMethod payment...',
                          style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Change:', style: GoogleFonts.outfit(color: AppColors.textLight, fontSize: 16)),
                        Text(
                          changeAmount > 0 ? 'Rp ${changeAmount.toStringAsFixed(0)}' : 'Rp 0',
                          style: GoogleFonts.outfit(
                            color: changeAmount >= 0 ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSufficient ? () async {
                              Navigator.pop(context); // Close dialog
                              String finalMethod = isSplit 
                                ? 'Split ($splitMethod1: ${splitAmount1.toStringAsFixed(0)}, $splitMethod2: ${splitAmount2.toStringAsFixed(0)})'
                                : _selectedPaymentMethod;
                              await _processTransaction(paidAmount, changeAmount, finalMethod);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  Future<void> _processTransaction(double paidAmount, double changeAmount, String finalMethod) async {
    try {
      await DatabaseHelper.instance.saveTransaction(
        subtotal: _subtotal,
        tax: _tax,
        grandTotal: _grandTotal,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        paymentMethod: finalMethod,
        cartItems: _cart.items,
      );

      if (mounted) {
        _showReceiptDialog(
          subtotal: _subtotal,
          discount: _discountTotal,
          tax: _tax,
          grandTotal: _grandTotal,
          paidAmount: paidAmount,
          changeAmount: changeAmount,
          paymentMethod: finalMethod,
          items: List.from(_cart.items),
        );
        _cart.clear();
        setState(() {
          _discountTotal = 0;
          _selectedPaymentMethod = 'Cash';
        });
        _loadCatalog(); // Refresh catalog to update stock numbers
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }"""
    
    with open("lib/screens/pos_screen.dart", "w") as f:
        f.write(content[:start_idx] + new_content + content[end_idx:])
    print("Replaced successfully")
else:
    print("Could not find start or end strings")
