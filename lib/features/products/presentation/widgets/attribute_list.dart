import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/attribute_models.dart';

class AttributeList<T extends ProductAttribute> extends StatelessWidget {
  final AsyncValue<List<T>> data;
  final Function(T) onEdit;
  final Function(T) onDelete;
  final Widget Function(T)? customLeading;
  final bool isGridView;
  final String searchQuery;

  const AttributeList({
    super.key,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    this.customLeading,
    this.isGridView = false,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return data.when(
      data: (items) {
        final filteredItems = items.where((item) =>
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (item is ProductSize && item.code.toLowerCase().contains(searchQuery.toLowerCase()))
        ).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No items found', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        if (isGridView) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) => _buildGridItem(context, filteredItems[index], index),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildListItem(context, filteredItems[index], index),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildListItem(BuildContext context, T item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: customLeading != null ? customLeading!(item) : _buildDefaultLeading(context, item),
        title: Text(item.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        subtitle: _buildSubtitle(item),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('#${item.index}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => onEdit(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => onDelete(item),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (30 * index).ms).slideX();
  }

  Widget _buildGridItem(BuildContext context, T item, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text('#${item.index}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
               Row(
                 children: [
                   InkWell(onTap: () => onEdit(item), child: const Icon(Icons.edit, size: 16, color: Colors.blue)),
                   const SizedBox(width: 4),
                   InkWell(onTap: () => onDelete(item), child: const Icon(Icons.delete, size: 16, color: Colors.red)),
                 ],
               )
            ],
          ),
          Expanded(
            child: Center(
              child: customLeading != null ? customLeading!(item) : _buildDefaultLeading(context, item),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(delay: (30 * index).ms).scale();
  }

  Widget _buildDefaultLeading(BuildContext context, T item) {
     if (item is ProductColor) {
       return Container(
         width: 40,
         height: 40,
         decoration: BoxDecoration(
           color: _safeParseColor((item as ProductColor).hexCode) ?? Colors.grey,
           shape: BoxShape.circle,
           border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
         ),
       );
     }
     
     if (item is ProductSize) {
        return Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            (item as ProductSize).code,
             style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
          ),
        );
     }

     if (item is ProductCategory) {
       final cat = item as ProductCategory;
       return Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (_safeParseColor(cat.colorHex) ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
             cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
             style: TextStyle(
               color: _safeParseColor(cat.colorHex) ?? Theme.of(context).primaryColor,
               fontWeight: FontWeight.bold,
             ),
          ),
       );
     }

     return CircleAvatar(child: Text(item.name[0]));
  }

  Widget? _buildSubtitle(T item) {
    if (item is ProductSize) return Text('Sort Order: ${(item as ProductSize).sortOrder}');
    if (item is ProductCategory) return (item as ProductCategory).description != null ? Text((item as ProductCategory).description!, maxLines: 1, overflow: TextOverflow.ellipsis) : null;
    return null;
  }

  Color? _safeParseColor(String? hexCode) {
    if (hexCode == null || hexCode.isEmpty) return null;
    try {
      String cleanHex = hexCode.replaceAll('#', '').replaceAll('0x', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
