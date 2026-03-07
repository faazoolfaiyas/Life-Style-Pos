import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/product_model.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/models/attribute_models.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/services/purchase_order_service.dart';
import '../../../connections/services/connection_service.dart';
import '../../../connections/data/models/connection_model.dart';
import '../../data/services/stock_service.dart';

// --- State Models (Adapted for PO) ---

class POSizeBlockState {
  final String id;
  String? sizeId;
  
  // "Apply to All" controllers (Common values)
  final TextEditingController commonBuyCtrl = TextEditingController();
  final TextEditingController commonQtyCtrl = TextEditingController();
  
  bool showCommonInputs = false; 

  final List<POColorRowState> colorRows = [];

  POSizeBlockState() : id = const Uuid().v4();
}

class POColorRowState {
  final String id;
  String? colorId;
  
  final TextEditingController buyCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(); // 0 means use common if valid
  
  POColorRowState() : id = const Uuid().v4();
}

// --- Main Screen ---

class CreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  final Product product;
  final PurchaseOrder? orderToEdit;
  const CreatePurchaseOrderScreen({super.key, required this.product, this.orderToEdit});

  @override
  ConsumerState<CreatePurchaseOrderScreen> createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends ConsumerState<CreatePurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Batch Context
  Supplier? _selectedSupplier;
  // We store supplierId temporarily until providers load
  String? _pendingSupplierId;

  // Wait, PO items have individual designIds. The UI assumes mostly uniform or per-item, but header has global design. 
  // We'll assume global design for the batch if items share it.
  
  ProductDesign? _selectedDesign;
  final TextEditingController _noteCtrl = TextEditingController();
  
  // Grid State
  final List<POSizeBlockState> _blocks = [];
  bool _isSaving = false;
  bool _isLoadingPrices = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.orderToEdit != null) {
      _noteCtrl.text = widget.orderToEdit!.note ?? '';
      _pendingSupplierId = widget.orderToEdit!.supplierId;
      // We delay block reconstruction until build phase / providers loaded, or do it immediately if we just use IDs.
      // We can do it immediately using IDs.
      _reconstructBlocks();
    } else {
      _addNewBlock();
      _isLoaded = true;
    }
  }

  void _reconstructBlocks() {
    final order = widget.orderToEdit!;
    // Group by Size
    // We assume items with same size are in same block? 
    // The UI structure allows multiple blocks of same size (technically), but usually one per size.
    // Let's group by Size ID.
    
    final grouped = <String, List<PurchaseOrderItem>>{};
    for (var item in order.items) {
      if (!grouped.containsKey(item.sizeId)) grouped[item.sizeId] = [];
      grouped[item.sizeId]!.add(item);
    }
    
    for (var entry in grouped.entries) {
      final sizeId = entry.key;
      final items = entry.value;
      
      final block = POSizeBlockState();
      block.sizeId = sizeId;
      
      // Attempt to find common design?
      // For now just taking first item's design if valid
      if (items.isNotEmpty && items.first.designId != null && _selectedDesign == null) {
         // design linking requires provider, we'll do it in build via ID matching if needed
         // or just rely on global selector
      }

      for (var item in items) {
        final row = POColorRowState();
        row.colorId = item.colorId;
        row.qtyCtrl.text = item.quantity.toString();
        if (item.purchasePrice != null) row.buyCtrl.text = item.purchasePrice.toString();
        block.colorRows.add(row);
      }
      _blocks.add(block);
    }
    
    if (_blocks.isEmpty) _addNewBlock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time supplier resolution if editing
    if (!_isLoaded && widget.orderToEdit != null) {
       // We rely on build to resolve supplier object from provider
    }
  }

  void _addNewBlock() {
    setState(() {
      final block = POSizeBlockState();
      block.colorRows.add(POColorRowState());
      _blocks.add(block);
    });
  }

  void _removeBlock(int index) {
    setState(() => _blocks.removeAt(index));
  }

  // Smart Price Lookup Logic
  Future<void> _updatePricesFromHistory() async {
    setState(() => _isLoadingPrices = true);
    

    
    for (var block in _blocks) {
      if (block.sizeId == null) continue;
      
      for (var row in block.colorRows) {
        if (row.colorId == null) continue;
        
        // Only fill if empty to avoid overwriting user edits (especially in Edit Mode)
        if (row.buyCtrl.text.isNotEmpty) continue;
        
        final price = await ref.read(stockServiceProvider).getVariantLastCost(
          productId: widget.product.id!,
          sizeId: block.sizeId!,
          colorId: row.colorId!,
          designId: _selectedDesign?.id,
          supplierId: _selectedSupplier?.id,
        );

        if (price != null && mounted) {
           // Check again if empty to be safe after async gap
           if (row.buyCtrl.text.isEmpty) {
             row.buyCtrl.text = price.toStringAsFixed(2);
           }
        }
      }
    }

    if (mounted) setState(() => _isLoadingPrices = false);
  }

  Future<void> _deleteOrder() async {
    if (widget.orderToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this purchase order? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(purchaseOrderServiceProvider).deletePurchaseOrder(
        widget.product.id!, 
        widget.orderToEdit!.id
      );
      
      if (mounted) {
        Navigator.pop(context); // Close screen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isSaving = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting order: $e')));
      }
    }
  }

  int get _totalQty {
    int total = 0;
    for (var block in _blocks) {
      int commonQty = int.tryParse(block.commonQtyCtrl.text) ?? 0;
      for (var row in block.colorRows) {
        int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;
        total += qty;
      }
    }
    return total;
  }

  double get _totalValue {
    double total = 0;
    for (var block in _blocks) {
      double? commonBuy = double.tryParse(block.commonBuyCtrl.text);
      for (var row in block.colorRows) {
        double buy = double.tryParse(row.buyCtrl.text) ?? commonBuy ?? 0;
        int qty = int.tryParse(row.qtyCtrl.text) ?? (int.tryParse(block.commonQtyCtrl.text) ?? 0);
        total += (buy * qty);
      }
    }
    return total;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check the form for errors.')));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final poService = ref.read(purchaseOrderServiceProvider);
      
      final now = DateTime.now();
      final poId = widget.orderToEdit?.id ?? const Uuid().v4();

      final sizes = ref.read(sizesProvider).asData?.value ?? [];
      final colors = ref.read(colorsProvider).asData?.value ?? [];

      List<PurchaseOrderItem> newItems = [];
      
      for (var block in _blocks) {
        if (block.sizeId == null) continue;

        final sizeObj = sizes.where((s) => s.id == block.sizeId).firstOrNull;
        final sizeIdx = sizeObj?.index ?? 0;
        
        double? commonBuy = double.tryParse(block.commonBuyCtrl.text);
        int commonQty = int.tryParse(block.commonQtyCtrl.text) ?? 0;

        for (var row in block.colorRows) {
          if (row.colorId == null) continue;

          final colorObj = colors.where((c) => c.id == row.colorId).firstOrNull;
          final colorIdx = colorObj?.index ?? 0;

          double? buy = double.tryParse(row.buyCtrl.text) ?? commonBuy;
          int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;

          if (qty <= 0) continue; 

          final designIdx = _selectedDesign?.index ?? 0;
          
          String variantId = '${widget.product.productCode}0$designIdx$sizeIdx$colorIdx';
          
          newItems.add(PurchaseOrderItem(
            variantId: variantId,
            designId: _selectedDesign?.id,
            sizeId: block.sizeId!,
            colorId: row.colorId!,
            purchasePrice: buy,
            quantity: qty,
          ));
        }
      }

      if (newItems.isEmpty) throw Exception("No items with quantity > 0 to order.");

      final po = PurchaseOrder(
        id: poId,
        productId: widget.product.id!,
        supplierId: _selectedSupplier?.id,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        items: newItems,
        createdAt: widget.orderToEdit?.createdAt ?? now,
        updatedAt: widget.orderToEdit != null ? now : null,
        expiresAt: widget.orderToEdit?.expiresAt ?? now,
      );

      if (widget.orderToEdit != null) {
        await poService.updatePurchaseOrder(po);
      } else {
         await poService.addPurchaseOrder(po);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.orderToEdit != null ? 'Order updated' : 'Purchase Order created')));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMultiSizePicker(BuildContext context, AsyncValue<List<ProductSize>> sizesAsync) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> selected = _blocks.where((b) => b.sizeId != null).map((b) => b.sizeId!).toList();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Sizes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: sizesAsync.when(
                  data: (sizes) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sizes.where((s) => s.isActive).map((size) {
                      final isSelected = selected.contains(size.id);
                      return FilterChip(
                        label: Text(size.name),
                        selected: isSelected,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) selected.add(size.id!);
                            else selected.remove(size.id);
                          });
                        },
                        selectedColor: Theme.of(context).primaryColor.withAlpha(51),
                        checkmarkColor: Theme.of(context).primaryColor,
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e,__) => Text('Error: $e'),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (_blocks.length == 1 && _blocks.first.sizeId == null && selected.isNotEmpty) {
                        _blocks.clear();
                      }
                      for (var id in selected) {
                        if (!_blocks.any((b) => b.sizeId == id)) {
                          final block = POSizeBlockState();
                          block.sizeId = id;
                          block.colorRows.add(POColorRowState());
                          _blocks.add(block);
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGlobalMultiColorPicker(BuildContext context, AsyncValue<List<ProductColor>> colorsAsync) {
    Color parseColor(String? hexCode) {
      if (hexCode == null || hexCode.isEmpty) return Colors.grey;
      try {
        String cleanHex = hexCode.replaceAll('#', '').replaceAll('0x', '');
        if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
        return Color(int.parse(cleanHex, radix: 16));
      } catch (_) {
        return Colors.grey;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        List<String> selected = [];
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Colors to Add to All Sizes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: colorsAsync.when(
                  data: (colors) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.where((c) => c.isActive).map((color) {
                      final isSelected = selected.contains(color.id);
                      final colorValue = parseColor(color.hexCode);
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colorValue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.withAlpha(76), width: 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(color.name),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) selected.add(color.id!);
                            else selected.remove(color.id);
                          });
                        },
                        selectedColor: Theme.of(context).primaryColor.withAlpha(51),
                        checkmarkColor: Theme.of(context).primaryColor,
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e,__) => Text('Error: $e'),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (_blocks.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please add at least one size first')),
                      );
                      Navigator.pop(context);
                      return;
                    }
                    setState(() {
                      for (var block in _blocks) {
                        for (var colorId in selected) {
                          if (!block.colorRows.any((r) => r.colorId == colorId)) {
                            final row = POColorRowState();
                            row.colorId = colorId;
                            block.colorRows.add(row);
                          }
                        }
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Providers
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final designsAsync = ref.watch(designsProvider);
    final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));

    // One-time Resolution of Pending IDs (when editing)
    if (_pendingSupplierId != null && suppliersAsync.hasValue) {
      final suppliers = suppliersAsync.asData!.value.cast<Supplier>();
      final found = suppliers.where((s) => s.id == _pendingSupplierId).firstOrNull;
      if (found != null && _selectedSupplier == null) {
          // Defer to next frame to avoid state build error or just set it? 
          // Since we are in build, we shouldn't setState. But we can update local var if not for state.
          // Better: Use addPostFrameCallback or just set it if we check for null. 
          // Actually, we can't setState inside build. 
          // We'll use a post-frame callback callback carefully, OR just use `SchedulerBinding`.
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
               setState(() {
                 _selectedSupplier = found;
                 _pendingSupplierId = null; // Done
               });
             }
          });
      }
    }
    // Design resolution similar if we stored designId at PO level (we didn't explicitly store singular designId in PO, only items. But UI assumes it). 
    // We'll skip design resolution for now unless we iterate items.
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.orderToEdit != null ? 'Edit Purchase Order' : 'Create Purchase Order', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.product.name, style: GoogleFonts.outfit(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        actions: [
          if (widget.orderToEdit != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Order',
              onPressed: _isSaving ? null : _deleteOrder,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _BatchHeader(
                      suppliersAsync: suppliersAsync,
                      designsAsync: designsAsync,
                      selectedSupplier: _selectedSupplier,
                      selectedDesign: _selectedDesign,
                      noteCtrl: _noteCtrl,
                      onSupplierChanged: (v) {
                        setState(() => _selectedSupplier = v);
                        _updatePricesFromHistory(); // Auto-fill on supplier change
                      },
                      onDesignChanged: (v) {
                        setState(() => _selectedDesign = v);
                         _updatePricesFromHistory();
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    if (_isLoadingPrices) 
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Composition', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showMultiSizePicker(context, sizesAsync),
                              icon: const Icon(Icons.style, size: 18),
                              label: const Text('Select Multiple Sizes'),
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _showGlobalMultiColorPicker(context, colorsAsync),
                              icon: const Icon(Icons.palette, size: 18),
                              label: const Text('Select Multiple Colors'),
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                      // Size Blocks
                    ..._blocks.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _POSizeEntryBlock(
                          index: entry.key,
                          state: entry.value,
                          productId: widget.product.id!, // Pass Product ID here
                          sizesAsync: sizesAsync,
                          colorsAsync: colorsAsync,
                          onRemove: () => _removeBlock(entry.key),
                          onUpdate: () => setState(() {}),
                          onLoadPriceTrigger: _updatePricesFromHistory, 
                        ),
                      );
                    }),

                    Center(
                      child: TextButton.icon(
                        onPressed: _addNewBlock,
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text('Add Another Size Group'),
                        style: TextButton.styleFrom(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                           backgroundColor: Theme.of(context).cardColor,
                           side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                       Text('TOTAL ORDER', style: GoogleFonts.outfit(color: Theme.of(context).disabledColor, fontSize: 11, fontWeight: FontWeight.bold)),
                       Text('$_totalQty Items', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                       Text('LKR ${_totalValue.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Theme.of(context).primaryColor)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.orderToEdit != null ? 'Update Order' : 'Create Order'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse similar structure to AddStock but simplified for PO (no sell price)

class _BatchHeader extends StatelessWidget {
  final AsyncValue<List<ConnectionModel>> suppliersAsync;
  final AsyncValue<List<ProductDesign>> designsAsync;
  final Supplier? selectedSupplier;
  final ProductDesign? selectedDesign;
  final TextEditingController noteCtrl;
  final ValueChanged<Supplier?> onSupplierChanged;
  final ValueChanged<ProductDesign?> onDesignChanged;

  const _BatchHeader({
    required this.suppliersAsync,
    required this.designsAsync,
    required this.selectedSupplier,
    required this.selectedDesign,
    required this.noteCtrl,
    required this.onSupplierChanged,
    required this.onDesignChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [FaIcon(FontAwesomeIcons.fileInvoice, size: 18, color: Theme.of(context).primaryColor), const SizedBox(width: 8), Text('Order Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: suppliersAsync.when(
                  data: (list) => DropdownButtonFormField<Supplier>(
                    value: selectedSupplier,
                    decoration: InputDecoration(labelText: 'Supplier (Optional)', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    items: [
                      DropdownMenuItem(value: null, child: Text("None", style: TextStyle(color: Theme.of(context).disabledColor))),
                      ...list.whereType<Supplier>().map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                    ],
                    isExpanded: true,
                    onChanged: onSupplierChanged,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_,__) => const Text('Error'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: designsAsync.when(
                  data: (list) => DropdownButtonFormField<ProductDesign>(
                    value: selectedDesign,
                    decoration: InputDecoration(labelText: 'Design (Opt)', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    items: [
                      DropdownMenuItem(value: null, child: Text("None", style: TextStyle(color: Theme.of(context).disabledColor))),
                      ...list.where((d) => d.isActive).map((d) => DropdownMenuItem(value: d, child: Text(d.name))),
                    ],
                    isExpanded: true,
                    onChanged: onDesignChanged,
                  ),
                  loading: () => const SizedBox(),
                  error: (_,__) => const SizedBox(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(controller: noteCtrl, decoration: InputDecoration(labelText: 'Note (Optional)', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        ],
      ),
    );
  }
}

class _POSizeEntryBlock extends StatefulWidget {
  final int index;
  final POSizeBlockState state;
  final String productId; // Add this
  final AsyncValue<List<ProductSize>> sizesAsync;
  final AsyncValue<List<ProductColor>> colorsAsync;
  final VoidCallback onRemove;
  final VoidCallback onUpdate;
  final VoidCallback onLoadPriceTrigger;

  const _POSizeEntryBlock({
    required this.index,
    required this.state,
    required this.productId, // Add this
    required this.sizesAsync,
    required this.colorsAsync,
    required this.onRemove,
    required this.onUpdate,
    required this.onLoadPriceTrigger,
  });

  @override
  State<_POSizeEntryBlock> createState() => _POSizeEntryBlockState();
}

class _POSizeEntryBlockState extends State<_POSizeEntryBlock> {


  double calculateGroupTotal() {
    double total = 0;
    double? commonBuy = double.tryParse(widget.state.commonBuyCtrl.text);
    int commonQty = int.tryParse(widget.state.commonQtyCtrl.text) ?? 0;

    for (var row in widget.state.colorRows) {
      double buy = double.tryParse(row.buyCtrl.text) ?? commonBuy ?? 0;
      int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;
      total += (buy * qty);
    }
    return total;
  }

  double calculateRowTotal(POColorRowState row) {
    double? commonBuy = double.tryParse(widget.state.commonBuyCtrl.text);
    int commonQty = int.tryParse(widget.state.commonQtyCtrl.text) ?? 0;
    
    double buy = double.tryParse(row.buyCtrl.text) ?? commonBuy ?? 0;
    int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;
    return buy * qty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
             decoration: BoxDecoration(
               color: Theme.of(context).scaffoldBackgroundColor,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
               border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
             ),
             child: Row(children: [
               SizedBox(
                 width: 140,
                 child: widget.sizesAsync.when(
                   data: (sizes) => DropdownButtonFormField<String>(
                     value: widget.state.sizeId,
                     items: sizes.where((s) => s.isActive).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                     onChanged: (v) {
                       setState(() => widget.state.sizeId = v); 
                       widget.onLoadPriceTrigger(); // Update prices
                       widget.onUpdate();
                     },
                     isExpanded: true,
                     decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none, hintText: 'Select Size'),
                     validator: (v) => v == null ? 'Required' : null,
                   ),
                   loading: () => const LinearProgressIndicator(), 
                   error: (_,__) => const Icon(Icons.error, size: 16),
                 ),
               ),
               const Spacer(),
               // Group Total
               Text(
                 'grp: ${calculateGroupTotal().toStringAsFixed(0)}', 
                 style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
               ),
               const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() => widget.state.showCommonInputs = !widget.state.showCommonInputs),
                  icon: Icon(widget.state.showCommonInputs ? Icons.expand_less : Icons.tune, size: 16),
                  label: Text(widget.state.showCommonInputs ? 'Hide Tools' : 'Tools', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                InkWell(onTap: widget.onRemove, child: const Icon(Icons.close, size: 18, color: Colors.red)),
             ]),
           ),
           
           if (widget.state.showCommonInputs)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               color: Colors.blue.withValues(alpha: 0.05),
               child: Row(
                 children: [
                   Expanded(child: _buildMiniInput(widget.state.commonBuyCtrl, 'Batch Price (Opt)', Colors.blue)),
                   const SizedBox(width: 8),
                   Expanded(child: _buildMiniInput(widget.state.commonQtyCtrl, 'Batch Qty', Colors.orange)),
                 ],
               ),
             ),

           // Headers 
           Padding(
             padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
             child: Row(
               children: [
                 Expanded(flex: 3, child: Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                 const SizedBox(width: 8),
                 Expanded(flex: 2, child: Text('Price (Opt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                 const SizedBox(width: 8),
                 Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                 const SizedBox(width: 8),
                 SizedBox(width: 50, child: Text('Val', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                 const SizedBox(width: 32),
               ],
             ),
           ),

           Column(
             children: [
               for (int index = 0; index < widget.state.colorRows.length; index++) ...[
                 if (index > 0) const Divider(height: 12, thickness: 0.5),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(
                         flex: 3,
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             widget.colorsAsync.when(
                               data: (colors) => DropdownButtonFormField<String>(
                                 isExpanded: true,
                                 value: widget.state.colorRows[index].colorId,
                                 items: colors.where((c) => c.isActive).map((c) => DropdownMenuItem(
                                   value: c.id, 
                                   child: Text(c.name, overflow: TextOverflow.ellipsis),
                                 )).toList(),
                                 onChanged: (v) { 
                                   setState(() => widget.state.colorRows[index].colorId = v); 
                                   widget.onLoadPriceTrigger(); 
                                   widget.onUpdate(); 
                                 }, 
                                 decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14), border: OutlineInputBorder()),
                                 validator: (v) => v == null ? '!' : null,
                               ),
                               loading: () => const SizedBox(height: 48), error: (_,__) => const SizedBox(height: 48),
                             ),
                              if (widget.state.sizeId != null && widget.state.colorRows[index].colorId != null)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final stockKey = '${widget.productId}|${widget.state.sizeId}|${widget.state.colorRows[index].colorId}';
                                    final asyncValue = ref.watch(variantStockInfoProvider(stockKey));

                                    return asyncValue.when(
                                      data: (data) {
                                         final qty = data['qty'] as int? ?? 0;
                                         final cost = data['cost'] as double?;
                                         
                                         if (qty == 0 && cost == null) return const SizedBox();

                                         return Padding(
                                           padding: const EdgeInsets.only(top: 4, left: 4),
                                           child: Row(
                                             children: [
                                               if (qty > 0)
                                                 Text(
                                                  'Stk: $qty', 
                                                  style: TextStyle(fontSize: 10, color: Colors.indigo[400], fontWeight: FontWeight.bold)
                                                 ),
                                               if (qty > 0 && cost != null)
                                                  const SizedBox(width: 8), // Spacer
                                               if (cost != null)
                                                 Text(
                                                  'Last Cost: ${cost.toStringAsFixed(0)}', 
                                                  style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold)
                                                 ),
                                             ],
                                           ),
                                         );
                                      },
                                      loading: () => const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1)),
                                      error: (_, __) => const SizedBox(),
                                    );
                                  }
                                ),
                           ],
                         ),
                       ),
                       const SizedBox(width: 8),
                       Expanded(flex: 2, child: _buildRowInput(widget.state.colorRows[index].buyCtrl, widget.state.commonBuyCtrl.text, context)),
                       const SizedBox(width: 8),
                        Expanded(flex: 2, child: _buildRowInput(widget.state.colorRows[index].qtyCtrl, widget.state.commonQtyCtrl.text, context)),
                        const SizedBox(width: 8),
                         // Variant Value
                         SizedBox(
                           width: 50, 
                           child: Text(
                             calculateRowTotal(widget.state.colorRows[index]).toStringAsFixed(0), 
                             textAlign: TextAlign.right, 
                             style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                           )
                         ),
                       SizedBox(width: 32, child: IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey), onPressed: () {
                         if (widget.state.colorRows.length > 1) {
                           setState(() => widget.state.colorRows.removeAt(index));
                           widget.onUpdate();
                         }
                       })),
                     ],
                   ),
                 ),
               ],
             ],
           ),
           Padding(
             padding: const EdgeInsets.all(8),
             child: TextButton(onPressed: () => setState(() => widget.state.colorRows.add(POColorRowState())), child: const Text('+ Add Variant')),
           ),
        ],
      ),
    );
  }

  Widget _buildMiniInput(TextEditingController ctrl, String label, Color tint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => widget.onUpdate(),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: tint, fontSize: 11),
        isDense: true, filled: true, fillColor: tint.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRowInput(TextEditingController ctrl, String hint, BuildContext context) {
    return TextFormField(
      controller: ctrl,
      onChanged: (_) => widget.onUpdate(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint.isNotEmpty ? hint : null,
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
