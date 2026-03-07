import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../features/products/data/services/stock_service.dart';
import '../../data/providers/settings_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/github_storage_service.dart';
import 'user_management_screen.dart';
import '../../../../features/pos/presentation/screens/transparency_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _biometric = false;
  bool _autoBackup = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.settings, color: theme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Manage your application preferences',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn().slideX(begin: -0.1),
            
            const SizedBox(height: 32),

            // Responsive Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column
                      Expanded(
                        child: Column(
                          children: [
                            _buildAppearanceCard(context, ref, isDarkMode),
                            const SizedBox(height: 24),
                            _buildBillingCard(context, ref),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column
                      Expanded(
                        child: Column(
                          children: [
                             _buildAccountCard(context),
                             const SizedBox(height: 24),
                             _buildDataCard(context, ref),
                             const SizedBox(height: 24),
                             _buildAboutCard(context),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildAppearanceCard(context, ref, isDarkMode),
                      const SizedBox(height: 24),
                      _buildBillingCard(context, ref),
                      const SizedBox(height: 24),
                      _buildAccountCard(context),
                      const SizedBox(height: 24),
                      _buildDataCard(context, ref),
                      const SizedBox(height: 24),
                      _buildAboutCard(context),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 48),
            Center(
               child: TextButton.icon(
                  onPressed: () => _showLogoutConfirmation(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: Colors.red.withValues(alpha: 0.05),
                  ),
                 icon: const Icon(Icons.logout, color: Colors.red),
                 label: Text('Log Out', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
               ),
             ),
             const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- SECTIONS ---

  Widget _buildAppearanceCard(BuildContext context, WidgetRef ref, bool isDarkMode) {
    return SettingsCard(
      title: 'Appearance',
      icon: FontAwesomeIcons.palette,
      color: Colors.purple,
      children: [
         _buildSwitchTile(
            context,
            icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
            title: 'Dark Mode',
            subtitle: 'Toggle application theme',
            value: isDarkMode,
            onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(val),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Product Card Preview', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _buildDisplaySettings(context, ref),
      ],
    );
  }

  Widget _buildBillingCard(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).asData?.value;
    return SettingsCard(
      title: 'Billing & Printing',
      icon: FontAwesomeIcons.receipt,
      color: Colors.blue,
      children: [
        SettingsTile(
          icon: FontAwesomeIcons.fileInvoice,
          title: 'Invoice Layout',
          subtitle: 'Configure logo, address, and footer',
          onTap: () => _showBillSettingsDialog(context),
        ),
        _buildSwitchTile(
          context,
          icon: FontAwesomeIcons.print,
          title: 'Compact Discount',
          subtitle: 'Print only global discount summary',
          value: settings?.printGlobalDiscountOnly ?? false,
          onChanged: (val) => ref.read(settingsProvider.notifier).updatePrintGlobalDiscountOnly(val),
        ),
        SettingsTile(
          icon: FontAwesomeIcons.coins,
          title: 'Currency',
          subtitle: 'LKR (Sri Lankan Rupee)',
          trailing: const SizedBox(), 
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return SettingsCard(
      title: 'Account & Security',
      icon: FontAwesomeIcons.shieldHalved,
      color: Colors.green,
      children: [
         SettingsTile(
          icon: FontAwesomeIcons.user,
          title: 'Profile',
          subtitle: 'Manage personal details',
          onTap: () {},
        ),
        // Restricted User Management
        if (ref.watch(authStateProvider).value?.isAdministrator ?? false) ...[
           SettingsTile(
            icon: FontAwesomeIcons.usersGear,
            title: 'User Management',
            subtitle: 'Manage roles & access',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
          ),
           SettingsTile(
            icon: FontAwesomeIcons.fileShield,
            title: 'Bill Manager',
            subtitle: 'Transparency & Verification',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransparencyScreen())),
          ),
           SettingsTile(
            icon: FontAwesomeIcons.bullseye,
            title: 'Origin Target',
            subtitle: 'Set daily transparency target',
            onTap: () => _showTargetDialog(context),
          ),
        ],
        _buildSwitchTile(
          context,
          icon: FontAwesomeIcons.fingerprint,
          title: 'Biometric Login',
          subtitle: 'Use fingerprint/face ID',
          value: _biometric,
          onChanged: (val) => setState(() => _biometric = val),
        ),
        _buildSwitchTile(
          context,
          icon: FontAwesomeIcons.bell,
          title: 'Notifications',
          subtitle: 'Receive system alerts',
          value: _notifications,
          onChanged: (val) => setState(() => _notifications = val),
        ),
      ],
    );
  }

  Future<void> _showTargetDialog(BuildContext context) async {
    final controller = TextEditingController();
    // Fetch current
    final doc = await FirebaseFirestore.instance.collection('bill_settings').doc('config').get();
    if (doc.exists) {
       controller.text = (doc.data()?['origin_target_value'] ?? 50000).toString();
    } else {
       controller.text = '50000';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Origin Target'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Target Value (LKR)',
            hintText: 'e.g. 50000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
               final val = int.tryParse(controller.text) ?? 50000;
               await FirebaseFirestore.instance.collection('bill_settings').doc('config').set({
                 'origin_target_value': val
               }, SetOptions(merge: true));
               if (context.mounted) {
                 Navigator.pop(ctx);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target Updated!')));
               }
            }, 
            child: const Text('Save')
          ),
        ],
      )
    );
  }

  Widget _buildDataCard(BuildContext context, WidgetRef ref) {
    return SettingsCard(
      title: 'Data Management',
      icon: FontAwesomeIcons.database,
      color: Colors.orange,
      children: [
        _buildSwitchTile(
          context,
          icon: FontAwesomeIcons.cloudArrowUp,
          title: 'Auto Backup',
          subtitle: 'Backup daily to cloud',
          value: _autoBackup,
          onChanged: (val) => setState(() => _autoBackup = val),
        ),
        SettingsTile(
          icon: FontAwesomeIcons.rotate,
          title: 'Sync Now',
          subtitle: 'Force sync with server',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing data...'))),
        ),
        SettingsTile(
          icon: FontAwesomeIcons.tags,
          title: 'Recalculate Prices',
          subtitle: 'Refresh product prices from stock',
          onTap: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recalculating...')));
             try {
                await ref.read(stockServiceProvider).recalculateAllProductPrices();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done!'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
          },
        ),
        const Divider(),
        _buildRetentionSettings(context, ref),
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return SettingsCard(
      title: 'About',
      icon: FontAwesomeIcons.circleInfo,
      color: Colors.grey,
      children: [
        SettingsTile(
          icon: FontAwesomeIcons.codeBranch,
          title: 'Version',
          subtitle: 'v1.0.0 (Beta)',
          trailing: const SizedBox(),
          onTap: () {},
        ),
        SettingsTile(
          icon: FontAwesomeIcons.fileContract,
          title: 'Terms of Service',
          onTap: () {},
        ),
        SettingsTile(
          icon: FontAwesomeIcons.lock,
          title: 'Privacy Policy',
          onTap: () {},
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildRetentionSettings(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final days = settingsAsync.value?.purchaseOrderRetentionDays ?? 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: Row(
            children: [
               Icon(Icons.cleaning_services, size: 20, color: theme.colorScheme.primary),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Purchase Order Retention', style: TextStyle(fontWeight: FontWeight.w600)),
                     Text('Delete after $days days', style: TextStyle(fontSize: 12, color: theme.hintColor)),
                   ],
                 ),
               ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: theme.primaryColor,
            inactiveTrackColor: theme.primaryColor.withValues(alpha: 0.1),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: days.toDouble(),
            min: 1, max: 90,
            divisions: 89,
            label: '$days Days',
            onChanged: (val) {
              ref.read(settingsProvider.notifier).updateRetentionDays(val.round());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDisplaySettings(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final currentSettings = settingsAsync.value ?? const AppSettings();

    return Column(
      children: [
        // Live Preview Box
        Center(
          child: Container(
            width: currentSettings.productCardSize,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor, // Contrast against card
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                  Container(
                    height: currentSettings.productCardSize * 0.5,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Icon(FontAwesomeIcons.shirt, size: 24, color: theme.primaryColor)),
                  ),
                  const SizedBox(height: 8),
                  Text('T-Shirt', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16 * currentSettings.productTextScale)),
                  Text('LKR 2,500', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * currentSettings.productTextScale, color: theme.primaryColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
           children: [
             const Text('Size', style: TextStyle(fontSize: 12)),
             Expanded(
               child: Slider(
                value: currentSettings.productCardSize,
                min: 150, max: 350, divisions: 200,
                onChanged: (val) => ref.read(settingsProvider.notifier).updateProductCardSize(val),
              ),
             ),
           ],
        ),
        Row(
           children: [
             const Text('Text', style: TextStyle(fontSize: 12)),
             Expanded(
               child: Slider(
                value: currentSettings.productTextScale,
                min: 0.8, max: 1.5, divisions: 7,
                onChanged: (val) => ref.read(settingsProvider.notifier).updateProductTextScale(val),
              ),
             ),
           ],
        ),
      ],
    );
  }


  Widget _buildSwitchTile(BuildContext context, {required IconData icon, required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final theme = Theme.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: theme.primaryColor,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: theme.primaryColor),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  // --- DIALOGS (Kept mostly same logic) ---
  
  Future<void> _showBillSettingsDialog(BuildContext context) async {
      final settings = ref.read(settingsProvider).value ?? const AppSettings();
      final addressCtrl = TextEditingController(text: settings.billAddress);
      final whatsappCtrl = TextEditingController(text: settings.whatsappLink);
      final whatsappLabelCtrl = TextEditingController(text: settings.whatsappLinkLabel);
      final footerCtrl = TextEditingController(text: settings.billFooterText);
      final logoCtrl = TextEditingController(text: settings.logoPath);
      bool showProductDiscount = settings.showProductDiscount;

      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Bill Layout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450, // Slightly wider
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogField(addressCtrl, 'Header Address', lines: 3),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDialogField(whatsappCtrl, 'WhatsApp Link')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDialogField(whatsappLabelCtrl, 'Label (e.g. Scan Me)')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(footerCtrl, 'Footer Message'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                           Expanded(child: _buildDialogField(logoCtrl, 'Logo URL / Path')),
                           const SizedBox(width: 8),
                           IconButton.filledTonal(
                             icon: const Icon(Icons.upload),
                             onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                   final bytes = await image.readAsBytes();
                                   // Mock upload or real upload
                                   try {
                                      final url = await GithubStorageService().uploadBillLogo(image.name, bytes);
                                      logoCtrl.text = url;
                                   } catch (e) {
                                      // Handle error
                                   }
                                }
                             },
                           )
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Itemized Discounts'),
                        subtitle: const Text('Show discount column per item'),
                        value: showProductDiscount,
                        onChanged: (val) => setState(() => showProductDiscount = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    ref.read(settingsProvider.notifier).updateBillSettings(
                      address: addressCtrl.text,
                      whatsapp: whatsappCtrl.text,
                      logo: logoCtrl.text,
                      footerText: footerCtrl.text,
                      whatsappLabel: whatsappLabelCtrl.text,
                      showProductDiscount: showProductDiscount,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          }
        ),
      );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, {int lines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to end your session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Log Out')
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authServiceProvider).signOut();
    }
  }
}

// --- HELPER CLASSES ---

class SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const SettingsCard({super.key, required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsTile({
    super.key, 
    required this.icon, 
    required this.title, 
    this.subtitle, 
    this.trailing, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: theme.scaffoldBackgroundColor, // Slight contrast
        leading: Icon(icon, color: theme.colorScheme.secondary, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
