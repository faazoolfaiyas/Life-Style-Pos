import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../../data/providers/product_providers.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stock_model.dart';
import '../widgets/batch_detail_dialog.dart';
import '../widgets/stock_label_dialog.dart';
import '../../data/services/stock_service.dart';
import '../../data/services/product_service.dart'; // Added
import 'add_stock_screen.dart';
import '../../../connections/services/connection_service.dart';
import '../widgets/purchase_orders_list_dialog.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/services/purchase_order_service.dart';


import '../widgets/stock_filter_panel.dart';
import '../widgets/stock_evaluation_dialog.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// Notifier for selected product
class SelectedProductNotifier extends Notifier<Product?> {
  @override
  Product? build() => null;

  void set(Product? product) {
    state = product;
  }
}

final selectedInventoryProductProvider = NotifierProvider<SelectedProductNotifier, Product?>(() {
  return SelectedProductNotifier();
});

final allPendingOrdersProvider = StreamProvider<List<PurchaseOrder>>((ref) {
  final service = ref.watch(purchaseOrderServiceProvider);
  return service.getAllPendingOrdersStream();
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _stockSearchCtrl = TextEditingController();
  
  // Stock View State
  String? _filterSupplierId;
  String? _filterDesignId; // New Filter
  String? _filterSizeId; // New Filter
  String? _filterBatchNumber; // New Filter

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProduct = ref.watch(selectedInventoryProductProvider);

    if (selectedProduct != null) {
      return _buildStockDetailView(theme, selectedProduct);
    }

    return _buildProductListView(theme);
  }

  Widget _buildProductListView(ThemeData theme) {
    final productsAsync = ref.watch(productsStreamProvider);
    final pendingOrdersAsync = ref.watch(allPendingOrdersProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Inventory Management',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn().slideX(),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.refresh), 
                      tooltip: 'Recalculate Totals',
                      onPressed: () => _recalculateAllTotals(context, ref),
                    ),
                  ],
                ),
                 SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) => _handleInventorySearch(val),
                    decoration: InputDecoration(
                      hintText: 'Search inventory or Scan ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary Cards (Compact & Expanded)
            productsAsync.when(
              data: (products) {
                final totalProducts = products.length;
                final lowStock = products.where((p) => p.stockQuantity > 0 && p.stockQuantity < 10).length;
                final outOfStock = products.where((p) => p.stockQuantity == 0).length;
                
                // Use new fields
                final totalCostValue = products.fold(0.0, (sum, p) => sum + p.totalCost);
                final totalSalesValue = products.fold(0.0, (sum, p) => sum + p.totalSales);
                
                final pendingPOs = pendingOrdersAsync.value?.length ?? 0;

                return Row(
                  children: [
                    Expanded(child: _buildSummaryCard(context, 'Total Items', '$totalProducts', Icons.inventory, Colors.blue)),
                    const SizedBox(width: 16),
                    // RESTRICTED TOTALS: Only Administrator can see financial values
                    if (ref.watch(authStateProvider).value?.isAdministrator ?? false) ...[
                      Expanded(child: _buildSummaryCard(context, 'Inv. Value (Cost)', 'LKR ${totalCostValue.toStringAsFixed(0)}', Icons.monetization_on, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSummaryCard(context, 'Retail Value', 'LKR ${totalSalesValue.toStringAsFixed(0)}', Icons.sell, Colors.teal)),
                      const SizedBox(width: 16),
                    ],
                    Expanded(child: _buildSummaryCard(context, 'Pending POs', '$pendingPOs', Icons.pending_actions, Colors.purple)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSummaryCard(context, 'Low Stock', '$lowStock', Icons.warning_amber, Colors.orange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSummaryCard(context, 'Out of Stock', '$outOfStock', Icons.remove_shopping_cart, Colors.red)),
                  ],
                );
              },
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error loading stats: $err'),
            ),
            const SizedBox(height: 24),

            // Stock Product List
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filtered = products.where((p) => 
                    p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase()) || 
                    p.productCode.toLowerCase().contains(_searchCtrl.text.toLowerCase())
                  ).toList();

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Expanded(flex: 2, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(child: Text('Price (LKR)', style: TextStyle(fontWeight: FontWeight.bold))),
                              const Expanded(child: Text('Total Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 120, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              return InkWell(
                                onTap: () {
                                  _stockSearchCtrl.clear();
                                  // Reset filters when opening product stock
                                  setState(() {
                                    _filterSupplierId = null;
                                    _filterDesignId = null;
                                    _filterSizeId = null;
                                    _filterBatchNumber = null;
                                  });
                                  ref.read(selectedInventoryProductProvider.notifier).set(product);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: Colors.grey[200],
                                                image: product.images.isNotEmpty ? DecorationImage(image: NetworkImage(product.images.first), fit: BoxFit.cover) : null,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                  Text(product.productCode, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(child: Text(product.categoryName)),
                                      Expanded(child: Text(product.price.toStringAsFixed(2))),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              '${product.stockQuantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                color: product.stockQuantity < 10 ? Colors.red : Colors.green,
                                              ),
                                            ),
                                            if (product.stockQuantity < 10)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: Tooltip(
                                                  message: 'Low Stock',
                                                  child: Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                                                ),
                                              ),
                                          ],
                                        )
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Row(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                // Reset filters when opening product stock
                                                setState(() {
                                                  _filterSupplierId = null;
                                                  _filterDesignId = null;
                                                  _filterSizeId = null;
                                                  _filterBatchNumber = null;
                                                });
                                                ref.read(selectedInventoryProductProvider.notifier).set(product);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                backgroundColor: theme.primaryColor,
                                                foregroundColor: Colors.white
                                              ),
                                              child: const Text('Stocks'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildStockDetailView(ThemeData theme, Product product) {
    // Providers
    final stocksStream = ref.watch(stockServiceProvider).getStockForProduct(product.id!);
    final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));

    // Use a Builder to get a context that is under the Scoutfold so we can open the drawer
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: StockFilterPanel(
        productId: product.id,
        initialSupplierId: _filterSupplierId,
        initialDesignId: _filterDesignId,
        initialSizeId: _filterSizeId,
        initialBatchNumber: _filterBatchNumber,
        onApply: (supplierId, designId, sizeId, batchNumber) {
          setState(() {
            _filterSupplierId = supplierId;
            _filterDesignId = designId;
            _filterSizeId = sizeId;
            _filterBatchNumber = batchNumber;
          });
        },
        onEvaluate: (supplierId, designId, sizeId, batchNumber) {
           Navigator.pop(context); // Close Drawer
           _handleEvaluateStock(context, product, supplierId, designId, sizeId, batchNumber);
        },
        onReset: () {
          setState(() {
            _filterSupplierId = null;
            _filterDesignId = null;
            _filterSizeId = null;
            _filterBatchNumber = null;
          });
        },
      ),
      body: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Header & Controls
                 Row(
                   children: [
                     IconButton(
                       onPressed: () => ref.read(selectedInventoryProductProvider.notifier).set(null),
                       icon: const Icon(Icons.arrow_back),
                     ),
                     const SizedBox(width: 16),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text(product.name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Stock Management', style: TextStyle(color: Colors.grey[600])),
                       ],
                     ),
                     const Spacer(),
                     // Search Bar
                      SizedBox(
                        width: 250,
                        child: TextField(
                          controller: _stockSearchCtrl,
                          onChanged: (val) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search Stock ID...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Filter Button (Replaces Old Controls)
                      OutlinedButton.icon(
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                        icon: const Icon(Icons.tune), // Filter/Tune icon
                        label: const Text('Filter & Sort'),
                        style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                           foregroundColor: theme.textTheme.bodyMedium?.color,
                           side: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                     const SizedBox(width: 16),
                     OutlinedButton.icon(
                       onPressed: () {
                          showDialog(
                            context: context, 
                            builder: (context) => PurchaseOrdersListDialog(product: product),
                          );
                       },
                       icon: const Icon(Icons.shopping_basket_outlined),
                       label: const Text('Purchase Orders'),
                       style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          foregroundColor: theme.textTheme.bodyMedium?.color,
                          side: BorderSide(color: theme.dividerColor),
                       ),
                     ),
                     const SizedBox(width: 16),
                     ElevatedButton.icon(
                       onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => AddStockScreen(product: product)));
                       },
                       icon: const Icon(Icons.add),
                       label: const Text('Add Stock Batch'),
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 24),
                 
                 // Stocks List
                 Expanded(
                   child: StreamBuilder<List<StockItem>>(
                     stream: stocksStream,
                     builder: (context, snapshot) {
                       if (snapshot.connectionState == ConnectionState.waiting) {
                         return const Center(child: CircularProgressIndicator());
                       }
                       if (snapshot.hasError) {
                         return Center(child: Text('Error: ${snapshot.error}'));
                       }
                       
                       var stocks = snapshot.data ?? [];
                       
                       // Filter: Supplier
                       if (_filterSupplierId != null) {
                         stocks = stocks.where((s) => s.supplierId == _filterSupplierId).toList();
                       }

                       // Filter: Design
                       if (_filterDesignId != null) {
                         stocks = stocks.where((s) => s.designId == _filterDesignId).toList();
                       }

                       // Filter: Size
                       if (_filterSizeId != null) {
                         stocks = stocks.where((s) => s.sizeId == _filterSizeId).toList();
                       }

                       // Filter: Batch Number
                       if (_filterBatchNumber != null) {
                          stocks = stocks.where((s) => s.batchNumber.toString() == _filterBatchNumber).toList();
                       }
   
                       // Stock ID Search (Text Field)
                       if (_stockSearchCtrl.text.isNotEmpty) {
                         final query = _stockSearchCtrl.text.toLowerCase();
                         stocks = stocks.where((s) => s.id.toLowerCase().contains(query)).toList();
                       }
                       
                       // Sort
                       // Default Sort: Date Descending
                       stocks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
   
                       if (stocks.isEmpty) {
                         return Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                               const SizedBox(height: 16),
                               Text('No stock records found.', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                             ],
                           ),
                         );
                       }
   
                       return Container(
                         decoration: BoxDecoration(
                           color: theme.cardColor,
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
                         ),
                         child: Column(
                           children: [
                             Padding(
                               padding: const EdgeInsets.all(16),
                               child: Row(
                                 children: [
                                   const Expanded(flex: 2, child: Text('Stock ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Batch #', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(flex: 2, child: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const Expanded(child: Text('Design', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Buy', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Sell', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                   const SizedBox(width: 40), // Space for action
                                 ],
                               ),
                             ),
                             const Divider(height: 1),
                             Expanded(
                               child: ListView.separated(
                                 itemCount: stocks.length,
                                 separatorBuilder: (context, index) => const Divider(height: 1),
                                 itemBuilder: (context, index) {
                                   final item = stocks[index];
                                   
                                   // Get Supplier Name safely
                                   final supplierName = suppliersAsync.asData?.value
                                       .where((s) => s.id == item.supplierId)
                                       .firstOrNull?.name ?? '-';
   
                                   return InkWell(
                                     onTap: () {
                                        // TODO: Open Batch/Item Edit Dialog
                                     },
                                     child: Padding(
                                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                       child: Row(
                                         children: [
                                           Expanded(flex: 2, child: Text(item.id, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                                           Expanded(
                                           child: InkWell(
                                             onTap: () => showDialog(
                                               context: context,
                                               builder: (_) => BatchDetailDialog(product: product, batchNumber: item.batchNumber),
                                             ),
                                             child: Text(
                                               '#${item.batchNumber}',
                                               style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                             ),
                                           ),
                                         ),
                                           Expanded(flex: 2, child: Text(supplierName, overflow: TextOverflow.ellipsis)),
                                           Expanded(child: _AttributeName(provider: designsProvider, id: item.designId ?? '-')),
                                           Expanded(child: _AttributeName(provider: sizesProvider, id: item.sizeId)),
                                           Expanded(child: _AttributeName(provider: colorsProvider, id: item.colorId, isColor: true)),
                                           Expanded(child: Text(item.purchasePrice.toStringAsFixed(0))),
                                           Expanded(child: Text(item.retailPrice.toStringAsFixed(0))),
                                           Expanded(child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                           SizedBox(
                                             width: 40,
                                             child: IconButton(
                                                icon: const Icon(Icons.print, size: 18, color: Colors.grey),
                                                tooltip: 'Print Label',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => StockLabelDialog(product: product, stock: item),
                                                  );
                                                },
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   );
                                 },
                               ),
                             ),
                           ],
                         ),
                       );
                     },
                   ),
                 ),
               ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      // width: 180, // Removed fixed width for flexible Row layout
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
           BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
               Icon(icon, color: color, size: 18),
             ],
           ),
           const SizedBox(height: 12),
           Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _handleInventorySearch(String val) async {
     if (val.isEmpty) return;

     // 1. SMART SCAN: Prefix Matching for Stock IDs
     bool foundStock = false;
     final products = ref.read(productsStreamProvider).value ?? [];
     
     // Find candidate products where scanned code starts with their product code
     final candidates = products.where((p) => 
       p.productCode.isNotEmpty && val.startsWith(p.productCode)
     ).toList();
     
     // Sort by longest code first (Greedy match)
     candidates.sort((a, b) => b.productCode.length.compareTo(a.productCode.length));
     
     final stockService = ref.read(stockServiceProvider);
     
     for (final candidate in candidates) {
        try {
           final stockItem = await stockService.getStockItem(candidate.id!, val.trim());
           
           if (stockItem != null) {
              // FOUND IT! Navigate to Stock View
              ref.read(selectedInventoryProductProvider.notifier).set(candidate);
              
              // Auto-filter to the specific scanned stock ID
              _stockSearchCtrl.text = val.trim();
              _searchCtrl.clear();
              
              foundStock = true;
              setState(() {}); // Refresh to show stock view
              return; // Exit function immediately
           }
        } catch (e) { debugPrint('Error checking candidate ${candidate.name}: $e'); }
     }
     
     // 2. Fallback: Search by EXACT PRODUCT CODE
     try {
        final productMatch = await ref.read(productServiceProvider).getProductByCode(val.trim());
               
        if (productMatch != null) {
          // Found Product -> Go to Stock View (All stocks)
          ref.read(selectedInventoryProductProvider.notifier).set(productMatch);
          
          _stockSearchCtrl.clear();
          _searchCtrl.clear();
          setState(() {});
        } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No item found with Code: ${val.trim()}'), 
                  duration: const Duration(milliseconds: 1000),
                  backgroundColor: Colors.orange,
                )
              );
            }
        }
      } catch (e) { debugPrint('Scan Error: $e'); }
  }

  void _handleEvaluateStock(BuildContext context, Product product, String? supplierId, String? designId, String? sizeId, String? batchNumber) {
    showDialog(
      context: context,
      builder: (_) => StockEvaluationDialog(
        product: product,
        supplierId: supplierId,
        designId: designId,
        sizeId: sizeId,
        batchNumber: batchNumber,
      ),
    );
  }

  Future<void> _recalculateAllTotals(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final stockService = ref.read(stockServiceProvider);
      
      // Call service to recalculate everything
      final updatedCount = await stockService.recalculateInventoryTotals();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recalculated totals for $updatedCount products.')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recalculation Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _AttributeName extends ConsumerWidget {
  // Using dynamic to avoid type issues with different provider variations.
  final dynamic provider; 
  final String id;
  final bool isColor;

  const _AttributeName({required this.provider, required this.id, this.isColor = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch(provider) returns AsyncValue because the providers are StreamProviders
    final AsyncValue<dynamic> asyncValue = ref.watch(provider);

    return asyncValue.when(
      data: (items) {
        // Safe lookup avoiding firstWhere orElse return type issues on non-nullable lists.
        final List<dynamic> list = items as List<dynamic>;
        final filtered = list.where((e) => e.id == id);
        final item = filtered.isNotEmpty ? filtered.first : null;
        
        if (item == null) return Text(id.length > 4 ? id.substring(0, 4) : id);
        
        if (isColor) {
           Color color = Colors.black;
           try {
             // Using dynamic access since we don't know exact type at compile time
             String? rawHex = (item.hexCode as String?);
             String hex = (rawHex ?? '#000000').replaceAll('#', '').replaceAll('0x', '');
             if (hex.length == 6) hex = 'FF$hex';
             color = Color(int.parse(hex, radix: 16));
           } catch (_) {}

           return Row(
             children: [
               Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
               const SizedBox(width: 8),
               Text(item.name?.toString() ?? '-'),
             ],
           );
        }
        return Text(item.name?.toString() ?? '-');
      },
      loading: () => const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (err, stack) => const Text('Error', style: TextStyle(color: Colors.red, fontSize: 10)),
    );
  }
}
