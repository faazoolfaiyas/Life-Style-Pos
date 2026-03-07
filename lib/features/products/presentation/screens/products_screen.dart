import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/filter_dialog.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/product_management_dialog.dart';
import '../../data/models/product_model.dart';
import '../../data/providers/product_providers.dart';
import '../../data/providers/attribute_provider.dart';
import '../../../../core/widgets/custom_animations.dart';
import '../../data/services/stock_service.dart';
import '../../../settings/data/providers/settings_provider.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => const FilterDialog(),
    );
  }

  void _showManagementDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductManagementDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettings();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Product List Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Products Inventory',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().fadeIn().slideX(begin: -0.1),
                        const SizedBox(width: 32),
                        // Search
                        SizedBox(
                          width: 400,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [                        
                        // Add Product Button
                        FilledButton.icon(
                          onPressed: () {
                             showDialog(
                               context: context,
                               builder: (context) => const ProductFormDialog(),
                             );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                        ),
                        const SizedBox(width: 8),

                        // Sync Button (Migration Tool)
                        IconButton(
                          onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing design search data...')));
                              try {
                                 final count = await ref.read(stockServiceProvider).reindexProductDesigns();
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                     content: Text('Sync Complete! Updated $count products.'), 
                                     backgroundColor: Colors.green
                                   ));
                                 }
                              } catch (e) {
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync Failed: $e'), backgroundColor: Colors.red));
                                 }
                              }
                          },
                          icon: const Icon(Icons.sync),
                          tooltip: 'Sync Design Search',
                        ),
                        const SizedBox(width: 8),

                        // Filter Button
                        IconButton.filledTonal(
                          onPressed: _showFilterDialog,
                          icon: const Icon(Icons.filter_list),
                          tooltip: 'Filter',
                        ),
                        const SizedBox(width: 8),
                        
                        // View Switcher
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => setState(() => _isGridView = false),
                                icon: Icon(Icons.list, color: !_isGridView ? Theme.of(context).primaryColor : Colors.grey),
                                tooltip: 'List View',
                              ),
                              IconButton(
                                onPressed: () => setState(() => _isGridView = true),
                                icon: Icon(Icons.grid_view, color: _isGridView ? Theme.of(context).primaryColor : Colors.grey),
                                tooltip: 'Grid View',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Product List/Grid
                Expanded(
                  child: productsAsync.when(
                    data: (allProducts) {
                      // Filter Products
                      final designs = ref.watch(designsProvider).value ?? [];
                      
                      final products = allProducts.where((p) {
                         final query = _searchQuery.trim();
                         if (query.isEmpty) return true;
                         
                         // Determine matching design IDs from query
                         final matchingDesignIds = designs
                             .where((d) => d.name.toLowerCase().contains(query))
                             .map((d) => d.id!)
                             .toList();

                         return p.name.toLowerCase().contains(query) ||
                                p.productCode.toLowerCase().contains(query) ||
                                p.categoryName.toLowerCase().contains(query) ||
                                (p.description?.toLowerCase().contains(query) ?? false) ||
                                p.designIds.any((id) => matchingDesignIds.contains(id));
                      }).toList();

                      if (products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                               const SizedBox(height: 16),
                               Text('No products found', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        );
                      }
                      return _isGridView ? _buildGridView(products, settings) : _buildListView(products);
                    },
                    loading: () => const CustomLoadingAnimation(message: 'Loading Inventory...'),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return InkWell(
          onTap: () => _showManagementDialog(product),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                 color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                     image: product.images.isNotEmpty ? DecorationImage(image: NetworkImage(product.images.first), fit: BoxFit.cover) : null,
                  ),
                  child: product.images.isEmpty ? Icon(FontAwesomeIcons.shirt, color: Theme.of(context).primaryColor) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Category: ${product.categoryName} • #${product.productCode}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.minPrice == product.maxPrice 
                        ? 'LKR ${product.price.toStringAsFixed(2)}'
                        : 'LKR ${product.minPrice.toStringAsFixed(0)} - LKR ${product.maxPrice.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor),
                    ),
                    Text(
                      'Stock: ${product.stockQuantity}',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showManagementDialog(product),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1);
      },
    );
  }

  Widget _buildGridView(List<Product> products, AppSettings settings) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: settings.productCardSize, // Dynamic Card Size
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final scale = settings.productTextScale; // Dynamic Text Scale

        return InkWell(
          onTap: () => _showManagementDialog(product),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                 color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
              ),
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
                      borderRadius: BorderRadius.circular(12),
                      image: product.images.isNotEmpty ? DecorationImage(image: NetworkImage(product.images.first), fit: BoxFit.cover) : null,
                    ),
                     child: product.images.isEmpty ? Icon(FontAwesomeIcons.shirt, size: 48 * scale, color: Theme.of(context).primaryColor) : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.name,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16 * scale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.categoryName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12 * scale),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                 Text(
                  '#${product.productCode}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11 * scale),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        product.minPrice == product.maxPrice
                          ? 'LKR ${product.price.toStringAsFixed(0)}'
                          : 'LKR ${product.minPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15 * scale, color: Theme.of(context).primaryColor),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, size: 20 * scale),
                      onPressed: () => _showManagementDialog(product),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).scale();
      },
    );
  }
}
