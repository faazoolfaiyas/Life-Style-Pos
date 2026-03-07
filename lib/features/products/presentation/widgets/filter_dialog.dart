import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 500);
  bool? _inStock;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            // Category Dropdown
            Text('Category', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: ['Men', 'Women', 'Kids', 'Accessories']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            
            // Price Range
            Text('Price Range: \$${_priceRange.start.toInt()} - \$${_priceRange.end.toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            RangeSlider(
              values: _priceRange,
              min: 0,
              max: 1000,
              divisions: 20,
              labels: RangeLabels('\$${_priceRange.start.toInt()}', '\$${_priceRange.end.toInt()}'),
              onChanged: (val) => setState(() => _priceRange = val),
            ),
            const SizedBox(height: 16),
            
            // Stock Status
            Text('Stock Status', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('In Stock'),
                    // ignore: deprecated_member_use
                    value: true,
                    // ignore: deprecated_member_use
                    groupValue: _inStock,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setState(() => _inStock = val),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Out of Stock'),
                    // ignore: deprecated_member_use
                    value: false,
                    // ignore: deprecated_member_use
                    groupValue: _inStock,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setState(() => _inStock = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
