import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../connections/services/connection_service.dart';
import '../../../connections/data/models/connection_model.dart';
import '../../data/providers/attribute_provider.dart';
import '../../data/models/attribute_models.dart';

class StockFilterPanel extends ConsumerStatefulWidget {
  final String? productId; // Filter suppliers by product stock
  final String? initialSupplierId;
  final String? initialDesignId;
  final String? initialSizeId;
  final String? initialBatchNumber;
  final Function(String? supplierId, String? designId, String? sizeId, String? batchNumber) onApply;
  final Function(String? supplierId, String? designId, String? sizeId, String? batchNumber) onEvaluate;
  final VoidCallback onReset;

  const StockFilterPanel({
    super.key,
    this.productId,
    this.initialSupplierId,
    this.initialDesignId,
    this.initialSizeId,
    this.initialBatchNumber,
    required this.onApply,
    required this.onEvaluate,
    required this.onReset,
  });

  @override
  ConsumerState<StockFilterPanel> createState() => _StockFilterPanelState();
}

class _StockFilterPanelState extends ConsumerState<StockFilterPanel> {
  String? _selectedSupplierId;
  String? _selectedDesignId;
  String? _selectedSizeId;
  late TextEditingController _batchCtrl;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.initialSupplierId;
    _selectedDesignId = widget.initialDesignId;
    _selectedSizeId = widget.initialSizeId;
    _batchCtrl = TextEditingController(text: widget.initialBatchNumber);
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    super.dispose();
  }

  void _handleReset() {
    setState(() {
      _selectedSupplierId = null;
      _selectedDesignId = null;
      _selectedSizeId = null;
      _batchCtrl.clear();
    });
    widget.onReset();
    Navigator.pop(context);
  }

  void _handleApply() {
    widget.onApply(
      _selectedSupplierId,
      _selectedDesignId, 
      _selectedSizeId,
      _batchCtrl.text.trim().isEmpty ? null : _batchCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  void _handleEvaluate() {
     widget.onEvaluate(
      _selectedSupplierId,
      _selectedDesignId, 
      _selectedSizeId,
      _batchCtrl.text.trim().isEmpty ? null : _batchCtrl.text.trim(),
    );
     // Do not pop, show logic might be handled by parent or a dialog
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));
    final designsAsync = ref.watch(designsProvider);
    final sizesAsync = ref.watch(sizesProvider);

    return Drawer(
      width: 320,
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
                Text('Filters', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 24),

                // Filters Section
                _buildSectionHeader('Filters'),
                const SizedBox(height: 16),
                
                // Batch Number
                Text('Batch Number', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                TextField(
                  controller: _batchCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. 104',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 20),

                // Design
                Text('Design', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                designsAsync.when(
                  data: (designs) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedDesignId,
                          hint: const Text('Select Design'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Designs')),
                            ...designs.where((d) => d.isActive).map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedDesignId = val),
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error loading designs: $err', style: const TextStyle(color: Colors.red)),
                ),

                const SizedBox(height: 20),

                // Size
                Text('Size', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                sizesAsync.when(
                  data: (sizes) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedSizeId,
                          hint: const Text('Select Size'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Sizes')),
                            ...sizes.where((s) => s.isActive).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedSizeId = val),
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error loading sizes: $err', style: const TextStyle(color: Colors.red)),
                ),

                const SizedBox(height: 20),

                // Supplier
                Text('Supplier', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                const SizedBox(height: 8),
                suppliersAsync.when(
                  data: (suppliers) {
                    // Cast to specific type if needed or just use ConnectionModel
                    final supplierItems = suppliers.cast<ConnectionModel>();
                    
                    return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedSupplierId,
                        hint: const Text('Select Supplier'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Suppliers')),
                          ...supplierItems.where((s) => s.id != null).map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedSupplierId = val),
                      ),
                    ),
                  );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, __) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Failed to load suppliers: ${error.toString()}',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          
          // Evaluate Button
          Container(
             padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
             color: theme.cardColor,
             width: double.infinity,
             child: OutlinedButton.icon(
                onPressed: _handleEvaluate,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Evaluate Stock'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.primaryColor),
                  foregroundColor: theme.primaryColor,
                ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2));
  }
}
