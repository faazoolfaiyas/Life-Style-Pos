import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/product_model.dart';
import '../../data/models/attribute_models.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/services/product_service.dart';
import '../../../../core/services/github_storage_service.dart';
import '../../../../core/widgets/custom_animations.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../screens/inventory_screen.dart';
import 'product_history_tab.dart';
import 'purchase_orders_list_dialog.dart';

class ProductManagementDialog extends ConsumerStatefulWidget {
  final Product product;
  const ProductManagementDialog({super.key, required this.product});

  @override
  ConsumerState<ProductManagementDialog> createState() => _ProductManagementDialogState();
}

class _ProductManagementDialogState extends ConsumerState<ProductManagementDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  
  ProductCategory? _selectedCategory;
  List<String> _currentImages = [];
  final List<XFile> _newImages = [];
  bool _isSaving = false;
  bool _isDeleting = false;

  final GithubStorageService _storageService = GithubStorageService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nameCtrl = TextEditingController(text: widget.product.name);
    _descCtrl = TextEditingController(text: widget.product.description);
    _currentImages = List.from(widget.product.images);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images);
      });
    }
  }

  void _removeCurrentImage(int index) {
    setState(() {
      _currentImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      if (_selectedCategory == null) {
          // Ideally selected in UI or keeps original if null. Logic below handles fallback.
      }

      // Upload new images
      if (_newImages.isNotEmpty) {
         showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const CustomUploadingAnimation(message: 'Uploading new images...'),
        );
        
        for (var image in _newImages) {
          final bytes = await image.readAsBytes();
          final url = await _storageService.uploadFile(image.name, bytes);
          _currentImages.add(url);
        }
        if (mounted) Navigator.pop(context);
      }

      final updatedProduct = Product(
        id: widget.product.id,
        productCode: widget.product.productCode,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _selectedCategory?.id ?? widget.product.categoryId,
        categoryName: _selectedCategory?.name ?? widget.product.categoryName,
        images: _currentImages,
        // Preserve existing calculated prices
        price: widget.product.price,
        minPrice: widget.product.minPrice,
        maxPrice: widget.product.maxPrice,
        stockQuantity: widget.product.stockQuantity, 
        createdAt: widget.product.createdAt,
        updatedAt: DateTime.now(),
        isActive: widget.product.isActive,
      );

      final productService = ref.read(productServiceProvider);
      await productService.updateProduct(updatedProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.product.name}"? This cannot be undone.'),
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

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
       final productService = ref.read(productServiceProvider);
       await productService.deleteProduct(widget.product.id!);
       if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
       }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: SizedBox(
         width: 700,
         height: 600,
         child: Column(
           children: [
             // Header
             Padding(
               padding: const EdgeInsets.all(24),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Manage Product',
                         style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                       ),
                       Text(
                         '#${widget.product.productCode}',
                         style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                       ),
                     ],
                   ),
                   Row(
                     children: [
                        if (_isSaving || _isDeleting)
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                        if (!_isSaving && !_isDeleting) ...[
                          IconButton.filledTonal(
                             onPressed: _deleteProduct,
                             icon: const Icon(Icons.delete_outline, color: Colors.red),
                             tooltip: 'Delete Product',
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => Navigator.pop(context), 
                            icon: const Icon(Icons.close),
                          ),
                        ]
                     ],
                   ),
                 ],
               ),
             ),
             
             // Tabs
             TabBar(
               controller: _tabController,
               labelColor: Theme.of(context).primaryColor,
               unselectedLabelColor: Colors.grey,
               indicatorSize: TabBarIndicatorSize.label,
               tabs: const [
                 Tab(icon: Icon(Icons.edit_note), text: 'Details'),
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory'),
                  Tab(icon: Icon(Icons.image_outlined), text: 'Media'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                ],
              ),
             
             Expanded(
               child: Form(
                 key: _formKey,
                 child: TabBarView(
                   controller: _tabController,
                   children: [
                     // Details Tab
                     Padding(
                       padding: const EdgeInsets.all(24),
                       child: ListView(
                         children: [
                            categoriesAsync.when(
                               data: (categories) {
                                 if (_selectedCategory == null) {
                                   try {
                                     _selectedCategory = categories.firstWhere((c) => c.id == widget.product.categoryId);
                                   } catch (_) {}
                                 }
                                 
                                 return DropdownButtonFormField<ProductCategory>(
                                   decoration: InputDecoration(
                                     labelText: 'Category',
                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                   ),
                                   value: _selectedCategory,
                                   items: categories.where((c) => c.isActive).map((c) => DropdownMenuItem(
                                     value: c,
                                     child: Text(c.name),
                                   )).toList(),
                                   onChanged: (val) => setState(() => _selectedCategory = val),
                                   validator: (v) => v == null ? 'Required' : null,
                                 );
                               },
                               loading: () => const LinearProgressIndicator(),
                               error: (err, stack) => const Text('Failed to load categories'),
                             ),
                             const SizedBox(height: 16),
                             TextFormField(
                               controller: _nameCtrl,
                               decoration: InputDecoration(
                                 labelText: 'Product Name',
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                               ),
                               validator: (v) => v!.isEmpty ? 'Required' : null,
                             ),
                             const SizedBox(height: 16),
                             TextFormField(
                               controller: _descCtrl,
                               decoration: InputDecoration(
                                 labelText: 'Description',
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                               ),
                               maxLines: 4,
                             ),
                              const SizedBox(height: 16),
                              
                              // Price Display Info
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.payments_outlined, color: Theme.of(context).primaryColor, size: 20),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Current Price Range', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        Text(
                                          widget.product.minPrice == widget.product.maxPrice
                                              ? 'LKR ${widget.product.price.toStringAsFixed(2)}'
                                              : 'LKR ${widget.product.minPrice.toStringAsFixed(0)} - LKR ${widget.product.maxPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                         ],
                       ),
                     ),
                     
                     // Inventory Tab (Updated)
                     Padding(
                        padding: const EdgeInsets.all(24),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                     Container(
                                       padding: const EdgeInsets.all(24),
                                       decoration: BoxDecoration(
                                         color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                         shape: BoxShape.circle,
                                       ),
                                       child: Icon(Icons.inventory_2, size: 48, color: Theme.of(context).primaryColor),
                                     ),
                                     const SizedBox(height: 24),
                                     Text(
                                       'Total Stock Quantity',
                                       style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                     ),
                                     const SizedBox(height: 8),
                                     Text(
                                       '${widget.product.stockQuantity}',
                                       style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold),
                                     ),
                                     const SizedBox(height: 32),
                                     SizedBox(
                                       width: 250,
                                       child: ElevatedButton.icon(
                                         onPressed: () {
                                            ref.read(selectedInventoryProductProvider.notifier).set(widget.product);
                                            ref.read(dashboardProvider.notifier).setIndex(6); // Inventory index
                                            Navigator.pop(context);
                                         },
                                         icon: const Icon(Icons.launch),
                                         label: const Text('Manage Detailed Stock'),
                                         style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                         ),
                                       ),
                                     ),
                                     const SizedBox(height: 12),
                                     SizedBox(
                                       width: 250,
                                       child: OutlinedButton.icon(
                                         onPressed: () {
                                            showDialog(
                                              context: context, 
                                              builder: (context) => PurchaseOrdersListDialog(product: widget.product),
                                            );
                                         },
                                         icon: const Icon(Icons.shopping_basket_outlined),
                                         label: const Text('Manage Purchase Orders'),
                                         style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                         ),
                                       ),
                                     ),
                                     const SizedBox(height: 16),
                                     const Text(
                                       'Manage batches, suppliers, and stock adjustments in the dedicated Inventory section.',
                                       textAlign: TextAlign.center,
                                       style: TextStyle(color: Colors.grey, fontSize: 13),
                                     ),
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                     ),
                     
                     // Media Tab
                     Padding(
                       padding: const EdgeInsets.all(24),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Add Images'),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: _currentImages.length + _newImages.length,
                                itemBuilder: (context, index) {
                                  if (index < _currentImages.length) {
                                    final url = _currentImages[index];
                                    final isVideo = url.toLowerCase().contains('.mp4') || url.toLowerCase().contains('.mov') || url.toLowerCase().contains('.webm');
                                    
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: isVideo 
                                            ? Container(
                                                color: Colors.black12,
                                                child: const Center(child: Icon(Icons.play_circle_fill, size: 32, color: Colors.white70)),
                                              )
                                            : Image.network(url, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.broken_image)),
                                        ),
                                        Positioned(
                                          top: 4, right: 4,
                                          child: InkWell(
                                            onTap: () => _removeCurrentImage(index),
                                            child: const CircleAvatar(
                                              radius: 12, backgroundColor: Colors.red,
                                              child: Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    final newIndex = index - _currentImages.length;
                                     final file = _newImages[newIndex];
                                     final isVideo = file.name.toLowerCase().endsWith('.mp4') || file.name.toLowerCase().endsWith('.mov');

                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                         Opacity(
                                           opacity: 0.7,
                                           child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: isVideo
                                                ? Container(color: Colors.black12, child: const Center(child: Icon(Icons.movie)))
                                                : Image.network(file.path, fit: BoxFit.cover, errorBuilder: (c,o,s) => const Icon(Icons.image)),
                                           ),
                                         ),
                                         const Center(child: Icon(Icons.upload, color: Colors.white, size: 30, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                                         Positioned(
                                          top: 4, right: 4,
                                          child: InkWell(
                                            onTap: () => _removeNewImage(newIndex),
                                            child: const CircleAvatar(
                                              radius: 12, backgroundColor: Colors.red,
                                              child: Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ),
                           ],
                       ),
                     ),

                     // History Tab
                     ProductHistoryTab(productId: widget.product.id!),
                   ],
                 ),
               ),
             ),
             
             // Actions
             Padding(
               padding: const EdgeInsets.all(24),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   OutlinedButton(
                     onPressed: _isSaving ? null : () => Navigator.pop(context),
                     child: const Text('Cancel'),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     onPressed: _isSaving ? null : _saveChanges,
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                     ),
                     child: _isSaving 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                       : const Text('Save Changes'),
                   ),
                 ],
               ),
             ),
           ],
         ),
       ),
    );
  }
}
