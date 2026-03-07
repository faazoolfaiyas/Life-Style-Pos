import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'crud_dialog.dart';

class ProductActionPanel extends StatelessWidget {
  const ProductActionPanel({super.key});

  void _showCrudDialog(BuildContext context, String title, String itemName) {
    showDialog(
      context: context,
      builder: (context) => CrudDialog(
        title: title,
        itemName: itemName,
        initialItems: const ['Item 1', 'Item 2'], // Mock data
        onAdd: (val) {},
        onDelete: (idx) {},
        onEdit: (idx, val) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'New Product', 'color': Colors.blue, 'onTap': () {}},
      {'label': 'Categories', 'color': Colors.purple, 'onTap': () => _showCrudDialog(context, 'Categories', 'Category')},
      {'label': 'Sizes', 'color': Colors.orange, 'onTap': () => _showCrudDialog(context, 'Sizes', 'Size')},
      {'label': 'Colors', 'color': Colors.teal, 'onTap': () => _showCrudDialog(context, 'Colors', 'Color')},
      {'label': 'Designs', 'color': Colors.pink, 'onTap': () => _showCrudDialog(context, 'Designs', 'Design')},
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Actions',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ...actions.map((action) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton(
                onPressed: action['onTap'] as VoidCallback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(Theme.of(context).primaryColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: (action['color'] as Color).withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Icon(Icons.circle, size: 8, color: action['color'] as Color),
                     ),
                     const SizedBox(width: 12),
                    Text(
                      action['label'] as String,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            );
          }),
        ],
      ),
    );
  }
}
