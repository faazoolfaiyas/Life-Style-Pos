import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/data/providers/product_providers.dart';
import '../../../settings/data/providers/settings_provider.dart';
import '../../../products/data/models/product_model.dart';
import 'social_product_card.dart';
import 'content_creator_modal.dart';

class SocialProductList extends ConsumerStatefulWidget {
  const SocialProductList({super.key});

  @override
  ConsumerState<SocialProductList> createState() => _SocialProductListState();
}

class _SocialProductListState extends ConsumerState<SocialProductList> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Column(
      children: [
        // Search Bar
        TextField(
          controller: _searchCtrl,
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search products by name or code...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear), 
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    }
                  ) 
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
        const SizedBox(height: 24),

        // Grid
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final filtered = products.where((p) => 
                p.isActive && // Only active products
                (p.name.toLowerCase().contains(_searchQuery) || 
                 p.productCode.toLowerCase().contains(_searchQuery))
              ).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'No products found.' : 'No matches found.',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                );
              }

              final settings = ref.watch(settingsProvider).value ?? const AppSettings();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: settings.productCardSize,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  return SocialProductCard(
                    product: product,
                    onGenerate: () => _openContentCreator(context, product),
                  );
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

  void _openContentCreator(BuildContext context, Product product) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing when clicking outside
      builder: (context) => ContentCreatorModal(product: product),
    );
  }
}
