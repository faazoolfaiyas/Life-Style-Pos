import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/product_model.dart';
import '../../data/models/stock_model.dart';
import '../../data/services/stock_service.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/models/attribute_models.dart';

import '../../../connections/data/models/connection_model.dart';
import '../../../connections/services/connection_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../screens/add_stock_screen.dart';

class BatchDetailDialog extends ConsumerStatefulWidget {
  final Product product;
  final int batchNumber;

  const BatchDetailDialog({super.key, required this.product, required this.batchNumber});

  @override
  ConsumerState<BatchDetailDialog> createState() => _BatchDetailDialogState();
}

class _BatchDetailDialogState extends ConsumerState<BatchDetailDialog> {


  @override
  Widget build(BuildContext context) {
    // Determine streams
    final stockAsync = ref.watch(stockServiceProvider).getStockForProduct(widget.product.id!);
    final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));
    final designsAsync = ref.watch(designsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      child: Container(
        width: 900,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header is now moved into StreamBuilder for access to batch metadata
             const SizedBox(height: 24),
             
             // Content
             Expanded(
               child: StreamBuilder<List<StockItem>>(
                 stream: stockAsync,
                 builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   
                   final batchItems = snapshot.data!.where((s) => s.batchNumber == widget.batchNumber).toList();
                   
                   if (batchItems.isEmpty) return Center(child: Text('No items found in this batch.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)));

                    // Resolve Supplier & Design
                    String supplierName = 'Unknown';
                    suppliersAsync.whenData((suppliers) {
                      final supplierId = batchItems.first.supplierId;
                      final supplier = suppliers.cast<Supplier?>().firstWhere((s) => s?.id == supplierId, orElse: () => null);
                      if (supplier != null) supplierName = supplier.shopName;
                    });

                    String designName = 'None';
                    designsAsync.whenData((designs) {
                      final designId = batchItems.first.designId;
                      final design = designs.firstWhere((d) => d.id == designId, orElse: () => ProductDesign(id: '', name: 'None', isActive: false, createdAt: DateTime.now()));
                      if (design.id?.isNotEmpty == true) designName = design.name;
                    });
                   
                   return Column(
                     children: [
                       // Header (Moved inside for batch context)
                       Row(
                         children: [
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('Batch #${widget.batchNumber}', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                               Text('Program: ${widget.product.name}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                             ],
                           ),
                           const Spacer(),
                           ElevatedButton.icon(
                             onPressed: () => _addItemToBatch(context, batchItems.first),
                             icon: const Icon(Icons.add, size: 18),
                             label: const Text('Add Item to Batch'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             ),
                           ),
                           const SizedBox(width: 8),
                           TextButton.icon(
                             onPressed: () => _deleteBatch(context, widget.product.id!, widget.batchNumber),
                             icon: const Icon(Icons.delete_sweep, size: 18),
                             label: const Text('Delete Batch'),
                             style: TextButton.styleFrom(
                               foregroundColor: Colors.red,
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             ),
                           ),
                           const SizedBox(width: 12),
                           IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                         ],
                       ),
                       const SizedBox(height: 24),

                       // Summary
                       Container(
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceAround,
                           children: [
                             _stat('Items', '${batchItems.length}', context),
                             _stat('Total Qty', '${batchItems.fold(0, (sum, i) => sum + i.quantity)}', context),
                             _stat('Total Value', 'LKR ${batchItems.fold(0.0, (sum, i) => sum + (i.retailPrice * i.quantity)).toStringAsFixed(0)}', context),
                             _stat('Supplier', supplierName, context, onEdit: () => _editBatchFields(context, isSupplier: true)),
                             _stat('Design', designName, context, onEdit: () => _editBatchFields(context, isSupplier: false)),
                             Text(DateFormat('yyyy-MM-dd HH:mm').format(batchItems.first.dateAdded), style: TextStyle(color: Theme.of(context).disabledColor)),
                           ],
                         ),
                       ),
                       const SizedBox(height: 24),

                       // Table Header
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         child: Row(
                           children: const [
                             Expanded(flex: 2, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                             Expanded(child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                             Expanded(child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold))),
                             Expanded(child: Text('Buy', style: TextStyle(fontWeight: FontWeight.bold))),
                             Expanded(child: Text('Sell', style: TextStyle(fontWeight: FontWeight.bold))),
                             Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                             SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                           ],
                         ),
                       ),
                       Divider(height: 1, color: Theme.of(context).dividerColor),
                       
                       // List
                       Expanded(
                         child: ListView.separated(
                           itemCount: batchItems.length,
                           separatorBuilder: (c, i) => Divider(height: 1, color: Theme.of(context).dividerColor),
                           itemBuilder: (context, index) {
                             final item = batchItems[index];
                             return Container(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                               child: Row(
                                 children: [
                                   Expanded(flex: 2, child: Text(item.id, style: TextStyle(fontSize: 12, color: Theme.of(context).disabledColor))),
                                   Expanded(child: _AttributeName(provider: sizesProvider, id: item.sizeId)),
                                   Expanded(child: _AttributeName(provider: colorsProvider, id: item.colorId, isColor: true)),
                                   Expanded(child: Text(item.purchasePrice.toStringAsFixed(0))),
                                   Expanded(child: Text(item.retailPrice.toStringAsFixed(0))),
                                   Expanded(child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                   SizedBox(
                                     width: 80,
                                     child: Row(
                                       children: [
                                         IconButton(
                                           icon: const Icon(Icons.edit, size: 18, color: Colors.blue), // Keep functional colors
                                           onPressed: () => _editItem(context, item),
                                         ),
                                         IconButton(
                                           icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                           onPressed: () => _deleteItem(context, item),
                                         ),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                             );
                           },
                         ),
                       ),
                     ],
                   );
                 },
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, BuildContext context, {VoidCallback? onEdit}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (onEdit != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit, size: 14),
                onPressed: onEdit,
              ),
          ],
        ),
        Text(label, style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12)),
      ],
    );
  }

  void _editBatchFields(BuildContext context, {required bool isSupplier}) {
    final suppliersAsync = ref.read(streamConnectionProvider('Supplier'));
    final designsAsync = ref.read(designsProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSupplier ? 'Change Batch Supplier' : 'Change Batch Design'),
        content: SizedBox(
          width: 300,
          child: isSupplier 
            ? suppliersAsync.when(
                data: (list) => DropdownButtonFormField<String>(
                  items: list.cast<Supplier>().map((s) => DropdownMenuItem(value: s.id, child: Text(s.shopName))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    // Confirmation Dialog
                    final confirm = await _showConfirmUpdate(context, isSupplier);
                    if (confirm == true) {
                      await _performBatchUpdate(v, isSupplier: true);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Select Supplier'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e,s) => Text('Error: $e'),
              )
            : designsAsync.when(
                data: (list) => DropdownButtonFormField<String>(
                  items: list.where((d) => d.isActive).map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    // Confirmation Dialog
                     final confirm = await _showConfirmUpdate(context, isSupplier);
                    if (confirm == true) {
                      await _performBatchUpdate(v, isSupplier: false);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Select Design'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e,s) => Text('Error: $e'),
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _performBatchUpdate(String newValue, {required bool isSupplier}) async {
    final user = ref.read(authStateProvider).value;
    try {
      await ref.read(stockServiceProvider).updateBatchFields(
        widget.product.id!,
        widget.batchNumber,
        supplierId: isSupplier ? newValue : null,
        designId: isSupplier ? null : newValue,
        userId: user?.uid ?? 'unknown',
        userEmail: user?.email ?? 'Unknown User',
      );
    } catch (e) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
       }
    }
  }

  Future<bool?> _showConfirmUpdate(BuildContext context, bool isSupplier) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Update?'),
        content: Text('This will change the ${isSupplier ? "Supplier" : "Design"} for ALL items in this batch (#${widget.batchNumber}). Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Update All')),
        ],
      ),
    );
  }

  void _addItemToBatch(BuildContext context, StockItem sampleItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStockScreen(
          product: widget.product,
          existingBatchNumber: widget.batchNumber,
          existingSupplierId: sampleItem.supplierId,
          existingDesignId: sampleItem.designId,
        ),
      ),
    ).then((_) {
      // Refresh or handle post-add
    });
  }

  void _editItem(BuildContext context, StockItem item) {
    // Simple dialog to edit Qty, Buy, Sell
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final buyCtrl = TextEditingController(text: item.purchasePrice.toString());
    final sellCtrl = TextEditingController(text: item.retailPrice.toString());
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Stock Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
               TextField(controller: buyCtrl, decoration: const InputDecoration(labelText: 'Buy Price'), keyboardType: TextInputType.number),
               TextField(controller: sellCtrl, decoration: const InputDecoration(labelText: 'Sell Price'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                try {
                  setState(() => isLoading = true);
                  final qty = int.parse(qtyCtrl.text);
                  final buy = double.parse(buyCtrl.text);
                  final sell = double.parse(sellCtrl.text);
                  
                  // Update
                  final updated = item.copyWith(
                    quantity: qty,
                    purchasePrice: buy,
                    retailPrice: sell,
                  );
                  
                  final user = ref.read(authStateProvider).value;
                  await ref.read(stockServiceProvider).updateStock(
                    updated, 
                    userId: user?.uid ?? 'unknown',
                    userEmail: user?.email ?? 'Unknown User',
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ) 
                : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(BuildContext context, StockItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('Are you sure you want to remove this stock item from the batch? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             onPressed: () async {
                final user = ref.read(authStateProvider).value;
                try {
                  await ref.read(stockServiceProvider).deleteStock(
                    item.productId, 
                    item.id,
                    userId: user?.uid ?? 'unknown',
                    userEmail: user?.email ?? 'Unknown User',
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                    );
                    Navigator.pop(context); // Close dialog even if failed? Or keep open? safer to keep open usually but for now simple handling. actually keep dialog open if possible, but dialog is "Are you sure?" so we should close that and show error.
                  }
                }
             },
             child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteBatch(BuildContext context, String productId, int batchNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entire Batch?'),
        content: Text('Warning: This will permanently delete ALL stock items in Batch #$batchNumber.\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final user = ref.read(authStateProvider).value;
              try {
                await ref.read(stockServiceProvider).deleteStockBatch(
                  productId, 
                  batchNumber,
                  userId: user?.uid ?? 'unknown',
                  userEmail: user?.email ?? 'Unknown User',
                );
                if (context.mounted) {
                   Navigator.pop(context); // Close confirm
                   Navigator.pop(context); // Close Detail Dialog
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}

class _AttributeName extends ConsumerWidget {
  // Copied for simplicity, or ideally abstract this to a shared widget
  final dynamic provider; 
  final String id;
  final bool isColor;

  const _AttributeName({required this.provider, required this.id, this.isColor = false});

  // Simplified version for dialog
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<dynamic> asyncValue = ref.watch(provider);
    return asyncValue.when(
      data: (items) {
        final List<dynamic> list = items as List<dynamic>;
        final item = list.where((e) => e.id == id).firstOrNull;
        if (item == null) return Text(id);
        
        if (isColor) {
           Color color = Colors.black;
           try {
             String hex = (item.hexCode as String? ?? '').replaceAll('#', '');
             if (hex.length == 6) hex = 'FF$hex';
             color = Color(int.parse(hex, radix: 16));
           } catch (_) {}
           return Row(children: [
             Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
             const SizedBox(width: 4),
             Text(item.name),
           ]);
        }
        return Text(item.name);
      },
      loading: () => const Text('...'),
      error: (err, stack) => const Text('Err'),
    );
  }
}


