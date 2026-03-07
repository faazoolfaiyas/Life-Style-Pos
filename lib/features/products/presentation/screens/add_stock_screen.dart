import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/product_model.dart';
import '../../data/models/stock_model.dart';
import '../../data/models/attribute_models.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/services/stock_service.dart';
import '../../../connections/services/connection_service.dart';
import '../../../connections/data/models/connection_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// --- State Models ---

class SizeBlockState {
  final String id;
  String? sizeId;
  
  // "Apply to All" controllers (Common values)
  final TextEditingController commonBuyCtrl = TextEditingController();
  final TextEditingController commonSellCtrl = TextEditingController();
  final TextEditingController commonQtyCtrl = TextEditingController();
  
  bool showCommonInputs = false; // Toggle for "Apply to all"

  final List<ColorRowState> colorRows = [];

  SizeBlockState() : id = const Uuid().v4();
}

class ColorRowState {
  final String id;
  String? colorId;
  
  final TextEditingController buyCtrl = TextEditingController();
  final TextEditingController sellCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(); // 0 means use common if valid
  
  ColorRowState() : id = const Uuid().v4();
}

// --- Main Screen ---

class AddStockScreen extends ConsumerStatefulWidget {
  final Product product;
  final int? existingBatchNumber;
  final String? existingSupplierId;
  final String? existingDesignId;

  const AddStockScreen({
    super.key, 
    required this.product,
    this.existingBatchNumber,
    this.existingSupplierId,
    this.existingDesignId,
  });

  @override
  ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Batch Context
  Supplier? _selectedSupplier;
  ProductDesign? _selectedDesign;
  final TextEditingController _noteCtrl = TextEditingController();
  
  // Grid State
  final List<SizeBlockState> _blocks = [];
  bool _isSaving = false;

  // Global Batch Tools
  final TextEditingController _globalBuyCtrl = TextEditingController();
  final TextEditingController _globalSellCtrl = TextEditingController();
  final TextEditingController _globalQtyCtrl = TextEditingController();
  bool _showGlobalBatchTools = false;

  @override
  void dispose() {
    _globalBuyCtrl.dispose();
    _globalSellCtrl.dispose();
    _globalQtyCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _addNewBlock();
  }

  void _addNewBlock() {
    setState(() {
      final block = SizeBlockState();
      block.colorRows.add(ColorRowState());
      _blocks.add(block);
    });
  }

  void _removeBlock(int index) {
    setState(() => _blocks.removeAt(index));
  }

  int get _totalQty {
    int total = 0;
    int globalQty = int.tryParse(_globalQtyCtrl.text) ?? 0;
    for (var block in _blocks) {
      int commonQty = int.tryParse(block.commonQtyCtrl.text) ?? globalQty;
      for (var row in block.colorRows) {
        int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;
        total += qty;
      }
    }
    return total;
  }

  double get _totalValue {
    double total = 0;
    double globalBuy = double.tryParse(_globalBuyCtrl.text) ?? 0;
    int globalQty = int.tryParse(_globalQtyCtrl.text) ?? 0;

    for (var block in _blocks) {
      double commonBuy = double.tryParse(block.commonBuyCtrl.text) ?? globalBuy;
      int commonQty = int.tryParse(block.commonQtyCtrl.text) ?? globalQty;
      
      for (var row in block.colorRows) {
         double buy = double.tryParse(row.buyCtrl.text) ?? commonBuy;
         int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty;
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
    if (_selectedSupplier == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier is required.')));
       return;
    }

    setState(() => _isSaving = true);
    
    try {
      final stockService = ref.read(stockServiceProvider);
      final user = ref.read(authStateProvider).value;
      final userId = user?.uid ?? 'unknown';
      final userEmail = user?.email ?? 'Unknown User';
      
      final batchId = widget.existingBatchNumber ?? await stockService.getNextBatchNumber(widget.product.id!);
      final now = DateTime.now();

      // Get current attribute lists to look up indices
      final sizes = ref.read(sizesProvider).asData?.value ?? [];
      final colors = ref.read(colorsProvider).asData?.value ?? [];

      
      List<StockItem> newItems = [];
      
      for (var block in _blocks) {
        if (block.sizeId == null) continue;

        // Lookup Size Index
        final sizeObj = sizes.where((s) => s.id == block.sizeId).firstOrNull;
        final sizeIdx = sizeObj?.index ?? 0;
        
        double globalBuy = double.tryParse(_globalBuyCtrl.text) ?? 0;
        double globalSell = double.tryParse(_globalSellCtrl.text) ?? 0;
        int globalQty = int.tryParse(_globalQtyCtrl.text) ?? 0;

        double commonBuy = double.tryParse(block.commonBuyCtrl.text) ?? globalBuy;
        double commonSell = double.tryParse(block.commonSellCtrl.text) ?? globalSell;
        int commonQty = int.tryParse(block.commonQtyCtrl.text) ?? globalQty;

        for (var row in block.colorRows) {
          if (row.colorId == null) continue;

          // Lookup Color Index
          final colorObj = colors.where((c) => c.id == row.colorId).firstOrNull;
          final colorIdx = colorObj?.index ?? 0;

          double buy = double.tryParse(row.buyCtrl.text) ?? commonBuy;
          double sell = double.tryParse(row.sellCtrl.text) ?? commonSell;
          int qty = int.tryParse(row.qtyCtrl.text) ?? commonQty; // If row qty empty, use common/global

          // Skip if qty is 0. 
          if (qty <= 0) continue; 

          // Smart ID Generation: Numeric-based
          // Format: {ProductCode}{Batch}{DesignIndex}{SizeIndex}{ColorIndex}
          // Note: DesignIndex defaults to 0 if not present.
          
          final designIdx = _selectedDesign?.index ?? 0;
          
          // Concatenate parts. User example: 111224 (P:11, B:1, D:2, S:2, C:4)
          // Ensure indices are handled safely.
          String id = '${widget.product.productCode}$batchId$designIdx$sizeIdx$colorIdx';
          
          newItems.add(StockItem(
            id: id,
            productId: widget.product.id!,
            batchNumber: batchId,
            supplierId: _selectedSupplier!.id!,
            designId: _selectedDesign?.id,
            sizeId: block.sizeId!,
            colorId: row.colorId!,
            purchasePrice: buy,
            retailPrice: sell,
            wholesalePrice: 0,
            quantity: qty,
            dateAdded: now,
            description: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          ));
        }
      }

      if (newItems.isEmpty) throw Exception("No items with quantity > 0 to add.");

      await stockService.addStockBatch(newItems, userId: userId, userEmail: userEmail);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch #$batchId added successfully (${newItems.length} items)')));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Providers
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final designsAsync = ref.watch(designsProvider);
    final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));

    // Handle initial selection if existing IDs provided (Safer using post-frame callbacks)
    if (widget.existingSupplierId != null && _selectedSupplier == null) {
      suppliersAsync.whenData((list) {
        final found = list.whereType<Supplier>().where((s) => s.id == widget.existingSupplierId).firstOrNull;
        if (found != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedSupplier = found));
        }
      });
    }

    if (widget.existingDesignId != null && _selectedDesign == null) {
      designsAsync.whenData((list) {
        final found = list.where((d) => d.id == widget.existingDesignId).firstOrNull;
        if (found != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _selectedDesign = found));
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Subtle background contrast
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Stock Batch', style: GoogleFonts.outfit(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.product.name, style: GoogleFonts.outfit(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
          ],
        ),
        leading: const BackButton(),
        actions: [
          // Quick reset or other actions could go here
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).dividerColor, height: 1),
        ),
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
                    // --- 1. Batch Context (Header) ---
                    _BatchHeader(
                      suppliersAsync: suppliersAsync,
                      designsAsync: designsAsync,
                      selectedSupplier: _selectedSupplier,
                      selectedDesign: _selectedDesign,
                      noteCtrl: _noteCtrl,
                      onSupplierChanged: (v) => setState(() => _selectedSupplier = v),
                      onDesignChanged: (v) => setState(() => _selectedDesign = v),
                    ),
                    
                    const SizedBox(height: 16),
                    // --- Global Batch Tools Panel ---
                    _GlobalToolsPanel(
                      showTools: _showGlobalBatchTools,
                      buyCtrl: _globalBuyCtrl,
                      sellCtrl: _globalSellCtrl,
                      qtyCtrl: _globalQtyCtrl,
                      onToggle: () => setState(() => _showGlobalBatchTools = !_showGlobalBatchTools),
                      onChanged: () => setState(() {}),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock Composition', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
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

                    // --- 2. Size Blocks ---
                    ..._blocks.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _SizeEntryBlock(
                          index: entry.key,
                          state: entry.value,
                          sizesAsync: sizesAsync,
                          colorsAsync: colorsAsync,
                          onRemove: () => _removeBlock(entry.key),
                          onUpdate: () => setState(() {}), // Trigger total recalc
                          globalBuy: _globalBuyCtrl.text,
                          globalSell: _globalSellCtrl.text,
                          globalQty: _globalQtyCtrl.text,
                        ),
                      );
                    }),

                    // --- 3. Add Block Button ---
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
                    const SizedBox(height: 100), // Space for sticky footer
                  ],
                ),
              ),
            ),
          ),
          
          // --- 4. Sticky Footer ---
          _StickySummaryFooter(
            totalQty: _totalQty,
            totalValue: _totalValue,
            isSaving: _isSaving,
            onSave: _submit,
            onCancel: () => Navigator.pop(context),
          ),
        ],
      ),
    );
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
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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
                      // 1. Remove initial empty block if it exists
                      if (_blocks.length == 1 && _blocks.first.sizeId == null && selected.isNotEmpty) {
                        _blocks.clear();
                      }

                      // 2. Create blocks for new selections
                      for (var id in selected) {
                        if (!_blocks.any((b) => b.sizeId == id)) {
                          final block = SizeBlockState();
                          block.sizeId = id;
                          block.colorRows.add(ColorRowState());
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
    // Helper function to parse color hex codes
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
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
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
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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
                      // Add selected colors to ALL size blocks
                      for (var block in _blocks) {
                        // FIX: Remove empty placeholder block if it exists
                        if (block.colorRows.length == 1 && block.colorRows.first.colorId == null) {
                           block.colorRows.clear();
                        }

                        for (var colorId in selected) {
                          // Only add if not already present
                          if (!block.colorRows.any((r) => r.colorId == colorId)) {
                            final row = ColorRowState();
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
}

// --- Sub-Widgets ---

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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_outlined, color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              Text('Batch Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: suppliersAsync.when(
                  data: (list) => DropdownButtonFormField<Supplier>(
                    value: selectedSupplier,
                    decoration: _cleanDecoration(context, 'Supplier'),
                    items: list.whereType<Supplier>().map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                    onChanged: onSupplierChanged,
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  loading: () => const SizedBox(height: 48, child: Center(child: LinearProgressIndicator())),
                  error: (e, s) => const Text('Error loading suppliers'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: designsAsync.when(
                  data: (list) => DropdownButtonFormField<ProductDesign>(
                    value: selectedDesign,
                    decoration: _cleanDecoration(context, 'Design (Opt)'),
                    items: [
                      DropdownMenuItem(value: null, child: Text("None", style: TextStyle(color: Theme.of(context).disabledColor))),
                      ...list.where((d) => d.isActive).map((d) => DropdownMenuItem(value: d, child: Text(d.name))),
                    ],
                    onChanged: onDesignChanged,
                  ),
                  loading: () => const SizedBox(),
                  error: (_,__) => const SizedBox(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: noteCtrl,
            decoration: _cleanDecoration(context, 'Batch Note (Optional)'),
            maxLines: 1,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
  InputDecoration _cleanDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
    );
  }
}

class _GlobalToolsPanel extends StatelessWidget {
  final bool showTools;
  final TextEditingController buyCtrl;
  final TextEditingController sellCtrl;
  final TextEditingController qtyCtrl;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  const _GlobalToolsPanel({
    required this.showTools,
    required this.buyCtrl,
    required this.sellCtrl,
    required this.qtyCtrl,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: showTools ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: showTools ? Theme.of(context).primaryColor : Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 12),
                Text('Global Batch Price/Qty (Apply to All)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Icon(showTools ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (showTools)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(child: _buildInput(context, buyCtrl, 'Global Buy', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildInput(context, sellCtrl, 'Global Sell', Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildInput(context, qtyCtrl, 'Global Qty', Colors.orange)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInput(BuildContext context, TextEditingController ctrl, String label, Color tint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tint, fontSize: 11),
        isDense: true,
        filled: true,
        fillColor: tint.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }
}

class _SizeEntryBlock extends StatefulWidget {
  final int index;
  final SizeBlockState state;
  final AsyncValue<List<ProductSize>> sizesAsync;
  final AsyncValue<List<ProductColor>> colorsAsync;
  final VoidCallback onRemove;
  final VoidCallback onUpdate;
  final String globalBuy;
  final String globalSell;
  final String globalQty;

  const _SizeEntryBlock({
    required this.index,
    required this.state,
    required this.sizesAsync,
    required this.colorsAsync,
    required this.onRemove,
    required this.onUpdate,
    required this.globalBuy,
    required this.globalSell,
    required this.globalQty,
  });

  @override
  State<_SizeEntryBlock> createState() => _SizeEntryBlockState();
}

class _SizeEntryBlockState extends State<_SizeEntryBlock> {
  // Parsing helper for local use
  Color _parseColor(String? hexCode) {
    if (hexCode == null || hexCode.isEmpty) return Colors.black;
    try {
      String cleanHex = hexCode.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  void _triggerUpdate() => widget.onUpdate();

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
          // Block Header: Size Selector & Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                // Size Selector
                SizedBox(
                  width: 140,
                  child: widget.sizesAsync.when(
                    data: (sizes) => DropdownButtonFormField<String>(
                      value: widget.state.sizeId,
                      items: sizes.where((s) => s.isActive).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) {
                        setState(() => widget.state.sizeId = v); 
                        _triggerUpdate();
                      },
                      decoration: const InputDecoration(
                        isDense: true, 
                        contentPadding: EdgeInsets.zero, 
                        border: InputBorder.none,
                        hintText: 'Select Size',
                      ),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_,__) => const Icon(Icons.error, size: 16),
                  ),
                ),
                const Spacer(),
                // Toggle "Apply to all"
                TextButton.icon(
                  onPressed: () => setState(() => widget.state.showCommonInputs = !widget.state.showCommonInputs),
                  icon: Icon(widget.state.showCommonInputs ? Icons.expand_less : Icons.tune, size: 16),
                  label: Text(widget.state.showCommonInputs ? 'Hide Batch Tools' : 'Batch Tools', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                ),
                const SizedBox(width: 8),
                InkWell(onTap: widget.onRemove, child: const Icon(Icons.close, size: 18, color: Colors.red)),
              ],
            ),
          ),
          
          // Action Bar for Colors
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Text('Variants', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showMultiColorPicker(context),
                  icon: const Icon(Icons.palette_outlined, size: 16),
                  label: const Text('Add Multiple Colors', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),

          // "Apply to All" Panel (Toggleable)
          if (widget.state.showCommonInputs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Expanded(child: _buildMiniInput(widget.state.commonBuyCtrl, 'Size Buy', Colors.blue, widget.globalBuy)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniInput(widget.state.commonSellCtrl, 'Size Sell', Colors.green, widget.globalSell)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMiniInput(widget.state.commonQtyCtrl, 'Size Qty', Colors.orange, widget.globalQty)),
                ],
              ),
            ),

          // Grid Headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Buy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Sell', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).disabledColor))),
                const SizedBox(width: 32), // Spacer for delete icon
              ],
            ),
          ),

          // Color Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            itemCount: widget.state.colorRows.length,
            separatorBuilder: (c, i) => const Divider(height: 12, thickness: 0.5),
            itemBuilder: (context, index) {
              final row = widget.state.colorRows[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color Picker
                  Expanded(
                    flex: 3,
                    child: widget.colorsAsync.when(
                      data: (colors) => DropdownButtonFormField<String>(
                         value: row.colorId,
                         items: colors.where((c) => c.isActive).map((c) => DropdownMenuItem(
                           value: c.id, 
                           child: Row(
                             children: [
                               Container(width: 12, height: 12, decoration: BoxDecoration(color: _parseColor(c.hexCode), shape: BoxShape.circle)),
                               const SizedBox(width: 8),
                               Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1)),
                             ],
                           )
                         )).toList(),
                         onChanged: (v) {
                           setState(() => row.colorId = v);
                           _triggerUpdate();
                         },
                         decoration: _inputDec(context, null),
                         isExpanded: true,
                         validator: (v) => v == null ? '!' : null,
                      ),
                      loading: () => const SizedBox(),
                      error: (_,__) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Buy
                  Expanded(flex: 2, child: _buildRowInput(row.buyCtrl, widget.state.commonBuyCtrl.text.isNotEmpty ? widget.state.commonBuyCtrl.text : widget.globalBuy, context)),
                  const SizedBox(width: 8),
                  // Sell
                  Expanded(flex: 2, child: _buildRowInput(row.sellCtrl, widget.state.commonSellCtrl.text.isNotEmpty ? widget.state.commonSellCtrl.text : widget.globalSell, context)),
                  const SizedBox(width: 8),
                  // Qty
                  Expanded(flex: 2, child: _buildRowInput(row.qtyCtrl, widget.state.commonQtyCtrl.text.isNotEmpty ? widget.state.commonQtyCtrl.text : widget.globalQty, context)),
                  
                  // Delete
                  SizedBox(
                    width: 32,
                    child: IconButton(
                       icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.grey),
                       onPressed: () {
                         if (widget.state.colorRows.length > 1) {
                           setState(() => widget.state.colorRows.removeAt(index));
                           _triggerUpdate();
                         }
                       },
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Row Footer
          Padding(
             padding: const EdgeInsets.all(8),
             child: TextButton(
               onPressed: () {
                 setState(() => widget.state.colorRows.add(ColorRowState()));
               },
               child: const Text('+ Add Variant'),
             ),
          ),
        ],
      ),
    );
  }

  void _showMultiColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> selected = widget.state.colorRows.where((r) => r.colorId != null).map((r) => r.colorId!).toList();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Colors', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: widget.colorsAsync.when(
                  data: (colors) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.where((c) => c.isActive).map((color) {
                      final isSelected = selected.contains(color.id);
                      return FilterChip(
                        avatar: Container(width: 12, height: 12, decoration: BoxDecoration(color: _parseColor(color.hexCode), shape: BoxShape.circle)),
                        label: Text(color.name),
                        selected: isSelected,
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) selected.add(color.id!);
                            else selected.remove(color.id);
                          });
                        },
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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
                      // 1. Remove initial empty row if it exists and we're adding new items
                      if (widget.state.colorRows.length == 1 && widget.state.colorRows.first.colorId == null && selected.isNotEmpty) {
                         widget.state.colorRows.clear();
                      }

                      // 2. Add selected colors that aren't already present
                      for (var id in selected) {
                        if (!widget.state.colorRows.any((r) => r.colorId == id)) {
                          final row = ColorRowState();
                          row.colorId = id;
                          widget.state.colorRows.add(row);
                        }
                      }
                      _triggerUpdate();
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
  Widget _buildMiniInput(TextEditingController ctrl, String label, Color tint, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _triggerUpdate(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tint, fontSize: 11),
        hintText: hint.isNotEmpty ? hint : null,
        hintStyle: TextStyle(color: tint.withValues(alpha: 0.3), fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: tint.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRowInput(TextEditingController ctrl, String hint, BuildContext context) {
    return TextFormField(
      controller: ctrl,
      onChanged: (_) => _triggerUpdate(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDec(context, hint.isNotEmpty ? hint : null),
      style: const TextStyle(fontSize: 13),
    );
  }

  InputDecoration _inputDec(BuildContext context, String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Theme.of(context).disabledColor.withValues(alpha: 0.4)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
    );
  }
}

class _StickySummaryFooter extends StatelessWidget {
  final int totalQty;
  final double totalValue;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _StickySummaryFooter({
    required this.totalQty,
    required this.totalValue,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                   Text('TOTAL ADDITION', style: GoogleFonts.outfit(color: Theme.of(context).disabledColor, fontSize: 11, fontWeight: FontWeight.bold)),
                   Row(
                     children: [
                       Text('$totalQty items', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                       const SizedBox(width: 8),
                        Container(width: 1, height: 16, color: Theme.of(context).dividerColor),
                       const SizedBox(width: 8),
                       Text('LKR ${totalValue.toStringAsFixed(0)}', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                     ],
                   ),
                 ],
               ),
             ),
             const SizedBox(width: 16),
             OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
             const SizedBox(width: 12),
             Expanded(
               child: ElevatedButton(
                 onPressed: isSaving ? null : onSave,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Theme.of(context).primaryColor,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirm'),
               ),
             ),
           ],
         ),
       ),
    );
  }
}
