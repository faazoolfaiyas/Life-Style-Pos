import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/sidebar.dart';

import 'overview_screen.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../products/presentation/screens/inventory_screen.dart';
import '../../../products/presentation/screens/attributes_screen.dart';
import '../../../connections/presentation/screens/connections_screen.dart';
import '../../../promotions/presentation/screens/promotions_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../social/presentation/screens/social_media_screen.dart'; // Added

class DashboardLayout extends ConsumerWidget {
  const DashboardLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () => ref.read(dashboardProvider.notifier).setIndex(1), // POS
        const SingleActivator(LogicalKeyboardKey.f2): () => ref.read(dashboardProvider.notifier).setIndex(6), // Products (Shifted +1)
        const SingleActivator(LogicalKeyboardKey.f3): () => ref.read(dashboardProvider.notifier).setIndex(7), // Inventory (Shifted +1)
        const SingleActivator(LogicalKeyboardKey.f4): () => ref.read(dashboardProvider.notifier).setIndex(2), // Connections
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(), // Close Dialogs
      },
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            const Sidebar(),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Header Removed
                  
                  // Dynamic Page Content
                  Expanded(
                    child: _buildPage(state.selectedIndex),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    // Basic routing for dashboard tabs
    switch (index) {
      case 0:
        return const OverviewScreen();
      case 1:
        return const PosScreen();
      case 2:
        return const ConnectionsScreen();
      case 3:
        return const Center(child: Text('Orders Screen - Coming Soon'));
      case 4:
         return const PromotionsScreen();
      case 5:
         return const SocialMediaScreen(); // New
      case 6:
         return const ProductsScreen();
      case 7:
         return const InventoryScreen();
      case 8:
         return const AttributesScreen();
      case 9:
        return const FinanceScreen();
      case 10:
        // Reports
        return Center(child: Text('Reports - Coming Soon', style: TextStyle(color: Colors.grey[400], fontSize: 24)));
      case 11:
        return const SettingsScreen();
      default:
        return Center(
          child: Text(
            'Coming Soon',
            style: TextStyle(fontSize: 24, color: Colors.grey[400]),
          ),
        );
    }
  }
}
