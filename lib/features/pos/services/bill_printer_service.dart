import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/bill_model.dart';
import '../../settings/data/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'logo_loader.dart'; // Added

class BillPrinterService {
  final Bill bill;
  final AppSettings settings;
  // Resolved Preference: Bill Override > Settings Default
  late final bool showProductDiscount;

  BillPrinterService(this.bill, this.settings) {
    showProductDiscount = bill.showProductDiscount ?? settings.showProductDiscount;
  }

  Future<void> printBill() async {
    final doc = pw.Document();
    
    // Preload Logo
    final Uint8List? logoBytes = await loadLogo(settings.logoPath);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.only(left: 2, right: 25, top: 5, bottom: 5), // Adjusted left margin per user request
        build: (pw.Context context) {
          return _buildLayout(context, logoBytes);
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Bill-${bill.billNumber}',
    );
  }

  pw.Widget _buildLayout(pw.Context context, Uint8List? logoBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildHeader(logoBytes),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        _buildBillInfo(),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        _buildItems(),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 4),
        _buildSummary(),
        pw.SizedBox(height: 8),
        _buildFooter(),
      ],
    );
  }

  pw.Widget _buildHeader(Uint8List? logoBytes) {
    pw.Widget? logoWidget;
    if (logoBytes != null) {
       final image = pw.MemoryImage(logoBytes);
       logoWidget = pw.Container(
         height: 45,
         alignment: pw.Alignment.center,
         child: pw.Image(image, fit: pw.BoxFit.contain),
       );
    }

    return pw.Column(
      children: [
        // Centered Header
        if (logoWidget != null) ...[
          logoWidget,
          pw.SizedBox(height: 4),
        ],
        if (logoWidget == null)
           pw.Center(child: pw.Text('LIFE STYLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
           
        if (settings.billAddress.isNotEmpty)
          pw.Center(child: pw.Text(settings.billAddress, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
          
        if (bill.customerName != null && bill.customerName!.isNotEmpty)
          pw.Center(child: pw.Text('Customer: ${bill.customerName}', style: const pw.TextStyle(fontSize: 9))),
      ],
    );
  }

  pw.Widget _buildBillInfo() {
     return pw.Row(
       mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
       crossAxisAlignment: pw.CrossAxisAlignment.center,
       children: [
         // Left Column: Bill # and Timestamp
         pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
               pw.Text('Bill #${bill.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
               pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(bill.createdAt), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ]
         ),
         
         // Right: Barcode
         pw.Container(
           height: 20,
           width: 60,
           child: pw.BarcodeWidget(
             barcode: pw.Barcode.code128(),
             data: bill.billNumber,
             drawText: false,
           ),
         ),
       ],
     );
  }

  pw.Widget _buildItems() {
    final soldItems = bill.items.where((i) => i.quantity > 0).toList();
    final returnedItems = bill.items.where((i) => i.quantity < 0).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (soldItems.isNotEmpty) ...[
          _buildItemTable(soldItems, title: null),
        ],
        
        if (returnedItems.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Returns / Exchanges', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          _buildItemTable(returnedItems, isReturn: true),
        ]
      ]
    );
  }

  pw.Widget _buildItemTable(List<BillItem> items, {String? title, bool isReturn = false}) {
    final List<pw.Widget> rows = [];
    
    // Header
    rows.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            if (showProductDiscount)
               pw.Expanded(flex: 2, child: pw.Text('Disc', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
            pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
          ],
        )
      )
    );

    for (var item in items) {
        final List<String> variants = [];
        String vText = '';
        if (item.selectedColor != null && item.selectedColor!.contains(' - ')) {
           final parts = item.selectedColor!.split(' - ');
           if (parts.length == 2) {
              vText = '${parts[1]} ${item.selectedSize ?? ""} ${parts[0]}';
           } else {
              vText = '${item.selectedSize ?? ""} ${item.selectedColor ?? ""}';
           }
        } else {
           vText = '${item.selectedSize ?? ""} ${item.selectedColor ?? ""}';
        }
        
        // Show absolute values for returns to make it cleaner, or keep negative?
        // Usually returns are shown as negative.
        final double lineTotal = showProductDiscount ? item.total : (item.price * item.quantity);
        final String priceStr = item.price.toStringAsFixed(0);
        final String discStr = item.discount > 0 ? '-${item.discount.toStringAsFixed(0)}' : '-';

        rows.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
               crossAxisAlignment: pw.CrossAxisAlignment.start,
               children: [
                 pw.Expanded(
                   flex: 4, 
                   child: pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       pw.Text(item.productName, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                       if (vText.trim().isNotEmpty)
                          pw.Text(vText.trim(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                     ]
                   )
                 ),
                 pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                 pw.Expanded(flex: 2, child: pw.Text(priceStr, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                 if (showProductDiscount)
                    pw.Expanded(flex: 2, child: pw.Text(discStr, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
                 pw.Expanded(flex: 2, child: pw.Text(lineTotal.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
               ],
            )
          )
        );
    }
    return pw.Column(children: rows);
  }

   pw.Widget _buildSummary() {
    final int totalItems = bill.items.length;
    final int totalQty = bill.items.fold(0, (sum, item) => sum + item.quantity.abs()); // Show volume count
    
    // Calculate values
    double displayedSubTotal = bill.subTotal;
    
    double globalDiscountAmount = 0.0;
    if (showProductDiscount) {
       final double totalItemDiscounts = bill.items.fold(0.0, (sum, i) => sum + i.discount);
       globalDiscountAmount = bill.discount - totalItemDiscounts;
       if (globalDiscountAmount < 0.01) globalDiscountAmount = 0.0;
    }

    final children = <pw.Widget>[];

    // 1. Total Items / Qty
    children.add(
      pw.Row(
         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
         children: [
            pw.Text('Total Items: $totalItems', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Total Qty: $totalQty', style: const pw.TextStyle(fontSize: 8)),
         ]
      )
    );
    children.add(pw.SizedBox(height: 2));
    children.add(pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed));
    children.add(pw.SizedBox(height: 2));

    // 2. Subtotal
    children.add(_row('Subtotal', displayedSubTotal));
    
    // 3. Discount
    if (showProductDiscount) {
        if (globalDiscountAmount > 0) children.add(_row('Global Discount', -globalDiscountAmount));
    } else {
        if (bill.discount > 0) children.add(_row('Total Discount', -bill.discount));
    }

    // 4. Tax
    if (bill.tax > 0) children.add(_row('Tax', bill.tax));
            
    children.add(pw.SizedBox(height: 6));
    
    // 5. Net Total
    children.add(
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('NET TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.Text('LKR ${bill.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      )
    );
    
    // 6. Payment & Balance
    final double received = bill.receivedAmount ?? bill.totalAmount;
    // Calculate balance based on received vs total
    final double balance = received - bill.totalAmount;
    final bool isPartialOrDebt = balance < -0.01;
    final bool isExact = balance.abs() < 0.01;
    
    pw.Widget paymentRow;
    
    if (isPartialOrDebt) {
        // Underpayment (Debt/Credit)
        // Show Deduction for the unpaid amount?
        // User requested: "if user entered a less amount than the total add the difference amount as - to the deductions"
        final double adjustment = balance; // This is negative
        
        // However, "Deduction" usually implies reducing the Total.
        // If we adjust the bill, the Total matches the Received.
        // But here we are just printing Summary.
        // Let's print:
        // Paid: [Received]
        // Balance/Due: [Negative Balance]
        
        paymentRow = pw.Column(
          children: [
             _row('Paid via ${bill.paymentMethod}', received),
             _row('Balance / Due', balance, isBold: true),
          ]
        );
    } else {
       // Check for Split Payment (Card + Cash)
       if (bill.paymentMethod == 'Card' && bill.splitCashAmount != null && bill.splitCashAmount! > 0) {
          // Split Payment Layout
          final cardPaid = bill.splitCardAmount ?? (received - bill.splitCashAmount!);
          final cashPaid = bill.splitCashAmount!;
          
          paymentRow = pw.Column(
            children: [
              _row('Payment Method', 0, textValue: 'Split (Card + Cash)'),
              _row('  - Card', cardPaid),
              _row('  - Cash', cashPaid),
              // Optional: Show Total Paid if wanted, but subtotal is already there.
            ]
          );
       } else {
           // Standard Payment Layout
           if (isExact) {
              paymentRow = _row('Paid via ${bill.paymentMethod}', received);
           } else {
              paymentRow = pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                     pw.Text('Paid (${bill.paymentMethod})', style: const pw.TextStyle(fontSize: 8)),
                     pw.Row(
                       children: [
                          pw.Text(received.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 8),
                          pw.Text('|', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                          pw.SizedBox(width: 8),
                          pw.Text('Bal: ${balance.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                       ]
                     )
                  ]
                )
              );
           }
       }
    }

    children.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: paymentRow));

    return pw.Column(children: children);
  }

  pw.Widget _row(String label, double amount, {String? textValue, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            textValue ?? amount.toStringAsFixed(2), 
            style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)
          ),
        ],
      )
    );
  }

  pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (settings.whatsappLink.isNotEmpty) 
           pw.Column(
             children: [
               pw.BarcodeWidget(
                 barcode: pw.Barcode.qrCode(),
                 data: settings.whatsappLink,
                 width: 30, // Reduced size
                 height: 30,
               ),
               if (settings.whatsappLinkLabel.isNotEmpty) ...[
                 pw.SizedBox(height: 2),
                 pw.Text(settings.whatsappLinkLabel, style: const pw.TextStyle(fontSize: 6)),
               ]
             ]
           ),
           
        pw.Spacer(),
        
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
             pw.Text(settings.billFooterText, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
             pw.SizedBox(height: 2),
             pw.Text('Software by Antigravity', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
          ],
        )
      ]
    );
  }
}
