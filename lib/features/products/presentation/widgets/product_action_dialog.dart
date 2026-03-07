import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/product_model.dart';
import 'product_form_dialog.dart';
import 'purchase_orders_list_dialog.dart';

class ProductActionDialog extends StatelessWidget {
  final Product product;

  const ProductActionDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    image: product.images.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(product.images.first), fit: BoxFit.cover) 
                        : null,
                  ),
                  child: product.images.isEmpty 
                      ? Icon(Icons.inventory_2, color: Theme.of(context).primaryColor) 
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '#${product.productCode}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            _buildActionItem(
              context,
              icon: Icons.edit_outlined,
              label: 'Edit Product Details',
              onTap: () {
                Navigator.pop(context);
                // TODO: Show edit dialog (reuse ProductFormDialog with initial data)
                // For now, re-opening form as placeholder or simply just closing
                showDialog(
                  context: context,
                  builder: (context) => const ProductFormDialog(), // Ideally pass product for editing
                );
              },
            ),
             _buildActionItem(
              context,
              icon: Icons.inventory_outlined,
              label: 'Manage Stock',
              subtitle: 'Add/Remove stock, adjust prices',
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Stock Management Dialog
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock management coming soon')));
              },
            ),
             _buildActionItem(
              context,
              icon: Icons.shopping_basket_outlined,
              label: 'Purchase Orders',
              subtitle: 'Manage orders & procurements',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context, 
                  builder: (context) => PurchaseOrdersListDialog(product: product),
                );
              },
            ),
             _buildActionItem(
              context,
              icon: Icons.delete_outline,
              label: 'Delete Product',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement Delete
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete functionality coming soon')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (color ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
