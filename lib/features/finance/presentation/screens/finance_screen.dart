import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../pos/data/services/pos_service.dart';
import '../../../pos/data/models/bill_model.dart';

final pendingCostBillsProvider = StreamProvider.autoDispose<List<Bill>>((ref) {
  return ref.watch(posServiceProvider).getPendingCostBills();
});

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingCostBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Finance & Pending Costs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: pendingAsync.when(
        data: (bills) {
          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Colors.green)
                      .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  Text('All Quick Sales have Cost Prices assigned.',
                      style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey[700])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final pendingItems = bill.items.where((i) => i.productId == 'TEMP-001' && (i.costPrice == null || i.costPrice == 0.0)).toList();

              if (pendingItems.isEmpty) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bill #${bill.billNumber}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...pendingItems.map((item) => _buildPendingItemRow(context, ref, bill.id, item)),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildPendingItemRow(BuildContext context, WidgetRef ref, String billId, BillItem item) {
    final costCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Sold for: LKR ${item.price.toStringAsFixed(2)} x ${item.quantity}', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: TextField(
              controller: costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Cost (LKR)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: () async {
              final cost = double.tryParse(costCtrl.text);
              if (cost != null && cost >= 0) {
                try {
                  await ref.read(posServiceProvider).updateQuickSaleCost(billId, item.productId, cost);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cost updated'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
