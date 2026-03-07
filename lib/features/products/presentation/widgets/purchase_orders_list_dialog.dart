import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/product_model.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/services/purchase_order_service.dart';
import '../screens/create_purchase_order_screen.dart';
import 'purchase_order_detail_dialog.dart';

class PurchaseOrdersListDialog extends ConsumerWidget {
  final Product product;
  const PurchaseOrdersListDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(purchaseOrderServiceProvider).getPurchaseOrders(product.id!);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Purchase Orders', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('Manage procurement for ${product.name}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            
            // List
            Expanded(
              child: StreamBuilder<List<PurchaseOrder>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final orders = snapshot.data!;
                  
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 48, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text('No purchase orders found', style: TextStyle(color: Theme.of(context).disabledColor)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (c, i) => Divider(height: 1, color: Theme.of(context).dividerColor),
                    itemBuilder: (context, index) {
                      final po = orders[index];
                      // Calculate basic stats
                      final totalQty = po.items.fold(0, (sum, i) => sum + i.quantity);
                      final totalValue = po.items.fold(0.0, (sum, i) => sum + (i.purchasePrice ?? 0) * i.quantity);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Colors.blue),
                        ),
                        title: Text(
                          DateFormat('MMM d, yyyy  h:mm a').format(po.createdAt),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (po.note != null && po.note!.isNotEmpty)
                              Text(po.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('$totalQty items • Est. LKR ${totalValue.toStringAsFixed(0)}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () {
                          showDialog(
                            context: context, 
                            builder: (_) => PurchaseOrderDetailDialog(product: product, order: po)
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => CreatePurchaseOrderScreen(product: product)),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
