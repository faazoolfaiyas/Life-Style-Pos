import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class Header extends ConsumerWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(authStateProvider);
    final user = userAsync.value;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products, orders...',
                  prefixIcon: Icon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: 16,
                    color: theme.iconTheme.color?.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: theme.cardColor.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Actions
          _buildActionButton(context, FontAwesomeIcons.bell),
          const SizedBox(width: 24),

          // Profile
          if (user != null)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    user.email.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.role, 
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: user.isAdministrator ? Colors.redAccent : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      user.email,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                PopupMenuButton(
                  icon: const Icon(FontAwesomeIcons.chevronDown, size: 14),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(FontAwesomeIcons.rightFromBracket, size: 16),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                      onTap: () {
                        ref.read(authServiceProvider).signOut();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon) {
    return IconButton(
      onPressed: () {},
      icon: FaIcon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }
}
