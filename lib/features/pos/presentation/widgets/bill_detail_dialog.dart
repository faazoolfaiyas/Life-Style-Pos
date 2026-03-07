import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/bill_model.dart';
import '../../services/bill_printer_service.dart';
import 'package:intl/intl.dart';
import '../../../settings/data/providers/settings_provider.dart';

class BillDetailDialog extends ConsumerStatefulWidget {
  final Bill bill;

  const BillDetailDialog({super.key, required this.bill});

  @override
  ConsumerState<BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends ConsumerState<BillDetailDialog> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill Details', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('#${widget.bill.billNumber}', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 32),
            
            // Info Grid
            Row(
              children: [
                Expanded(child: _buildInfo('Date', DateFormat('MMM d, y HH:mm').format(widget.bill.createdAt))),
                Expanded(child: _buildInfo('Customer', widget.bill.customerName ?? 'Walk-in')),
                Expanded(child: _buildInfo('Payment', widget.bill.paymentMethod)),
                Expanded(child: _buildInfo('Status', widget.bill.status, isStatus: true)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Items List
            Text('Items', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(0),
                  itemCount: widget.bill.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = widget.bill.items[index];
                    // Insert category header if needed (using same logic as Cart)
                    final currentCategory = item.categoryName;
                    final prevCategory = index > 0 ? widget.bill.items[index - 1].categoryName : null;
                    final showHeader = index == 0 || currentCategory != prevCategory;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showHeader)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            color: Colors.grey[100],
                            child: Text(
                              currentCategory.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ),
                        ListTile(
                          dense: true,
                          title: Text(item.productName),
                          subtitle: Text([item.selectedSize, item.selectedColor].whereType<String>().join(' • ')),
                          trailing: Text('${item.quantity} x ${item.price.toStringAsFixed(0)} = ${item.total.toStringAsFixed(0)}'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Totals
            _buildTotalRow('Subtotal', widget.bill.subTotal),
            if (widget.bill.discount > 0) _buildTotalRow('Discount', -widget.bill.discount, isDiscount: true),
            const Divider(),
            _buildTotalRow('Total', widget.bill.totalAmount, isBold: true),
            
            // Split Payment Details
            if (widget.bill.paymentMethod == 'Card' && widget.bill.splitCashAmount != null && widget.bill.splitCashAmount! > 0) ...[
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                 child: Column(
                   children: [
                     Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                       Text('Paid via Card:', style: TextStyle(fontSize: 12, color: Colors.blue[800])),
                       Text('LKR ${(widget.bill.splitCardAmount ?? 0).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                     ]),
                     Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                       Text('Paid via Cash:', style: TextStyle(fontSize: 12, color: Colors.green[800])),
                       Text('LKR ${widget.bill.splitCashAmount!.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
                     ]),
                   ],
                 ),
               )
            ],
            
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Logic to share or email
                    }, 
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : () async {
                      setState(() => _isPrinting = true);
                      try {
                        final settings = ref.read(settingsProvider).value ?? const AppSettings();
                        final printer = BillPrinterService(widget.bill, settings);
                        await printer.printBill();
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Error: $e')));
                      } finally {
                         if (mounted) setState(() => _isPrinting = false);
                      }
                    }, 
                    icon: _isPrinting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.print),
                    label: Text(_isPrinting ? 'Printing...' : 'Print Receipt (80mm)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value, {bool isStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        isStatus 
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[800])),
          )
        : Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: isBold ? 18 : 14, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal
          )),
          Text(
            amount.toStringAsFixed(2), 
            style: TextStyle(
              fontSize: isBold ? 18 : 14, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.red : null,
            )
          ),
        ],
      ),
    );
  }
}
