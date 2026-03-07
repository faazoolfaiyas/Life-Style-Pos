import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:life_style/features/auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final isExpanded = state.isSidebarExpanded;
    final theme = Theme.of(context);

    // Sidebar items
    final items = [
      {'icon': FontAwesomeIcons.chartPie, 'label': 'Overview'},
      {'icon': FontAwesomeIcons.cashRegister, 'label': 'POS'},
      {'icon': FontAwesomeIcons.users, 'label': 'Connections'},
      {'icon': FontAwesomeIcons.fileInvoice, 'label': 'Orders'},
      {'icon': FontAwesomeIcons.bullhorn, 'label': 'Promotions'},
      {'icon': FontAwesomeIcons.shareNodes, 'label': 'Social Media'}, // Index 5
      {'icon': FontAwesomeIcons.boxOpen, 'label': 'Products'},
      {'icon': FontAwesomeIcons.boxesStacked, 'label': 'Inventory'},
      {'icon': FontAwesomeIcons.layerGroup, 'label': 'Attributes'},
      {'icon': FontAwesomeIcons.coins, 'label': 'Finance'},
      {'icon': FontAwesomeIcons.chartLine, 'label': 'Reports'},
      {'icon': FontAwesomeIcons.gear, 'label': 'Settings'},
    ];

    return AnimatedContainer(
      duration: 300.ms,
      width: isExpanded ? 260 : 80,
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(4, 0),
            ),
        ],
      ),
      child: Column(
        children: [
          // Logo Area & Notifications
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                // Logo & Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FontAwesomeIcons.bagShopping, color: Color(0xFF6C63FF), size: 28)
                        .animate(target: isExpanded ? 1 : 0)
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                    if (isExpanded) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Life Style',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ).animate().fadeIn(duration: 200.ms, delay: 100.ms).slideX(begin: -0.2),
                    ]
                  ],
                ),
                
                // Notification Icon (Only if Expanded)
                if (isExpanded)
                  IconButton(
                    onPressed: () {}, // TODO: Notifications
                    icon: Icon(FontAwesomeIcons.bell, size: 18, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = state.selectedIndex == index;

                return InkWell(
                  onTap: () => ref.read(dashboardProvider.notifier).setIndex(index),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    margin: EdgeInsets.symmetric(
                      horizontal: isExpanded ? 16 : 12,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: theme.primaryColor.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: isExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          item['icon'] as IconData,
                          size: 20,
                          color: isSelected
                              ? theme.primaryColor
                              : theme.iconTheme.color?.withValues(alpha: 0.6),
                        ),
                        if (isExpanded) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: GoogleFonts.outfit(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? theme.primaryColor
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // User Profile & Collapse
          Consumer(
            builder: (context, ref, _) {
              // Access Auth Provider inside Consumer to minimize rebuilds if not needed
              // Assuming authServiceProvider is globally available or imported
              // We need to import it at the top of file
              return InkWell(
                onTap: () => ref.read(dashboardProvider.notifier).toggleSidebar(),
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                       CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, size: 18, color: Color(0xFF6C63FF)),
                       ),
                       if (isExpanded) ...[
                         const SizedBox(width: 12),
                         Expanded(
                           child: Consumer(
                                 builder: (context, ref, _) {
                                   final userAsync = ref.watch(authStateProvider);
                                   return userAsync.when(
                                     data: (user) => Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                          Text(
                                            user?.email ?? 'User',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            user?.role ?? 'Manager',
                                            style: GoogleFonts.outfit(fontSize: 10, color: theme.hintColor),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                       ],
                                     ),
                                     loading: () => const Text('Loading...'),
                                     error: (_,__) => const Text('Error'),
                                   );
                                 }
                               ),
                         ),
                         Icon(
                            FontAwesomeIcons.chevronLeft,
                            size: 14,
                            color: theme.iconTheme.color?.withValues(alpha: 0.5),
                         ),
                       ]
                    ],
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}
