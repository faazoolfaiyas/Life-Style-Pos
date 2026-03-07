import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stock_model.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/services/stock_service.dart';
import '../../data/services/purchase_order_service.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/models/attribute_models.dart';
import '../../../connections/data/models/connection_model.dart';
import '../../../connections/services/connection_service.dart';

class StockEvaluationDialog extends ConsumerStatefulWidget {
  final Product product;
  final String? supplierId;
  final String? designId;
  final String? sizeId;
  final String? batchNumber;

  const StockEvaluationDialog({
    super.key,
    required this.product,
    this.supplierId,
    this.designId,
    this.sizeId,
    this.batchNumber,
  });

  @override
  ConsumerState<StockEvaluationDialog> createState() => _StockEvaluationDialogState();
}

class _StockEvaluationDialogState extends ConsumerState<StockEvaluationDialog> {
  // Key: "SizeID_ColorID" -> Controller
  final Map<String, TextEditingController> _qtyControllers = {};
  bool _isCreatingOrder = false;

  @override
  void dispose() {
    for (var c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stocksStream = ref.watch(stockServiceProvider).getStockForProduct(widget.product.id!);
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final designsAsync = ref.watch(designsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stock Evaluation', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<StockItem>>(
              stream: stocksStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                var stocks = snapshot.data ?? [];

                // Apply Filters
                if (widget.supplierId != null) stocks = stocks.where((s) => s.supplierId == widget.supplierId).toList();
                if (widget.designId != null) stocks = stocks.where((s) => s.designId == widget.designId).toList();
                if (widget.sizeId != null) stocks = stocks.where((s) => s.sizeId == widget.sizeId).toList();
                if (widget.batchNumber != null) stocks = stocks.where((s) => s.batchNumber.toString() == widget.batchNumber).toList();

                if (stocks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No matching stock found.')),
                  );
                }

                // Aggregate Data
                // Map<SizeID, List<StockItem>>
                final Map<String, List<StockItem>> groupedBySize = {};
                for (var stock in stocks) {
                  groupedBySize.putIfAbsent(stock.sizeId, () => []).add(stock);
                }

                // Sort sizes if possible (simplistic sort by ID or name if available)
                final sortedSizeKeys = groupedBySize.keys.toList();
                
                // Helper to get name
                String getName(AsyncValue<List<dynamic>> asyncVal, String id) {
                   return asyncVal.maybeWhen(
                     data: (list) => list.cast<dynamic>().firstWhere((e) => e.id == id, orElse: () => null)?.name ?? id,
                     orElse: () => id,
                   );
                }

                int totalQty = stocks.fold(0, (sum, s) => sum + s.quantity);

                return Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                               Icon(Icons.inventory, color: theme.primaryColor),
                               const SizedBox(width: 12),
                               Text('Total Quantity Found:', style: TextStyle(fontWeight: FontWeight.w600, color: theme.primaryColor)),
                               const SizedBox(width: 8),
                               Text('$totalQty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.primaryColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // List by Size
                        ...sortedSizeKeys.map((sizeId) {
                          final sizeStocks = groupedBySize[sizeId]!;
                          final sizeStepTotal = sizeStocks.fold(0, (sum, s) => sum + s.quantity);
                          final sizeName = getName(sizesAsync, sizeId);

                          // Group by Color within Size
                          final Map<String, List<StockItem>> stocksByColor = {};
                           for (var stock in sizeStocks) {
                             stocksByColor.putIfAbsent(stock.colorId, () => []).add(stock);
                           }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Size Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Size: $sizeName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Total: $sizeStepTotal', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // Color List
                                ...stocksByColor.entries.map((entry) {
                                   final colorId = entry.key;
                                   final colorStocks = entry.value;
                                   final colorName = getName(colorsAsync, colorId);
                                   final colorQty = colorStocks.fold(0, (sum, s) => sum + s.quantity);
                                   
                                   // Get Unique Prices
                                   final prices = colorStocks.map((s) => s.purchasePrice).toSet().toList()..sort();
                                   final priceString = prices.map((p) => p.toStringAsFixed(0)).join(', ');

                                   return Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                     child: Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Expanded(
                                           child: Row(
                                             children: [
                                               const Icon(Icons.circle, size: 8, color: Colors.grey),
                                               const SizedBox(width: 8),
                                               Text(colorName),
                                               const SizedBox(width: 8),
                                               // Prices
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                 decoration: BoxDecoration(
                                                   color: Colors.green.withOpacity(0.1),
                                                   borderRadius: BorderRadius.circular(4),
                                                   border: Border.all(color: Colors.green.withOpacity(0.3)),
                                                 ),
                                                 child: Text(
                                                   'LKR $priceString', 
                                                   style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.w500)
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                         // Stock Qty
                                         Text('$colorQty', style: const TextStyle(fontWeight: FontWeight.w500)),
                                         const SizedBox(width: 16),
                                         // PO Qty Input
                                         SizedBox(
                                           width: 80,
                                           child: TextField(
                                              controller: _qtyControllers.putIfAbsent('${sizeId}_${colorId}', () => TextEditingController()),
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: 'Qty',
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                           ),
                                         ),
                                       ],
                                     ),
                                   );
                                }),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreatingOrder ? null : () => _handleCreateOrder(sizesAsync, colorsAsync, ref.read(designsProvider), ref.watch(streamConnectionProvider('Supplier'))),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: _isCreatingOrder 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text('Create Purchase Order from Inputs'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _handleCreateOrder(
      AsyncValue<List<ProductSize>> sizesAsync,
      AsyncValue<List<ProductColor>> colorsAsync,
      AsyncValue<List<ProductDesign>> designsAsync,
      AsyncValue<List<ConnectionModel>> suppliersAsync,
  ) async {
    // 1. Validate inputs
    final Map<String, int> validInputs = {};
    for (var entry in _qtyControllers.entries) {
       final qty = int.tryParse(entry.value.text);
       if (qty != null && qty > 0) {
         validInputs[entry.key] = qty;
       }
    }

    if (validInputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter at least one quantity.')));
      return;
    }

    // 2. Show Selection Dialog (Supplier & Design)
    final suppliers = suppliersAsync.value?.cast<Supplier>() ?? [];
    final designs = designsAsync.value ?? [];
    
    // Default selections
    Supplier? selectedSupplier = suppliers.where((s) => s.id == widget.supplierId).firstOrNull;
    ProductDesign? selectedDesign = designs.where((d) => d.id == widget.designId).firstOrNull;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Confirm Order Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     DropdownButtonFormField<Supplier>(
                        value: selectedSupplier,
                        decoration: InputDecoration(
                          labelText: 'Select Supplier',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text("None")),
                          ...suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                        ],
                        onChanged: (val) => setDialogState(() => selectedSupplier = val),
                     ),
                     const SizedBox(height: 16),
                     DropdownButtonFormField<ProductDesign>(
                        value: selectedDesign,
                        decoration: InputDecoration(
                          labelText: 'Select Design',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text("None")),
                          ...designs.where((d) => d.isActive).map((d) => DropdownMenuItem(value: d, child: Text(d.name))),
                        ],
                        onChanged: (val) => setDialogState(() => selectedDesign = val),
                     ),
                     const SizedBox(height: 12),
                     const Text('Prices will be auto-filled from the last purchase history if available.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Create Order'),
                ),
              ],
            );
          },
        );
      }
    );

    if (shouldCreate != true) return;

    setState(() => _isCreatingOrder = true);

    try {
      // 3. Prepare Data
      final sizes = sizesAsync.value ?? [];
      final colors = colorsAsync.value ?? [];
      
      final List<PurchaseOrderItem> items = [];
      final stockService = ref.read(stockServiceProvider);

      for (var entry in validInputs.entries) {
         final parts = entry.key.split('_');
         final sizeId = parts[0];
         final colorId = parts[1];
         final qty = entry.value;

         final sizeIdx = sizes.indexWhere((s) => s.id == sizeId);
         final colorIdx = colors.indexWhere((c) => c.id == colorId);
         final designIdx = selectedDesign?.index ?? 0; 

         final variantId = '${widget.product.productCode}0$designIdx${sizeIdx == -1 ? 0 : sizeIdx}${colorIdx == -1 ? 0 : colorIdx}';
         
         // 4. Auto-Fetch Price
         double? lastPrice = await stockService.getVariantLastCost(
            productId: widget.product.id!, 
            sizeId: sizeId, 
            colorId: colorId,
            designId: selectedDesign?.id,
            supplierId: selectedSupplier?.id,
         );

         items.add(PurchaseOrderItem(
           variantId: variantId,
           designId: selectedDesign?.id,
           sizeId: sizeId,
           colorId: colorId,
           purchasePrice: lastPrice, 
           quantity: qty,
         ));
      }

      // 5. Create PO Object
      final now = DateTime.now();
      final po = PurchaseOrder(
         id: const Uuid().v4(),
         productId: widget.product.id!,
         supplierId: selectedSupplier?.id,
         note: 'Auto-created from Stock Evaluation',
         items: items,
         createdAt: now,
         expiresAt: now, // Service will correct this
      );

      // 6. Call Service
      await ref.read(purchaseOrderServiceProvider).addPurchaseOrder(po);

      if (mounted) {
        Navigator.pop(context); // Close Dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase Order Created Successfully!')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }
}
