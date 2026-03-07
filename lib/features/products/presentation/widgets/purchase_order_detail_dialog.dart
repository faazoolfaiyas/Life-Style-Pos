import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/attribute_models.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_order_model.dart';
import '../../data/providers/attribute_provider.dart';

import '../../../connections/services/connection_service.dart';
import '../screens/create_purchase_order_screen.dart';

class PurchaseOrderDetailDialog extends ConsumerWidget {
  final Product product;
  final PurchaseOrder order;

  const PurchaseOrderDetailDialog({
    super.key,
    required this.product,
    required this.order,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve helper data (Sizes, Colors, Supplier)
    // We can use providers. Since we are in a dialog, we assume providers are alive.
    final sizes = ref.read(sizesProvider).asData?.value ?? [];
    final colors = ref.read(colorsProvider).asData?.value ?? [];
    final designs = ref.read(designsProvider).asData?.value ?? [];
    
    // Resolve supplier name if ID exists
    String supplierName = 'Unknown / None';
    if (order.supplierId != null) {
       final suppliersAsync = ref.watch(streamConnectionProvider('Supplier'));
       if (suppliersAsync.hasValue) {
         final s = suppliersAsync.value!.where((s) => s.id == order.supplierId).firstOrNull;
         if (s != null) supplierName = s.name;
       }
    }

    // Helper to resolve names
    String getSize(String id) => sizes.where((s) => s.id == id).firstOrNull?.code ?? '?';
    String getColor(String id) => colors.where((s) => s.id == id).firstOrNull?.name ?? '?';
    String getDesign(String? id) => id == null ? '-' : (designs.where((d) => d.id == id).firstOrNull?.name ?? '?');

    double grandTotal = 0;
    int totalQty = 0;
    for (var item in order.items) {
      grandTotal += (item.purchasePrice ?? 0) * item.quantity;
      totalQty += item.quantity;
    }

    // Sort Items: Design -> Size -> Color
    List<PurchaseOrderItem> sortedItems = List.from(order.items);
    sortedItems.sort((a, b) {
       // 1. Design
       final dB = designs.where((d) => d.id == b.designId).firstOrNull?.index ?? 0;
       final dA = designs.where((d) => d.id == a.designId).firstOrNull?.index ?? 0;
       if (dA != dB) return dA.compareTo(dB);
       
       // 2. Size
       final sA = sizes.where((s) => s.id == a.sizeId).firstOrNull?.index ?? 0;
       final sB = sizes.where((s) => s.id == b.sizeId).firstOrNull?.index ?? 0;
       if (sA != sB) return sA.compareTo(sB);
       
       // 3. Color
       final cA = colors.where((c) => c.id == a.colorId).firstOrNull?.index ?? 0;
       final cB = colors.where((c) => c.id == b.colorId).firstOrNull?.index ?? 0;
       return cA.compareTo(cB);
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Theme.of(context).cardColor,
      child: Container(
        width: 500,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Summary', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Meta Info
            _buildMetaRow('Product:', product.name, context),
            _buildMetaRow('Date:', DateFormat('MMM d, yyyy h:mm a').format(order.createdAt), context),
            _buildMetaRow('Supplier:', supplierName, context),
            if (order.note != null) _buildMetaRow('Note:', order.note!, context),

            const SizedBox(height: 24),
            Text('Items', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                   Expanded(flex: 2, child: Text('Design', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   Expanded(flex: 1, child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   Expanded(flex: 2, child: Text('Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                   Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Table Content
            Expanded(
              child: ListView.separated(
                itemCount: sortedItems.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = sortedItems[index];
                  // final totalParams = '${getDesign(item.designId)} / ${getSize(item.sizeId)} / ${getColor(item.colorId)}';
                  final lineTotal = (item.purchasePrice ?? 0) * item.quantity;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(getDesign(item.designId), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 1, child: Text(getSize(item.sizeId), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text(getColor(item.colorId), style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text(item.purchasePrice?.toStringAsFixed(2) ?? '-', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text(lineTotal.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$totalQty Items', style: TextStyle(fontSize: 12, color: Theme.of(context).disabledColor)),
                      Text('LKR ${grandTotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Theme.of(context).primaryColor)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _printReceipt(product, order, supplierName, sizes, colors, designs);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close detail
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePurchaseOrderScreen(product: product, orderToEdit: order)));
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Order'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    Product product, 
    PurchaseOrder order, 
    String supplierName,
    List<ProductSize> sizes,
    List<ProductColor> colors,
    List<ProductDesign> designs,
  ) async {
    final pdf = pw.Document();
    
    // Functions for PDF context
    String pSize(String id) => sizes.where((s) => s.id == id).firstOrNull?.code ?? '?';
    String pColor(String id) => colors.where((s) => s.id == id).firstOrNull?.name ?? '?';
    String pDesign(String? id) => id == null ? '-' : (designs.where((d) => d.id == id).firstOrNull?.name ?? '?');

    // 80mm roll width. Height is irrelevant for rollback (continuous), but page format usually needs some height.
    // Use roll80 constant if available or custom.
    // PdfPageFormat.roll80 is 80mm width, infinite height.
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Life Style', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Purchase Order', style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),
              
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ]),
              pw.SizedBox(height: 2),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Supplier:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(supplierName, style: pw.TextStyle(fontSize: 8)),
              ]),
              pw.SizedBox(height: 2),
               pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Product:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(product.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
              ]),
              
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),

              // Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Design', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 1, child: pw.Text('Size', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text('Color', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 1, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  pw.Expanded(flex: 1, child: pw.Text('Amt', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                ],
              ),
              pw.SizedBox(height: 4),

              // Sorting for Print
              ...() {
                List<PurchaseOrderItem> printItems = List.from(order.items);
                printItems.sort((a, b) {
                   final dB = designs.where((d) => d.id == b.designId).firstOrNull?.index ?? 0;
                   final dA = designs.where((d) => d.id == a.designId).firstOrNull?.index ?? 0;
                   if (dA != dB) return dA.compareTo(dB);
                   
                   final sA = sizes.where((s) => s.id == a.sizeId).firstOrNull?.index ?? 0;
                   final sB = sizes.where((s) => s.id == b.sizeId).firstOrNull?.index ?? 0;
                   if (sA != sB) return sA.compareTo(sB);
                   
                   final cA = colors.where((c) => c.id == a.colorId).firstOrNull?.index ?? 0;
                   final cB = colors.where((c) => c.id == b.colorId).firstOrNull?.index ?? 0;
                   return cA.compareTo(cB);
                });
                return printItems.map((item) {
                   final total = (item.purchasePrice ?? 0) * item.quantity;
                   return pw.Container(
                     margin: const pw.EdgeInsets.only(bottom: 2),
                     child: pw.Row(
                      children: [
                        pw.Expanded(flex: 2, child: pw.Text(pDesign(item.designId), style: const pw.TextStyle(fontSize: 7), tightBounds: true)),
                        pw.Expanded(flex: 1, child: pw.Text(pSize(item.sizeId), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(flex: 2, child: pw.Text(pColor(item.colorId), style: const pw.TextStyle(fontSize: 8))),
                        
                        pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(flex: 1, child: pw.Text((item.purchasePrice ?? 0).toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(flex: 1, child: pw.Text(total.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      ],
                    ),
                   );
                });
              }(),

              pw.Divider(thickness: 0.5),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('Total Qty:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                   pw.Text('${order.items.fold(0, (s, i) => s + i.quantity)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                   pw.Text(
                     'LKR ${order.items.fold(0.0, (s, i) => s + (i.purchasePrice ?? 0) * i.quantity).toStringAsFixed(2)}', 
                     style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)
                   ),
                ],
              ),
              
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('*** End of Order ***', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'PO_${order.id}',
    );
  }
}
