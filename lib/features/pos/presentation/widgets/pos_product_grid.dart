import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../features/products/data/providers/product_providers.dart';
import '../../../../features/products/data/models/product_model.dart';
import '../../../../features/products/data/models/attribute_models.dart';
import '../../data/providers/pos_provider.dart';
import '../../../../features/products/data/services/stock_service.dart';
import '../../../../features/products/data/services/product_service.dart';
import '../../../../features/products/data/services/attribute_service.dart';
import '../../../../features/settings/data/providers/settings_provider.dart';
import '../../../../features/products/data/providers/attribute_provider.dart';
import 'stock_selection_dialog.dart';

// Top-level providers to ensure stable streams
// Top-level providers to ensure stable streams
// Attribute Providers are now imported from product_providers.dart

class PosProductGrid extends ConsumerStatefulWidget {
  const PosProductGrid({super.key});

  @override
  ConsumerState<PosProductGrid> createState() => _PosProductGridState();
}

class _PosProductGridState extends ConsumerState<PosProductGrid> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
         // Clear cart selection when user is searching/scanning
         ref.read(cartSelectionProvider.notifier).clearSelection();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider); 

    // Listen for focus requests from keyboard shortcuts (F1, Escape)
    ref.listen<int>(searchFocusRequestProvider, (prev, next) {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });

    
    // Fetch attributes using stable providers
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final designsAsync = ref.watch(designsProvider);

    // Create Lookup Maps
    final sizeMap = { for (var s in sizesAsync.value ?? []) s.id!: s };
    final colorMap = { for (var c in colorsAsync.value ?? []) c.id!: c };
    final designMap = { for (var d in designsAsync.value ?? []) d.id!: d };

    return Column(
        children: [
          // 1. Search Bar & Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Scan Stock ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.toLowerCase());
                    },
                    // SCANNING LOGIC MOVED TO onSubmitted (ENTER KEY)
                    onSubmitted: (rawVal) async {
                      final val = rawVal.trim();
                      if (val.isEmpty) return;

                      // 1. SMART SCAN: Prefix Matching for Stock IDs
                      bool foundStock = false;
                      // Fetch current data synchronously from cache/provider state if possible, 
                      // or wait for the async value.
                      final products = productsAsync.value ?? [];
                      
                       // Find candidate products where scanned code starts with their product code
                       final candidates = products.where((p) => 
                         p.productCode.isNotEmpty && val.toLowerCase().startsWith(p.productCode.toLowerCase())
                       ).toList();
                       
                       // Sort by longest code first (Greedy match)
                       candidates.sort((a, b) => b.productCode.length.compareTo(a.productCode.length));
                       
                       final stockService = ref.read(stockServiceProvider);
                       
                       for (final candidate in candidates) {
                          try {
                             // Use EXACT MATCH for the Stock ID part now?
                             // User said "look for exact id match". 
                             // getStockItem logic checks if stockId == suffix.
                             // We pass the FULL scanned string as 'stockId' argument to getStockItem usually?
                             // Actually getStockItem(productId, stockId) implementation needs check.
                             // Assuming getStockItem handles the logic of finding the stock based on the ID.
                             final stockItem = await stockService.getStockItem(candidate.id!, val.trim());
                             
                             if (stockItem != null) {
                                // FOUND IT!
                                final sizeCode = sizeMap[stockItem.sizeId]?.code ?? stockItem.sizeId;
                                final colorName = colorMap[stockItem.colorId]?.name ?? stockItem.colorId;
                                final designName = designMap[stockItem.designId]?.name ?? '';
                                
                                final variantDetail = designName.isNotEmpty ? '$colorName - $designName' : colorName;

                                ref.read(cartProvider.notifier).addToCart(
                                  candidate,
                                  size: sizeCode,
                                  color: variantDetail,
                                  stockId: stockItem.id, 
                                  price: stockItem.retailPrice,
                                );
                                
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                foundStock = true;
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ${candidate.name} ($sizeCode)'), 
                                      backgroundColor: Colors.green, duration: const Duration(milliseconds: 1000)
                                    )
                                  );
                                }
                                _searchFocusNode.requestFocus();
                                break; 
                             }
                          } catch (e) { print('Error checking candidate ${candidate.name}: $e'); }
                       }
                       
                       if (foundStock) return; 

                       // 2. Fallback: Search by EXACT PRODUCT CODE
                       try {
                          final productMatch = await ref.read(productServiceProvider).getProductByCode(val.trim());
                                 
                          if (productMatch != null) {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => StockSelectionDialog(product: productMatch),
                              ).then((_) {
                                _searchFocusNode.requestFocus();
                              });
                            }
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
                        } catch (e) { print('Scan Error: $e'); }
                    },
                  ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => _showCategoryFilter(context),
                icon: Icon(Icons.filter_list, color: _selectedCategory != null ? Theme.of(context).primaryColor : null),
              ),
            ],
          ),
        ),

        // 2. Product Grid
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final designs = designsAsync.value ?? [];
              
              final filtered = products.where((p) {
                // Find designs matching the query
                final matchingDesignIds = designs
                     .where((d) => d.name.toLowerCase().contains(_searchQuery))
                     .map((d) => d.id!)
                     .toList();

                final matchesSearch = p.name.toLowerCase().contains(_searchQuery) ||
                    p.productCode.toLowerCase().contains(_searchQuery) ||
                    p.categoryName.toLowerCase().contains(_searchQuery) ||
                    (p.description?.toLowerCase().contains(_searchQuery) ?? false) ||
                    p.designIds.any((id) => matchingDesignIds.contains(id));
                    
                final matchesCategory = _selectedCategory == null || p.categoryId == _selectedCategory;
                return matchesSearch && matchesCategory;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              final settings = ref.watch(settingsProvider).value ?? const AppSettings(); // Get Settings

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: settings.productCardSize, // Use setting
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(context, filtered[index], index, settings.productTextScale);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, int index, double textScale) {
    return InkWell(
      onTap: () {
        // Show Stock Selection Dialog
        showDialog(
          context: context,
          builder: (context) => StockSelectionDialog(product: product),
        ).then((_) {
           // Refocus on search bar when returning from dialog
           _searchFocusNode.requestFocus();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  image: product.images.isNotEmpty 
                      ? DecorationImage(image: NetworkImage(product.images.first), fit: BoxFit.cover) 
                      : null,
                ),
                child: product.images.isEmpty 
                    ? Icon(FontAwesomeIcons.shirt, size: 32, color: Theme.of(context).primaryColor) 
                    : null,
              ),
            ),
                  Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    product.name,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13 * textScale),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LKR ${product.price.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 13 * textScale),
                  ),
                  Text(
                    'Stock: ${product.stockQuantity}',
                          style: TextStyle(fontSize: 10 * textScale, color: product.stockQuantity > 0 ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (20 * index).ms).scale();
  }
  void _showCategoryFilter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Category', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, _) {
              final categoriesAsync = ref.watch(categoriesProvider);
              return categoriesAsync.when(
                data: (categories) {
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('All Categories'),
                        leading: _selectedCategory == null ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
                        onTap: () {
                          setState(() => _selectedCategory = null);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(),
                      ...categories.map((cat) => ListTile(
                        title: Text(cat.name),
                        leading: _selectedCategory == cat.id ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
                        onTap: () {
                          setState(() => _selectedCategory = cat.id);
                          Navigator.pop(context);
                        },
                      )),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error: $e'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
