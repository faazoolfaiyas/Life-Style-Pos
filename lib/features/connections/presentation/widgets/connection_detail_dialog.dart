import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/connection_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ConnectionDetailDialog extends StatelessWidget {
  final ConnectionModel contact;

  const ConnectionDetailDialog({super.key, required this.contact});

  Future<void> _launchWhatsApp(BuildContext context, String number) async {
    var phone = number.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('0') && phone.length == 10) {
      phone = '94${phone.substring(1)}';
    } else if (phone.length == 9 && !phone.startsWith('94')) {
      phone = '94$phone';
    }
    
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Future<void> _printLabel(BuildContext context, Affiliate affiliate) async {
    final doc = pw.Document();
    
    // 35mm x 25mm page size
    // 1mm = 2.835 points approximately
    final pageFormat = PdfPageFormat(35 * PdfPageFormat.mm, 25 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Name and Vehicle
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(affiliate.name.length > 8 ? '${affiliate.name.substring(0, 8)}..' : affiliate.name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(affiliate.threewheelerNumber, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                
                // Center: Mobile
                pw.Text(
                  affiliate.whatsappNumber,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),

                // Bottom: Barcode
                pw.Container(
                  height: 25,
                  width: double.infinity,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: affiliate.id ?? 'UNKNOWN',
                    drawText: false,
                  ),
                ),
                pw.Text(affiliate.id ?? '', style: const pw.TextStyle(fontSize: 5)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Label-${affiliate.name}',
    );
  }

  // 80mm Receipt Print for Contact Details
  Future<void> _printContactDetails(BuildContext context, ConnectionModel contact) async {
    final doc = pw.Document();
    
    // 80mm width, dynamic height
    final pageFormat = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(contact.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 8),
              pw.Text(contact.whatsappNumber, style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 8),
              // Address with line break after comma
              pw.Text(
                contact.address.replaceAll(',', ',\n').replaceAll(',\n ', ',\n'),
                style: const pw.TextStyle(fontSize: 12)
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Details-${contact.name}',
    );
  }

  // 80mm Receipt Print for Bank Details
  Future<void> _printBankDetails(BuildContext context, ConnectionModel contact) async {
    List<Map<String, String>> banks = [];
    String shopName = contact.name;
    if (contact is Supplier) {
      banks = contact.bankDetails;
      shopName = contact.name; // Supplier uses name as shopName
    } else if (contact is Affiliate) {
      banks = contact.bankDetails;
    }

    if (banks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bank details to print')));
      return;
    }

    final doc = pw.Document();
    final pageFormat = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
              pw.Divider(),
              ...banks.map((bank) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(bank['bankName'] ?? 'Bank', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('Acc No: ${bank['accountNumber'] ?? ''}', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Name: ${bank['accountName'] ?? ''}', style: const pw.TextStyle(fontSize: 12)),
                      if (bank['branch'] != null && bank['branch']!.isNotEmpty)
                        pw.Text('Branch: ${bank['branch']}', style: const pw.TextStyle(fontSize: 12)),
                      pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'BankDetails-${contact.name}',
    );
  }

    // 80mm Address Label Print
  Future<void> _printAddressLabel(BuildContext context, ConnectionModel contact) async {
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 5),
                pw.Text(contact.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 5),
                pw.Text(contact.whatsappNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 10),
                pw.Text(
                  contact.address.replaceAll(',', ',\n').replaceAll(',\n ', ',\n'), // Same formatting
                  style: const pw.TextStyle(fontSize: 14),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Address-${contact.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                   Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${contact.connectionId}',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: Text(
                                 contact.type,
                                 style: TextStyle(
                                   color: Theme.of(context).primaryColor,
                                   fontWeight: FontWeight.w600,
                                   fontSize: 12,
                                 ),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(
                                 color: (contact.status == 'Active' ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: Text(
                                 contact.status,
                                 style: TextStyle(
                                   color: contact.status == 'Active' ? Colors.green : Colors.grey,
                                   fontWeight: FontWeight.w600,
                                   fontSize: 12,
                                 ),
                               ),
                             ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.print),
                    tooltip: 'Print Options',
                    onSelected: (value) {
                      switch (value) {
                        case 'details':
                          _printContactDetails(context, contact);
                          break;
                        case 'address':
                          _printAddressLabel(context, contact);
                          break;
                        case 'bank':
                          _printBankDetails(context, contact);
                          break;
                        case 'label':
                          if (contact is Affiliate) _printLabel(context, contact as Affiliate);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Print Details (80mm)'),
                      ),
                      const PopupMenuItem(
                         value: 'address',
                         child: Text('Print Address Label'),
                      ),
                      if ((contact is Supplier && (contact as Supplier).bankDetails.isNotEmpty) || (contact is Affiliate && (contact as Affiliate).bankDetails.isNotEmpty))
                        const PopupMenuItem(
                          value: 'bank',
                          child: Text('Print Bank Details'),
                        ),
                      if (contact is Affiliate)
                        const PopupMenuItem(
                          value: 'label',
                          child: Text('Print Sticker Label'),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Core Info
                    _buildSectionHeader(context, 'Contact Information', Icons.contact_phone),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'Phone', contact.whatsappNumber, icon: FontAwesomeIcons.whatsapp, isLink: true, onTap: () => _launchWhatsApp(context, contact.whatsappNumber)),
                    if (contact.email != null && contact.email!.isNotEmpty)
                       _buildInfoRow(context, 'Email', contact.email!, icon: Icons.email),
                    if (contact.address.isNotEmpty)
                       _buildInfoRow(
                         context, 
                         'Address', 
                         contact.address, 
                         icon: Icons.location_on,
                         showCopy: true,
                       ),
                    
                    // Connection Specifics
                    if (contact is Supplier) ...[
                       const SizedBox(height: 24),
                       _buildSectionHeader(context, 'Supplier Details', Icons.store),
                       const SizedBox(height: 16),
                       if ((contact as Supplier).ownerName != null && (contact as Supplier).ownerName!.isNotEmpty)
                          _buildInfoRow(context, 'Owner Name', (contact as Supplier).ownerName!, icon: Icons.person),
                       
                       if ((contact as Supplier).bankDetails.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Bank Accounts', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          ...(contact as Supplier).bankDetails.map((bank) => _buildBankCard(context, bank)),
                       ],
                    ],

                    if (contact is Affiliate) ...[
                        const SizedBox(height: 24),
                       _buildSectionHeader(context, 'Vehicle Details', Icons.directions_car),
                       const SizedBox(height: 16),
                       if ((contact as Affiliate).threewheelerNumber.isNotEmpty)
                         _buildInfoRow(context, 'Threewheeler No.', (contact as Affiliate).threewheelerNumber, icon: Icons.numbers),
                       
                        if ((contact as Affiliate).bankDetails.isNotEmpty) ...[
                           const SizedBox(height: 16),
                           Text('Bank Accounts', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                           const SizedBox(height: 8),
                           ...(contact as Affiliate).bankDetails.map((bank) => _buildBankCard(context, bank)),
                        ],
                    ],

                    // Social Media (Supplier & Reseller)
                     if ((contact is Supplier && (contact as Supplier).socialMedia.isNotEmpty) || (contact is Reseller && (contact as Reseller).socialMedia.isNotEmpty)) ...[
                        const SizedBox(height: 24),
                       _buildSectionHeader(context, 'Social Media', Icons.share),
                       const SizedBox(height: 16),
                       const SizedBox(height: 16),
                       Column(
                         children: getSocials(contact).map((social) => _buildSocialChip(context, social)).toList(),
                       ),
                     ],

                     if (contact.description != null && contact.description!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(context, 'Notes', Icons.notes),
                        const SizedBox(height: 8),
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.grey.withValues(alpha: 0.05),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(contact.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
                         ),
                     ],
                     
                     const SizedBox(height: 24),
                     Center(
                       child: Column(
                         children: [
                           Text(
                             'Created on ${DateFormat('MMM dd, yyyy').format(contact.createdAt)}',
                             style: TextStyle(color: Colors.grey[400], fontSize: 12),
                           ),
                           if (contact.updatedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                   'Last Updated: ${DateFormat('MMM dd, yyyy • hh:mm a').format(contact.updatedAt!)}',
                                   style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                         ],
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  List<Map<String, String>> getSocials(ConnectionModel contact) {
    if (contact is Supplier) return contact.socialMedia;
    if (contact is Reseller) return contact.socialMedia;
    return [];
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {IconData? icon, bool isLink = false, VoidCallback? onTap, bool showCopy = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 12),
           ],
           SizedBox(
             width: 100,
             child: Text(
               label,
               style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
             ),
           ),
           Expanded(
             child: GestureDetector(
               onTap: isLink ? onTap : null,
               child: Text(
                 value,
                 style: GoogleFonts.outfit(
                   fontWeight: FontWeight.w600,
                   color: isLink ? Theme.of(context).primaryColor : Theme.of(context).colorScheme.onSurface,
                   decoration: isLink ? TextDecoration.underline : null,
                   decorationColor: Theme.of(context).primaryColor,
                 ),
               ),
             ),
           ),
           if (showCopy)
             IconButton(
               icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
               constraints: const BoxConstraints(),
               padding: const EdgeInsets.only(left: 8),
               tooltip: 'Copy $label',
               onPressed: () {
                 Clipboard.setData(ClipboardData(text: value));
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $label')));
               },
             ),
        ],
      ),
    );
  }
  
  Widget _buildBankCard(BuildContext context, Map<String, String> bank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bank['bankName'] ?? 'Bank',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  if (bank['branch'] != null && bank['branch']!.isNotEmpty)
                   Text(
                     bank['branch']!,
                     style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                   ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_all, color: Colors.white, size: 18),
                    tooltip: 'Copy All Details',
                    onPressed: () {
                      final text = '''
Bank: ${bank['bankName']}
Account Number: ${bank['accountNumber']}
Account Name: ${bank['accountName']}
Branch: ${bank['branch'] ?? ''}
''';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied all bank details')));
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bank['accountNumber'] ?? '0000 0000 0000',
                style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 18, letterSpacing: 2),
              ),
               IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bank['accountNumber'] ?? ''));
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied Account Number')));
                  },
               ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                 bank['accountName']?.toUpperCase() ?? '',
                 style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, letterSpacing: 1),
              ),
              IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: bank['accountName'] ?? ''));
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied Account Name')));
                  },
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialChip(BuildContext context, Map<String, String> social) {
    final platform = social['platform'] ?? 'Link';
    final url = social['link'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                 if (await canLaunchUrl(Uri.parse(url))) {
                   await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                 } else {
                   if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch link')));
                   }
                 }
              },
              icon: Icon(_getSocialIcon(platform), size: 16),
              label: Text(platform, overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                elevation: 0,
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy Link',
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              ),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $platform link'), 
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getSocialIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('facebook') || p.contains('fb')) return FontAwesomeIcons.facebook;
    if (p.contains('instagram') || p.contains('insta')) return FontAwesomeIcons.instagram;
    if (p.contains('twitter') || p.contains('x')) return FontAwesomeIcons.twitter;
    if (p.contains('linkedin')) return FontAwesomeIcons.linkedin;
    if (p.contains('tiktok')) return FontAwesomeIcons.tiktok;
    if (p.contains('youtube')) return FontAwesomeIcons.youtube;
    return Icons.link;
  }
}
