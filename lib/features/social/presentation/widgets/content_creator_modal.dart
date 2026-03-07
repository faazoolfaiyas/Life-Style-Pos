import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:url_launcher/url_launcher.dart'; // Ensure this is available

import '../../../products/data/models/product_model.dart';
import '../../../products/data/models/stock_model.dart';
import '../../../products/data/models/attribute_models.dart';
import '../../../products/data/services/stock_service.dart';
import '../../../products/data/providers/attribute_provider.dart';
import '../../data/constants/marketing_templates.dart';
import '../../data/models/social_settings_model.dart';
import '../../utils/marketing_engine.dart';
import 'social_settings_dialog.dart';
import '../../../settings/data/providers/settings_provider.dart'; // Added AppSettings Provider

class ContentCreatorModal extends ConsumerStatefulWidget {
  final Product product;
  const ContentCreatorModal({super.key, required this.product});

  @override
  ConsumerState<ContentCreatorModal> createState() => _ContentCreatorModalState();
}

class _ContentCreatorModalState extends ConsumerState<ContentCreatorModal> {
  // State
  MarketingTemplate _selectedTemplate = MarketingTemplates.all.first;
  bool _showInstagram = true;
  bool _showWebsite = true;
  bool _showContact = true;
  final TextEditingController _customLinkCtrl = TextEditingController();
  final TextEditingController _aiPromptCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  
  late List<String> _marketingNotes; // Local state for notes
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _aiPromptCtrl.text = widget.product.aiImagePrompt ?? '';
    _marketingNotes = List.from(widget.product.marketingNotes);
    // Initial generation will happen when data loads
  }

  @override
  Widget build(BuildContext context) {
    // 1. Data Fetching
    final stocksAsync = ref.watch(stockStreamProvider(widget.product.id!));
    final sizesAsync = ref.watch(sizesProvider);
    final colorsAsync = ref.watch(colorsProvider);
    final settingsAsync = ref.watch(socialSettingsProvider);
    final appSettingsAsync = ref.watch(settingsProvider); // Fetch AppSettings

    // 2. Data Handling
    // We expect these providers to have data because they are eager loaded or cached.
    // If they are calling, we show a spinner.
    
    // 2. Non-Blocking Data Handling
    // Instead of blocking the whole UI, we check if we are loading to show a subtle indicator, but we render the UI regardless.
    final bool isSyncing = stocksAsync.isLoading || sizesAsync.isLoading || colorsAsync.isLoading || settingsAsync.isLoading || appSettingsAsync.isLoading;
    
    // Safely get values (defaults to empty/initial if loading/error)
    final stocks = stocksAsync.value ?? [];
    final sizes = sizesAsync.value ?? [];
    final colors = colorsAsync.value ?? [];
    final settings = settingsAsync.value ?? const SocialSettings();
    final appSettings = appSettingsAsync.value ?? const AppSettings(); // Get AppSettings

    // 3. Auto-Generate Logic
    // We use a post-frame callback or simple check to trigger generation once data is available.
    if (_isGenerating && !isSyncing) {
       // Using Future.microtask to avoid setState during build
       Future.microtask(() {
         if (mounted && _contentCtrl.text.isEmpty) {
           _generate(stocks, sizes, colors, settings, appSettings);
           setState(() => _isGenerating = false);
         }
       });
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 900),
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            if (isSyncing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Row(
                children: [
            // LEFT PANEL: Controls (40%)
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Content Studio', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      
                      // Template Selector
                      Text('Select Template', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<MarketingTemplate>(
                            value: _selectedTemplate,
                            isExpanded: true,
                            items: MarketingTemplates.all.map((t) => DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Text(t.icon),
                                  const SizedBox(width: 8),
                                  Text(t.label),
                                ],
                              ),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedTemplate = val);
                                _generate(stocks, sizes, colors, settings, appSettings);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toggles
                      Text('Include Links', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _buildSwitch('Instagram Profile', _showInstagram, (v) {
                        setState(() => _showInstagram = v);
                        _generate(stocks, sizes, colors, settings, appSettings);
                      }),
                      _buildSwitch('Website Link', _showWebsite, (v) {
                        setState(() => _showWebsite = v);
                        _generate(stocks, sizes, colors, settings, appSettings);
                      }),
                      _buildSwitch('Contact Signature', _showContact, (v) {
                        setState(() => _showContact = v);
                        _generate(stocks, sizes, colors, settings, appSettings);
                      }),

                      const SizedBox(height: 24),

                      // Saved Notes (New)
                      if (_marketingNotes.isNotEmpty) ...[
                        Text('Saved Marketing Notes', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: const Text('Load a saved note...'),
                              isExpanded: true,
                              items: _marketingNotes.map((note) {
                                final preview = note.replaceAll('\n', ' ').substring(0, note.length > 30 ? 30 : note.length);
                                return DropdownMenuItem(
                                  value: note,
                                  child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                     _contentCtrl.text = val;
                                     _isGenerating = false; // Stop auto-regen until reset
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Custom Link
                      Text('Custom Link Override (Optional)', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customLinkCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Specific Item URL',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) => _generate(stocks, sizes, colors, settings, appSettings),
                      ),

                      const SizedBox(height: 32),
                      
                      // AI Prompt
                       Text('AI Image Prompt Saved', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                       const SizedBox(height: 8),
                       TextField(
                         controller: _aiPromptCtrl,
                         maxLines: 3,
                         decoration: InputDecoration(
                           hintText: 'Prompt used for generation...',
                           fillColor: Colors.white,
                           filled: true,
                           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                           suffixIcon: IconButton(
                             icon: const Icon(Icons.save),
                             onPressed: () => _saveAiPrompt(widget.product.id!, _aiPromptCtrl.text),
                             tooltip: 'Save Prompt to Product',
                           ),
                         ),
                       ),
                    ],
                  ),
                ),
              ),
            ),

            // RIGHT PANEL: Preview & Actions (60%)
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text('Message Preview', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                         IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECE5DD), // WhatsApp-like BG
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _contentCtrl,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                          decoration: const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _saveNote(widget.product.id!),
                            icon: const Icon(Icons.save_as_outlined),
                            label: const Text('Save Note'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _contentCtrl.text));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to Clipboard!')));
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _sendToWhatsapp(settings),
                            icon: const Icon(FontAwesomeIcons.whatsapp),
                            label: const Text('Send to WhatsApp'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool val, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: val,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeTrackColor: Theme.of(context).primaryColor,
    );
  }

  void _generate(List<StockItem> stocks, List<ProductSize> sizes, List<ProductColor> colors, SocialSettings settings, AppSettings appSettings) {
    setState(() {
      _contentCtrl.text = MarketingEngine.generateContent(
        product: widget.product,
        stocks: stocks,
        template: _selectedTemplate,
        settings: settings,
        appSettings: appSettings,
        sizes: sizes,
        colors: colors,
        showInstagram: _showInstagram,
        showWebsite: _showWebsite,
        showContact: _showContact,
        customLinkOverride: _customLinkCtrl.text,
      );
    });
  }

  Future<void> _saveAiPrompt(String productId, String prompt) async {
    // Ideally use Product Service update method
    try {
      await FirebaseFirestore.instance.collection('Products').doc('details').collection('datas').doc(productId).update({
        'aiImagePrompt': prompt
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Prompt Saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving prompt: $e')));
    }
  }

  Future<void> _saveNote(String productId) async {
    final note = _contentCtrl.text.trim();
    if (note.isEmpty) return;

    try {
      setState(() => _marketingNotes.add(note)); // Optimistic update
      
      await FirebaseFirestore.instance.collection('Products').doc('details').collection('datas').doc(productId).update({
        'marketingNotes': FieldValue.arrayUnion([note])
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note Saved!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    }
  }

  Future<void> _sendToWhatsapp(SocialSettings settings) async {
     // User requirement: "Direct WhatsApp Redirect: Add a button "Send to WhatsApp" that uses the wa.me API to open WhatsApp with the text pre-filled."
     // If settings has a number, open chat with THAT number. If not, maybe just open general share?
     // Wa.me with number opens chat. Wa.me/?text=... attempts to share.
     
     final text = Uri.encodeComponent(_contentCtrl.text);
     Uri url;
     
     if (settings.whatsappNumber.isNotEmpty) {
       // Send to specific number? No, usually marketing is sent TO customers. 
       // User requirement says: "Open https://wa.me/?text=[Encoded_Text]" in Phase 3 request? 
       // Wait, Check Prompt:
       // "WhatsApp Redirect: Open https://wa.me/?text=[Encoded_Text]." (Implies general share picker or desktop app picker)
       // "WhatsApp Redirect: Open https://wa.me/[NUMBER]?text=[ENCODED_MESSAGE]" (Prompt 2 - implies predefined number)
       // context: "You can generate... messaging..." 
       // If I am the business owner, I want to SHARE this content. I don't want to send it to MYSELF.
       // So `https://wa.me/?text=` is the correct way to open the contact picker.
       // UNLESS "WhatsApp Message Link: (Auto-generated wa.me link)" refers to the link INSIDE the message.
       // The "Action" button should probably open the share sheet or WA picker.
       
       url = Uri.parse('https://wa.me/?text=$text');
     } else {
       url = Uri.parse('https://wa.me/?text=$text');
     }

     if (await canLaunchUrl(url)) {
       await launchUrl(url, mode: LaunchMode.externalApplication);
     } else {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
     }
  }
}

// Helper for stock stream (simplifying since we don't have this exact provider exposed globally in the view files I saw earlier)
final stockStreamProvider = StreamProvider.family<List<StockItem>, String>((ref, productId) {
  return ref.watch(stockServiceProvider).getStockForProduct(productId);
});
