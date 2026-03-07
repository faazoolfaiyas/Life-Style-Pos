import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/social_settings_dialog.dart';
import '../widgets/social_product_list.dart';
import '../widgets/social_product_filter_panel.dart';

class SocialMediaScreen extends ConsumerWidget {
  const SocialMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      endDrawer: SocialProductFilterPanel(
        sortBy: 'name',
        sortAsc: true,
        onApply: ({category, minPrice, maxPrice, hasMarketingNotes, sortBy = 'name', sortAsc = true}) {
          // TODO: Apply filters to product list
          // For now, just close the drawer
        },
        onReset: () {
          // TODO: Reset filters in product list
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Social Media Hub',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Generate high-conversion marketing content',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filter Products',
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                    const SizedBox(width: 12),
                     FilledButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const SocialSettingsDialog(),
                        );
                      },
                      icon: const Icon(FontAwesomeIcons.gear, size: 16),
                      label: const Text('Brand Settings'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Area
            const Expanded(
              child: SocialProductList(),
            ),
          ],
        ),
      ),
    );
  }
}
