import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SocialProductFilterPanel extends ConsumerStatefulWidget {
  final String? initialCategory;
  final double? minPrice;
  final double? maxPrice;
  final bool? hasMarketingNotes; // null = all, true = with notes, false = without notes
  final String sortBy; // 'name', 'price', 'updated'
  final bool sortAsc;
  final Function({
    String? category,
    double? minPrice,
    double? maxPrice,
    bool? hasMarketingNotes,
    String sortBy,
    bool sortAsc,
  }) onApply;
  final VoidCallback onReset;

  const SocialProductFilterPanel({
    super.key,
    this.initialCategory,
    this.minPrice,
    this.maxPrice,
    this.hasMarketingNotes,
    required this.sortBy,
    required this.sortAsc,
    required this.onApply,
    required this.onReset,
  });

  @override
  ConsumerState<SocialProductFilterPanel> createState() => _SocialProductFilterPanelState();
}

class _SocialProductFilterPanelState extends ConsumerState<SocialProductFilterPanel> {
  String? _selectedCategory;
  late TextEditingController _minPriceCtrl;
  late TextEditingController _maxPriceCtrl;
  bool? _hasMarketingNotes;
  late String _sortBy;
  late bool _sortAsc;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _minPriceCtrl = TextEditingController(text: widget.minPrice?.toString() ?? '');
    _maxPriceCtrl = TextEditingController(text: widget.maxPrice?.toString() ?? '');
    _hasMarketingNotes = widget.hasMarketingNotes;
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
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _hasMarketingNotes = null;
      _sortBy = 'name';
      _sortAsc = true;
    });
    widget.onReset();
    Navigator.pop(context);
  }

  void _handleApply() {
    widget.onApply(
      category: _selectedCategory,
      minPrice: _minPriceCtrl.text.trim().isEmpty ? null : double.tryParse(_minPriceCtrl.text.trim()),
      maxPrice: _maxPriceCtrl.text.trim().isEmpty ? null : double.tryParse(_maxPriceCtrl.text.trim()),
      hasMarketingNotes: _hasMarketingNotes,
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
                    _buildSortChip('Recently Updated', 'updated', false, Icons.update),
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

                // Marketing Notes Status
                Text('Marketing Notes', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildNotesChip('All Products', null, Icons.apps),
                    _buildNotesChip('With Notes', true, Icons.note_alt_outlined),
                    _buildNotesChip('Without Notes', false, Icons.note_add_outlined),
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

  Widget _buildNotesChip(String label, bool? value, IconData icon) {
    final isSelected = _hasMarketingNotes == value;
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
          setState(() => _hasMarketingNotes = value);
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      backgroundColor: Colors.transparent,
    );
  }
}
