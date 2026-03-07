import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../features/products/data/models/product_model.dart';
import '../../../../features/products/data/models/stock_model.dart';
import '../../../../features/products/data/services/stock_service.dart';
import '../../../../features/products/data/models/attribute_models.dart';
import '../../../../features/products/data/services/attribute_service.dart';
import '../../data/providers/pos_provider.dart';

import '../../../../features/products/data/providers/attribute_provider.dart';

class StockSelectionDialog extends ConsumerStatefulWidget {
  final Product product;
  const StockSelectionDialog({super.key, required this.product});

  @override
  ConsumerState<StockSelectionDialog> createState() => _StockSelectionDialogState();
}

class _StockSelectionDialogState extends ConsumerState<StockSelectionDialog> {
  String? _selectedDesignId;
  
  @override
  Widget build(BuildContext context) {
    // 1. Fetch Attributes for ID resolution
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final designsAsync = ref.watch(designsProvider);

    final Map<String, ProductSize> sizeMap = {
      for (var s in sizesAsync.value ?? []) s.id!: s
    };
    final Map<String, ProductColor> colorMap = {
      for (var c in colorsAsync.value ?? []) c.id!: c
    };
    final Map<String, ProductDesign> designMap = {
      for (var d in designsAsync.value ?? []) d.id!: d
    };

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (_selectedDesignId != null)
                        Text(
                          'Design: ${_getDesignName(_selectedDesignId!, designMap)}', 
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                        )
                      else
                        const Text('Select Variant', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                if (_selectedDesignId != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedDesignId = null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Designs'),
                  ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 32),

            // Content
            Expanded(
              child: StreamBuilder<List<StockItem>>(
                stream: ref.watch(stockServiceProvider).getStockForProduct(widget.product.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  
                  final stocks = snapshot.data ?? [];
                  final availableStocks = stocks.where((s) => s.quantity > 0).toList();

                  if (availableStocks.isEmpty) {
                    return const Center(child: Text('No stock available for this product.'));
                  }

                  // Group by Design
                  final designs = availableStocks.map((s) => s.designId ?? 'Standard').toSet().toList();
                  
                  // 1. Auto-Select if only 1 design (or no design)
                  if (designs.length == 1 && _selectedDesignId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) setState(() => _selectedDesignId = designs.first);
                    });
                  }

                  // VIEW 1: Design Selection
                  if (designs.length > 1 && _selectedDesignId == null) {
                    return _buildDesignGrid(designs, availableStocks, designMap);
                  }

                  // VIEW 2: Variant Selection
                  final designStocks = availableStocks.where((s) => (s.designId ?? 'Standard') == (_selectedDesignId ?? designs.first)).toList();
                  
                  return _buildVariantGrid(designStocks, sizeMap, colorMap, designMap);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDesignName(String id, Map<String, ProductDesign> map) {
    if (id == 'Standard') return 'Standard Design';
    return map[id]?.name ?? 'Unknown Design'; // Show Name, not ID
  }

  Widget _buildDesignGrid(List<String> designs, List<StockItem> allStocks, Map<String, ProductDesign> designMap) {
    // ... existing implementation remains correct ...
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: designs.length,
      itemBuilder: (context, index) {
        final designId = designs[index];
        final count = allStocks.where((s) => (s.designId ?? 'Standard') == designId).length;
        final designName = _getDesignName(designId, designMap);
        
        return InkWell(
          onTap: () => setState(() => _selectedDesignId = designId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style, size: 32, color: Theme.of(context).primaryColor),
                const SizedBox(height: 8),
                Text(designName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                Text('$count Variants Available', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVariantGrid(List<StockItem> stocks, Map<String, ProductSize> sizeMap, Map<String, ProductColor> colorMap, Map<String, ProductDesign> designMap) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final item = stocks[index];
        return _buildStockCard(item, sizeMap, colorMap, designMap);
      },
    );
  }

  Widget _buildStockCard(StockItem item, Map<String, ProductSize> sizeMap, Map<String, ProductColor> colorMap, Map<String, ProductDesign> designMap) {
    final theme = Theme.of(context);
    
    // Resolve Attributes
    final size = sizeMap[item.sizeId];
    final color = colorMap[item.colorId];
    final design = designMap[item.designId];
    
    final sizeCode = size?.code ?? item.sizeId; // Check map first, fallback to ID
    final colorName = color?.name ?? 'Standard';
    final designName = design?.name ?? '';
    final colorHex = color?.hexCode;

    return InkWell(
      onTap: () {
        // format: "Color - Design"
        final variantDetail = designName.isNotEmpty ? '$colorName - $designName' : colorName;

        ref.read(cartProvider.notifier).addToCart(
          widget.product,
          size: sizeCode, // Use CODE (S, M, L)
          color: variantDetail,
          stockId: item.id, // Pass Stock ID
          price: item.retailPrice,
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Added ${widget.product.name} - $sizeCode $colorName'), 
            duration: const Duration(milliseconds: 500), backgroundColor: Colors.green));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
             // Size & Color Tag
             Container(
               width: 48, 
               height: 48,
               decoration: BoxDecoration(
                 color: _parseColorHex(colorHex) ?? theme.primaryColor.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
               ),
               alignment: Alignment.center,
               child: Text(
                 sizeCode,
                 style: TextStyle(
                   fontWeight: FontWeight.bold, 
                   fontSize: 18,
                   color: _parseColorHex(colorHex) != null ? _contrastColor(_parseColorHex(colorHex)!) : theme.primaryColor
                 ),
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Text(colorName, 
                     style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), 
                     maxLines: 1, overflow: TextOverflow.ellipsis
                   ),
                   const SizedBox(height: 2),
                   Text('Qty: ${item.quantity}', style: TextStyle(fontSize: 12, color: item.quantity < 5 ? Colors.red : Colors.grey)),
                 ],
               ),
             ),
             // Price
             Column(
               mainAxisAlignment: MainAxisAlignment.center,
               crossAxisAlignment: CrossAxisAlignment.end,
               children: [
                 Text('LKR', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                 Text(item.retailPrice.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               ],
             ),
          ],
        ),
      ),
    );
  }

  Color? _parseColorHex(String? colorStr) {
    if (colorStr == null) return null;
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      return null;
    } catch (e) { return null; }
  }

  Color _contrastColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
