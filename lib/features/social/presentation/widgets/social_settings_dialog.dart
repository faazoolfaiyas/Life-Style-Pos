import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../data/models/social_settings_model.dart';

// Simple provider for settings - Ideally should be moved to a dedicated provider file
final socialSettingsProvider = FutureProvider<SocialSettings>((ref) async {
  final doc = await FirebaseFirestore.instance.collection('settings').doc('social').get();
  if (doc.exists && doc.data() != null) {
    return SocialSettings.fromMap(doc.data()!);
  }
  return const SocialSettings();
});

class SocialSettingsDialog extends ConsumerStatefulWidget {
  const SocialSettingsDialog({super.key});

  @override
  ConsumerState<SocialSettingsDialog> createState() => _SocialSettingsDialogState();
}

class _SocialSettingsDialogState extends ConsumerState<SocialSettingsDialog> {
  late TextEditingController _whatsappCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _tiktokCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _contactNameCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _whatsappCtrl = TextEditingController();
    _instagramCtrl = TextEditingController();
    _tiktokCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _contactNameCtrl = TextEditingController();
    
    // Load initial data
    final settings = ref.read(socialSettingsProvider).value;
    if (settings != null) {
      _whatsappCtrl.text = settings.whatsappNumber;
      _instagramCtrl.text = settings.instagramUrl;
      _tiktokCtrl.text = settings.tiktokUrl;
      _websiteCtrl.text = settings.websiteUrl;
      _contactNameCtrl.text = settings.customContactName;
    }
  }

  @override
  void dispose() {
    _whatsappCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _websiteCtrl.dispose();
    _contactNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = SocialSettings(
        whatsappNumber: _whatsappCtrl.text.trim(),
        instagramUrl: _instagramCtrl.text.trim(),
        tiktokUrl: _tiktokCtrl.text.trim(),
        websiteUrl: _websiteCtrl.text.trim(),
        customContactName: _contactNameCtrl.text.trim(),
      );

      await FirebaseFirestore.instance.collection('settings').doc('social').set(settings.toMap());
      ref.invalidate(socialSettingsProvider); // Refresh provider
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brand settings saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Global Brand Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'These links will be automatically injected into your marketing messages.',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
              ),
              const SizedBox(height: 24),

              _buildField(_whatsappCtrl, 'WhatsApp Number', FontAwesomeIcons.whatsapp, hint: '+947XXXXXXXX'),
              const SizedBox(height: 16),
              _buildField(_instagramCtrl, 'Instagram Profile URL', FontAwesomeIcons.instagram, hint: 'https://instagram.com/yourbrand'),
              const SizedBox(height: 16),
              _buildField(_tiktokCtrl, 'TikTok Profile URL', FontAwesomeIcons.tiktok, hint: 'https://tiktok.com/@yourbrand'),
              const SizedBox(height: 16),
              _buildField(_websiteCtrl, 'Website / Catalog URL', FontAwesomeIcons.globe, hint: 'https://yourbrand.com'),
              const SizedBox(height: 16),
              _buildField(_contactNameCtrl, 'Custom Business Name', FontAwesomeIcons.building, hint: 'My Fashion Store'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveSettings,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {String? hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
