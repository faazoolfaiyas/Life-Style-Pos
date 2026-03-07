import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class PosProductFilterPanel extends ConsumerStatefulWidget {
  final String? initialCategory;
  final String? initialSize;
  final String? initialColor;
  final double? minPrice;
  final double? maxPrice;
  final String? stockStatus; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  final String sortBy; // 'name', 'price', 'stock'
  final bool sortAsc;
  final Function({
    String? category,
    String? size,
    String? color,
    double? minPrice,
    double? maxPrice,
    String? stockStatus,
    String sortBy,
    bool sortAsc,
  }) onApply;
  final VoidCallback onReset;

  const PosProductFilterPanel({
    super.key,
    this.initialCategory,
    this.initialSize,
    this.initialColor,
    this.minPrice,
    this.maxPrice,
    this.stockStatus,
    required this.sortBy,
    required this.sortAsc,
    required this.onApply,
    required this.onReset,
  });

  @override
  ConsumerState<PosProductFilterPanel> createState() => _PosProductFilterPanelState();
}

class _PosProductFilterPanelState extends ConsumerState<PosProductFilterPanel> {
  String? _selectedCategory;
  String? _selectedSize;
  String? _selectedColor;
  late TextEditingController _minPriceCtrl;
  late TextEditingController _maxPriceCtrl;
  String _stockStatus = 'all';
  late String _sortBy;
  late bool _sortAsc;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedSize = widget.initialSize;
    _selectedColor = widget.initialColor;
    _minPriceCtrl = TextEditingController(text: widget.minPrice?.toString() ?? '');
    _maxPriceCtrl = TextEditingController(text: widget.maxPrice?.toString() ?? '');
    _stockStatus = widget.stockStatus ?? 'all';
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _handleReset() {
    setState(() {
      _selectedCategory = null;
      _selectedSize = null;
      _selectedColor = null;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _stockStatus = 'all';
      _sortBy = 'name';
      _sortAsc = true;
    });
    widget.onReset();
    Navigator.pop(context);
  }

  void _handleApply() {
    widget.onApply(
      category: _selectedCategory,
      size: _selectedSize,
      color: _selectedColor,
      minPrice: _minPriceCtrl.text.trim().isEmpty ? null : double.tryParse(_minPriceCtrl.text.trim()),
      maxPrice: _maxPriceCtrl.text.trim().isEmpty ? null : double.tryParse(_maxPriceCtrl.text.trim()),
      stockStatus: _stockStatus,
      sortBy: _sortBy,
      sortAsc: _sortAsc,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 340,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Products', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Sort Section
                _buildSectionHeader('Sort By'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSortChip('Name A-Z', 'name', true, Icons.sort_by_alpha),
                    _buildSortChip('Name Z-A', 'name', false, Icons.sort_by_alpha),
                    _buildSortChip('Price Low-High', 'price', true, Icons.arrow_upward),
                    _buildSortChip('Price High-Low', 'price', false, Icons.arrow_downward),
                    _buildSortChip('Stock High-Low', 'stock', false, Icons.inventory),
                    _buildSortChip('Stock Low-High', 'stock', true, Icons.inventory_2_outlined),
                  ],
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Filters Section
                _buildSectionHeader('Filters'),
                const SizedBox(height: 16),
                
                // Price Range
                Text('Price Range', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceCtrl,
                        decoration: InputDecoration(
                          hintText: 'Min',
                          prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceCtrl,
                        decoration: InputDecoration(
                          hintText: 'Max',
                          prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Stock Status
                Text('Stock Status', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStockStatusChip('All', 'all', Icons.apps),
                    _buildStockStatusChip('In Stock', 'in_stock', Icons.check_circle_outline),
                    _buildStockStatusChip('Low Stock', 'low_stock', Icons.warning_amber_outlined),
                    _buildStockStatusChip('Out of Stock', 'out_of_stock', Icons.remove_circle_outline),
                  ],
                ),
              ],
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleReset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleApply,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
    );
  }

  Widget _buildSortChip(String label, String key, bool asc, IconData icon) {
    final isSelected = _sortBy == key && _sortAsc == asc;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = key;
            _sortAsc = asc;
          });
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildStockStatusChip(String label, String value, IconData icon) {
    final isSelected = _stockStatus == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _stockStatus = value);
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      backgroundColor: Colors.transparent,
    );
  }
}
