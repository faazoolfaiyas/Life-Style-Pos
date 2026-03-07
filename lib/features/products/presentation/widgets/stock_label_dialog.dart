import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stock_model.dart';
import '../../data/providers/attribute_provider.dart';

class StockLabelDialog extends ConsumerStatefulWidget {
  final Product product;
  final StockItem stock;

  const StockLabelDialog({super.key, required this.product, required this.stock});

  @override
  ConsumerState<StockLabelDialog> createState() => _StockLabelDialogState();
}

class _StockLabelDialogState extends ConsumerState<StockLabelDialog> {
  late TextEditingController _copiesCtrl;
  
  // Cache attribute names
  String _sizeName = '';
  String _colorName = '';

  @override
  void initState() {
    super.initState();
    _copiesCtrl = TextEditingController(text: widget.stock.quantity.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAttributes();
  }

  Future<void> _loadAttributes() async {
    // We need to resolve the size and color names from providers/lists
    // Note: In a dialog, providers might typically already be loaded or we can watch them.
    // For simplicity, we'll try to find them in the current provider state.
    
    final sizes = ref.read(sizesProvider).asData?.value ?? [];
    final colors = ref.read(colorsProvider).asData?.value ?? [];

    final size = sizes.where((s) => s.id == widget.stock.sizeId).firstOrNull;
    final color = colors.where((c) => c.id == widget.stock.colorId).firstOrNull;

    setState(() {
      _sizeName = size?.name ?? '';
      _colorName = color?.name ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey.keyLabel == 'Enter') {
          _printLabels();
        }
      },
      child: Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Print Stock Labels', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Preview Section (35mm x 25mm)
              Text('Preview (35mm x 25mm)', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 280, 
                  height: 200, // 35:25 ratio approx
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // MAIN CONTENT: QR + PRODUCT INFO
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // LEFT: QR CODE
                            Container(
                              width: 65,
                              height: 65,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: BarcodeWidget(
                                barcode: Barcode.qrCode(),
                                data: widget.stock.id,
                                drawText: false,
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // RIGHT: PRODUCT INFO
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Name
                                  Text(
                                    widget.product.name.toUpperCase(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Price
                                  Text(
                                    'Rs. ${widget.stock.retailPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  
                                  // Stock ID
                                  Text(
                                    widget.stock.id,
                                    style: GoogleFonts.barlowCondensed(
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // FOOTER: BRAND + SIZE/COLOR
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'LIFE STYLE',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '$_sizeName - $_colorName',
                              style: GoogleFonts.barlowCondensed(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              TextField(
                controller: _copiesCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Number of Copies',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.copy),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _printLabels,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Labels'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printLabels() async {
    final pdf = pw.Document();
    final count = int.tryParse(_copiesCtrl.text) ?? 1;
    final format = PdfPageFormat(35 * PdfPageFormat.mm, 25 * PdfPageFormat.mm);

    // Load custom fonts
    final fontRegular = await PdfGoogleFonts.barlowCondensedRegular();
    final fontBold = await PdfGoogleFonts.barlowCondensedBold();

    for (int i = 0; i < count; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          orientation: pw.PageOrientation.landscape,
          margin: const pw.EdgeInsets.all(0.6 * PdfPageFormat.mm),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.7, color: PdfColors.black),
                borderRadius: pw.BorderRadius.circular(2),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(1.5 * PdfPageFormat.mm),
              child: pw.Column(
                children: [
                  // MAIN CONTENT: QR + PRODUCT INFO
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // LEFT: QR CODE
                        pw.Container(
                          width: 15 * PdfPageFormat.mm,
                          height: 15 * PdfPageFormat.mm,
                          padding: const pw.EdgeInsets.all(0.5 * PdfPageFormat.mm),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 0.3, color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(1),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: widget.stock.id,
                            drawText: false,
                          ),
                        ),
                        
                        pw.SizedBox(width: 2 * PdfPageFormat.mm),
                        
                        // RIGHT: PRODUCT INFO
                        pw.Expanded(
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.start,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Product Name
                              pw.Text(
                                widget.product.name.toUpperCase(),
                                maxLines: 2,
                                overflow: pw.TextOverflow.clip,
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  font: fontBold,
                                  height: 1.1,
                                ),
                              ),
                              pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
                              
                              // Price
                              pw.Text(
                                'Rs. ${widget.stock.retailPrice.toStringAsFixed(0)}',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  font: fontBold,
                                  height: 1.0,
                                ),
                              ),
                              pw.SizedBox(height: 0.3 * PdfPageFormat.mm),
                              
                              // Stock ID
                              pw.Text(
                                widget.stock.id,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  font: fontRegular,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(height: 1 * PdfPageFormat.mm),
                  
                  // FOOTER: BRAND + SIZE/COLOR
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 0.6 * PdfPageFormat.mm, horizontal: 1 * PdfPageFormat.mm),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'LIFE STYLE',
                          style: pw.TextStyle(
                            fontSize: 7,
                            font: fontBold,
                          ),
                        ),
                        pw.Text(
                          '$_sizeName - $_colorName',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: fontBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'StockLabel_${widget.stock.id}',
    );
    
    // Close the dialog after print is initiated
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
