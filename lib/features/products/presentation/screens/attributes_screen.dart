import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers/attribute_provider.dart';
import '../../data/services/attribute_service.dart';
import '../../data/services/product_service.dart';
import '../../data/models/attribute_models.dart';
import 'package:life_style/features/products/presentation/widgets/attribute_list.dart';
import 'package:life_style/features/products/presentation/widgets/attribute_dialogs.dart';

class AttributesScreen extends ConsumerStatefulWidget {
  const AttributesScreen({super.key});

  @override
  ConsumerState<AttributesScreen> createState() => _AttributesScreenState();
}

class _AttributesScreenState extends ConsumerState<AttributesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGridView = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    final index = _tabController.index;
    showDialog(
      context: context,
      builder: (context) {
        switch (index) {
          case 0: return const CategoryFormDialog();
          case 1: return const SizeFormDialog();
          case 2: return const ColorFormDialog();
          case 3: return const DesignFormDialog();
          default: return const SizedBox();
        }
      }
    );
  }

  Future<void> _confirmDelete<T extends ProductAttribute>(T item, Function(String) deleteMethod) async {
    // Dependency Check
    if (item is ProductCategory) {
       // Show loading indicator
       showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
       
       try {
         final productService = ref.read(productServiceProvider);
         final isUsed = await productService.isCategoryUsed(item.id!);
         
         if (mounted) Navigator.pop(context); // Close loading

         if (isUsed && mounted) {
           showDialog(
             context: context,
             builder: (_) => AlertDialog(
               title: const Text('Cannot Delete'),
               content: Text('The category "${item.name}" is currently used by one or more products. Please remove the products or change their category first.'),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
               ],
             ),
           );
           return;
         }
       } catch (e) {
         if (mounted) Navigator.pop(context);
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking dependencies: $e')));
         return;
       }
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await deleteMethod(item.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final sizes = ref.watch(sizesProvider);
    final colors = ref.watch(colorsProvider);
    final designs = ref.watch(designsProvider);
    final service = ref.read(attributeServiceProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Attributes Manager', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            const SizedBox(width: 32),
            SizedBox(
              width: 350,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Sizes'),
            Tab(text: 'Colors'),
            Tab(text: 'Designs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Categories
          AttributeList<ProductCategory>(
             data: categories,
             isGridView: _isGridView,
             searchQuery: _searchCtrl.text,
             onEdit: (item) => showDialog(context: context, builder: (_) => CategoryFormDialog(initialData: item)),
             onDelete: (item) => _confirmDelete(item, service.deleteCategory),
          ),
          // Sizes
          AttributeList<ProductSize>(
             data: sizes,
             isGridView: _isGridView,
             searchQuery: _searchCtrl.text,
             onEdit: (item) => showDialog(context: context, builder: (_) => SizeFormDialog(initialData: item)),
             onDelete: (item) => _confirmDelete(item, service.deleteSize),
          ),
           // Colors
          AttributeList<ProductColor>(
             data: colors,
             isGridView: _isGridView,
             searchQuery: _searchCtrl.text,
             onEdit: (item) => showDialog(context: context, builder: (_) => ColorFormDialog(initialData: item)),
             onDelete: (item) => _confirmDelete(item, service.deleteColor),
          ),
           // Designs
          AttributeList<ProductDesign>(
             data: designs,
             isGridView: _isGridView,
             searchQuery: _searchCtrl.text,
             onEdit: (item) => showDialog(context: context, builder: (_) => DesignFormDialog(initialData: item)),
             onDelete: (item) => _confirmDelete(item, service.deleteDesign),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
