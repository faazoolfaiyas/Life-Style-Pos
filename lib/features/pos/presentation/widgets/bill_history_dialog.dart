import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/bill_model.dart';
import '../../data/providers/pos_provider.dart';
import '../../data/services/pos_service.dart'; // Import for posServiceProvider
import '../../../../features/products/data/providers/attribute_provider.dart'; // Import for restoring stock
import '../../../../features/auth/presentation/providers/auth_provider.dart'; // For user ID
import 'bill_detail_dialog.dart';

class BillHistoryDialog extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  const BillHistoryDialog({super.key, this.isSelectionMode = false});

  @override
  ConsumerState<BillHistoryDialog> createState() => _BillHistoryDialogState();
}

class _BillHistoryDialogState extends ConsumerState<BillHistoryDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  
  // Filter States
  DateTimeRange? _selectedDateRange;
  String? _selectedPaymentMethod;
  bool _showReturnsOnly = false;

  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filterBills);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterBills() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredBills = _allBills.where((bill) {
        // 1. Text Search
        final matchesQuery = bill.billNumber.toLowerCase().contains(query) ||
               (bill.customerName ?? '').toLowerCase().contains(query) ||
               (bill.customerPhone ?? '').contains(query);
        if (!matchesQuery) return false;

        // 2. Date Range Filter
        if (_selectedDateRange != null) {
          if (bill.createdAt.isBefore(_selectedDateRange!.start) || 
              bill.createdAt.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }

        if (_selectedPaymentMethod != null && _selectedPaymentMethod != 'All') {
          if (bill.paymentMethod != _selectedPaymentMethod) return false;
        }

        // 4. Returns Only
        if (_showReturnsOnly && !bill.isReturn) return false;

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(recentBillsProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900, // Widened for filters
        height: 750,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.isSelectionMode ? 'Select Reference Bill' : 'Transaction History', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Search & Filters Row
            Row(
              children: [
                // SEARCH BAR
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by ID, Name or Phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // DATE RANGE PICKER
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _selectedDateRange,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDateRange = picked;
                          _filterBills();
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _selectedDateRange == null 
                        ? 'Select Dates' 
                        : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
                 if (_selectedDateRange != null)
                   IconButton(
                     icon: const Icon(Icons.close, size: 18),
                     onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                          _filterBills();
                        });
                     }
                   ),

                const SizedBox(width: 16),

                // PAYMENT METHOD DROPDOWN
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPaymentMethod ?? 'All',
                        isExpanded: true,
                        items: ['All', 'Cash', 'Card', 'Transfer', 'Credit'].map((String method) {
                          return DropdownMenuItem<String>(
                            value: method,
                            child: Text(method),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPaymentMethod = val == 'All' ? null : val;
                            _filterBills();
                          });
                        },
                    ),
                  ),
                ),
                ),
                const SizedBox(width: 16),
                
                // RETURNS FILTER CHIP
                FilterChip(
                  label: const Text('Returns'),
                  selected: _showReturnsOnly,
                  onSelected: (val) {
                     setState(() {
                       _showReturnsOnly = val;
                       _filterBills();
                     });
                  },
                  backgroundColor: theme.cardColor,
                  selectedColor: Colors.red.withValues(alpha: 0.2),
                  checkmarkColor: Colors.red,
                  labelStyle: TextStyle(
                    color: _showReturnsOnly ? Colors.red : theme.hintColor, 
                    fontWeight: _showReturnsOnly ? FontWeight.bold : FontWeight.normal
                  ),
                  side: BorderSide(color: _showReturnsOnly ? Colors.red : theme.dividerColor),
                ),
              ],
            ),
             const SizedBox(height: 24),
             
             // Content Table
             Expanded(
               child: historyAsync.when(
                 data: (bills) {
                   // Initial Data Sync
                   // Only sync if raw data changed or we haven't loaded yet. 
                   // WE DO NOT overwrite filtered list if user is actively searching 
                   // unless it's the very first load.
                   if (_allBills.isEmpty && bills.isNotEmpty) {
                      _allBills = bills;
                      _filteredBills = bills;
                      // Re-apply filters if any exist on initial load (unlikely but safe)
                      if (_searchCtrl.text.isNotEmpty || _selectedDateRange != null || _selectedPaymentMethod != null) {
                         WidgetsBinding.instance.addPostFrameCallback((_) => _filterBills());
                      }
                   } else if (bills.length != _allBills.length) {
                       // Simple check for updates (e.g. new bill added in background)
                       _allBills = bills;
                       // Re-run filter on new data
                       WidgetsBinding.instance.addPostFrameCallback((_) => _filterBills());
                   }

                   if (_filteredBills.isEmpty) {
                     return Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.history_toggle_off, size: 48, color: theme.disabledColor),
                           const SizedBox(height: 16),
                           Text('No transactions found', style: TextStyle(color: theme.hintColor)),
                         ],
                       ),
                     );
                   }

                   return Theme(
                     // Use specific divider color for the table
                     data: theme.copyWith(dividerColor: theme.dividerColor.withOpacity(0.5)),
                     child: SingleChildScrollView(
                       child: DataTable(
                         headingRowColor: MaterialStateProperty.all(theme.canvasColor),
                         dataRowColor: MaterialStateProperty.all(theme.cardColor),
                         columns: [
                           DataColumn(label: Text('Bill ID', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Method', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                           DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor))),
                         ],
                         rows: _filteredBills.map((bill) {
                           final isCompleted = bill.status == 'Completed';
                           return DataRow(
                             cells: [
                               DataCell(
                                 Row(
                                   children: [
                                     Text(bill.billNumber, style: const TextStyle(fontWeight: FontWeight.w500)),
                                     if (bill.isReturn)
                                       Container(
                                         margin: const EdgeInsets.only(left: 8),
                                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                         decoration: BoxDecoration(
                                           color: Colors.red.withOpacity(0.1),
                                           borderRadius: BorderRadius.circular(4),
                                           border: Border.all(color: Colors.red, width: 0.5)
                                         ),
                                         child: const Text('RETURN', style: TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold)),
                                       ),
                                   ],
                                 )
                               ),
                               DataCell(Text(DateFormat('MMM d, HH:mm').format(bill.createdAt))),
                               DataCell(Text(bill.customerName ?? '-')),
                               DataCell(Text('LKR ${bill.totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor))),
                               DataCell(Text(bill.paymentMethod)),
                               DataCell(
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                     borderRadius: BorderRadius.circular(4),
                                     border: Border.all(color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5))
                                   ),
                                   child: Text(
                                     bill.status, 
                                     style: TextStyle(
                                       fontSize: 11, 
                                       color: isCompleted ? Colors.green : Colors.orange,
                                       fontWeight: FontWeight.bold
                                     )
                                   ),
                                 )
                               ),
                               DataCell(
                                 Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     IconButton(
                                       icon: Icon(Icons.visibility_outlined, color: theme.primaryColor),
                                       onPressed: () {
                                         showDialog(
                                           context: context, 
                                           builder: (context) => BillDetailDialog(bill: bill)
                                         );
                                       },
                                     ),
                                     IconButton(
                                       icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                       onPressed: () => _onDeleteBill(context, ref, bill),
                                     ),
                                     if (!widget.isSelectionMode)
                                        IconButton(
                                          icon: Icon(Icons.edit, color: Colors.blue),
                                          tooltip: 'Edit / Load to Cart',
                                          onPressed: () {
                                            ref.read(cartProvider.notifier).loadBillForEditing(bill);
                                            Navigator.pop(context); // Close History
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bill #${bill.billNumber} loaded for editing.')));
                                          },
                                        ),
                                     if (widget.isSelectionMode)
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, bill),
                                          child: const Text('Select'),
                                        ),
                                   ],
                                 )
                               ),
                             ],
                           );
                         }).toList(),
                       ),
                     ),
                   );
                 },
                 loading: () => const Center(child: CircularProgressIndicator()),
                 error: (err, stack) => Center(child: Text('Error: $err')),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDeleteBill(BuildContext context, WidgetRef ref, Bill bill) async {
    bool restoreStock = true; // Default to true

    final confirm = await showDialog<bool>(
      context: context, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Transaction'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to delete Bill #${bill.billNumber}?'),
                  const SizedBox(height: 16),
                  
                  // Restore Stock Option
                  Row(
                    children: [
                      Checkbox(
                        value: restoreStock, 
                        onChanged: (val) {
                           setDialogState(() => restoreStock = val ?? false);
                        }
                      ),
                      const Text('Restore items to inventory?'),
                    ],
                  ),
                  if (restoreStock)
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0),
                      child: Text(
                        'This will restore items to existing stock batches (if found) or create new return batches.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), // Cancel
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, true), // Confirm
                  child: const Text('Delete'),
                ),
              ],
            );
          }
        );
      }
    );

    if (confirm != true) return;

    // 1. Restore Stock if requested
    if (restoreStock) {
      try {
        // Need sizes and colors for reverse lookup
        final sizes = ref.read(sizesProvider).value ?? [];
        final colors = ref.read(colorsProvider).value ?? [];
        final user = ref.read(authStateProvider).value;
        
        if (sizes.isEmpty || colors.isEmpty) {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Warning: Attributes not loaded. Skipping stock restoration.')));
           }
           // Don't return, proceed to delete
        } else {
           await ref.read(posServiceProvider).restoreBillStock(
            bill, 
            sizes, 
            colors,
            userId: user?.uid ?? 'unknown',
            userEmail: user?.email ?? 'unknown',
          );
        }
      } catch (e) {
        print('Error during stock restoration: $e');
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warning: Stock restoration failed: $e')));
        }
        // Proceed to delete bill anyway? 
        // User wants bill deleted.
      }
    }

    // 2. Delete Bill
    try {
      await ref.read(posServiceProvider).deleteBill(bill.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted successfully')));
        Navigator.pop(context); // Close dialog if it was open or just refresh? 
        // Actually this is called from the table view, so we don't need to pop, just snackbar.
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting bill: $e')));
      }
    }
  }
}
