import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/github_storage_service.dart';
import '../../data/models/product_model.dart';
import '../../data/models/attribute_models.dart';
import '../../data/services/product_service.dart';
import '../../data/providers/attribute_provider.dart';
import '../../../../core/widgets/custom_animations.dart';

class ProductFormDialog extends ConsumerStatefulWidget {
  const ProductFormDialog({super.key});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  ProductCategory? _selectedCategory;
  final List<XFile> _selectedImages = [];
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();
  final GithubStorageService _storageService = GithubStorageService();

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Show Uploading Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const CustomUploadingAnimation(message: 'Uploading to GitHub...'),
      );

      List<String> imageUrls = [];
      // Upload images
      for (var image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final url = await _storageService.uploadFile(image.name, bytes);
        imageUrls.add(url);
      }

      final productService = ref.read(productServiceProvider);
      
      final product = Product(
        productCode: '', // Will be generated
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _selectedCategory!.id!,
        categoryName: _selectedCategory!.name,
        images: imageUrls,
        createdAt: DateTime.now(),
      );

      await productService.addProduct(product);

      if (mounted) Navigator.pop(context); // Close Uploading Dialog
      if (mounted) Navigator.pop(context); // Close Form Dialog
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close Uploading Dialog if open
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: Container(
         width: 600,
         padding: const EdgeInsets.all(24),
         child: Form(
           key: _formKey,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Add New Product', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                   IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                 ],
               ),
               const SizedBox(height: 24),
               
               // Category Selection
               categoriesAsync.when(
                 data: (categories) => DropdownButtonFormField<ProductCategory>(
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
                 ),
                 loading: () => const LinearProgressIndicator(),
                 error: (err, stack) => const Text('Failed to load categories'),
               ),
               const SizedBox(height: 16),

               // Name
               TextFormField(
                 controller: _nameCtrl,
                 decoration: InputDecoration(
                   labelText: 'Product Name',
                   hintText: 'Max 12 characters',
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   // Show live character count
                   counterText: '${_nameCtrl.text.length}/12',
                   counterStyle: TextStyle(
                      color: _nameCtrl.text.length > 12 ? Colors.red : Colors.grey,
                   ),
                   errorMaxLines: 3,
                 ),
                 onChanged: (val) => setState(() {}), // Upadte counter
                 validator: (val) {
                   if (val == null || val.isEmpty) return 'Required';
                   if (val.length > 12) {
                     return 'Warning: Stock ID will hide on the label.\nCannot add product with name > 12 chars.';
                   }
                   return null;
                 },
               ),
               const SizedBox(height: 16),

               // Description
               TextFormField(
                 controller: _descCtrl,
                 decoration: InputDecoration(
                   labelText: 'Description',
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 maxLines: 3,
               ),
               const SizedBox(height: 16),

                // Note: Price is now determined by stock batches
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Price will be automatically set based on the stock batches you add later.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

               // Media Picker
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('Product Media', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 8),
                   Wrap(
                     spacing: 8,
                     runSpacing: 8,
                     children: [
                       InkWell(
                         onTap: _pickImages,
                         child: Container(
                           width: 80,
                           height: 80,
                           decoration: BoxDecoration(
                             color: Colors.grey[200],
                             borderRadius: BorderRadius.circular(8),
                             border: Border.all(color: Colors.grey[400]!),
                           ),
                           child: const Icon(Icons.add_a_photo, color: Colors.grey),
                         ),
                       ),
                       ..._selectedImages.asMap().entries.map((entry) {
                         return Stack(
                           children: [
                             Container(
                               width: 80,
                               height: 80,
                               decoration: BoxDecoration(
                                 borderRadius: BorderRadius.circular(8),
                                 image: DecorationImage(
                                     image: NetworkImage(entry.value.path), 
                                     fit: BoxFit.cover,
                                 ),
                                 color: Colors.grey[300]
                               ),
                               child: const SizedBox(), 
                             ),
                              Positioned(
                               top: 0,
                               right: 0,
                               child: InkWell(
                                 onTap: () => _removeImage(entry.key),
                                 child: const CircleAvatar(
                                   radius: 10,
                                   backgroundColor: Colors.red,
                                   child: Icon(Icons.close, size: 12, color: Colors.white),
                                 ),
                               ),
                             ),
                           ],
                         );
                       }),
                     ],
                   ),
                 ],
               ),
               
               const SizedBox(height: 24),
               ElevatedButton(
                 onPressed: _isUploading ? null : _save,
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 child: _isUploading 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : const Text('Save Product'),
               ),
             ],
           ),
         ),
       ),
    );
  }
}
