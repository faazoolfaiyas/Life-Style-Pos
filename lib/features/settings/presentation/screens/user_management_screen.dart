import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersStream = ref.watch(authServiceProvider).getAllUsersStream();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('User Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserTile(context, user);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    final isMe = ref.watch(authServiceProvider).currentUser?.uid == user.uid;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
           BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
        ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
           backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
           child: Text(
             user.email.substring(0, 1).toUpperCase(),
             style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _getRoleColor(user.role)),
           ),
        ),
        title: Text(user.email, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(
                 color: _getRoleColor(user.role).withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(4)
               ),
               child: Text(user.role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getRoleColor(user.role))),
             ),
             if (isMe) ...[
               const SizedBox(width: 8),
               const Text('(You)', style: TextStyle(fontSize: 12, color: Colors.grey)),
             ]
          ],
        ),
        trailing: isMe 
          ? null 
          : IconButton.filledTonal(
              icon: const Icon(Icons.edit, size: 18), 
              onPressed: () => _showChangeRoleDialog(context, user)
            ),
      ),
    ).animate().fadeIn().slideX();
  }

  Color _getRoleColor(String role) {
    switch(role) {
      case 'Administrator': return Colors.red;
      case 'Admin': return Colors.blue;
      default: return Colors.orange; // Cashier
    }
  }

  Future<void> _showChangeRoleDialog(BuildContext context, UserModel user) async {
    String selectedRole = user.role;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Change Role', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select new role for ${user.email}:'),
                  const SizedBox(height: 16),
                  _buildRoleOption('Administrator', selectedRole, (val) => setState(() => selectedRole = val)),
                  _buildRoleOption('Admin', selectedRole, (val) => setState(() => selectedRole = val)),
                  _buildRoleOption('Cashier', selectedRole, (val) => setState(() => selectedRole = val)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                     Navigator.pop(context); // Close selection
                     if (selectedRole != user.role) {
                        _showReAuthDialog(context, user, selectedRole);
                     }
                  }, 
                  child: const Text('Continue')
                )
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildRoleOption(String role, String groupValue, ValueChanged<String> onChanged) {
    return RadioListTile<String>(
      title: Text(role),
      value: role,
      groupValue: groupValue,
      onChanged: (val) => onChanged(val!),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _showReAuthDialog(BuildContext context, UserModel targetUser, String newRole) async {
    final passCtrl = TextEditingController();
    bool isProcessing = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
         return StatefulBuilder(
           builder: (context, setState) {
             final theme = Theme.of(context);
             return AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 40,
                        color: theme.primaryColor,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).shake(delay: 500.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Security Check',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please enter your administrator password to confirm this sensitive action.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                    ),
                    if (isProcessing) ...[
                       const SizedBox(height: 16),
                       const LinearProgressIndicator(),
                       const SizedBox(height: 8),
                       Text('Verifying & Updating...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]
                  ],
               ),
               actions: [
                 if (!isProcessing) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                 FilledButton(
                   onPressed: isProcessing ? null : () async {
                      setState(() { isProcessing = true; error = null; });
                      
                      try {
                         // 1. Re-authenticate with timeout
                         final success = await ref.read(authServiceProvider)
                             .reauthenticate(passCtrl.text)
                             .timeout(const Duration(seconds: 10), onTimeout: () {
                                throw 'Re-authentication timed out. Check connection.';
                             });

                         if (success) {
                            // 2. Update Firestore with timeout
                            await ref.read(authServiceProvider)
                                .updateUserRole(targetUser.uid, newRole)
                                .timeout(const Duration(seconds: 10), onTimeout: () {
                                   throw 'Update timed out. Check connection.';
                                });

                            if (context.mounted) {
                               Navigator.pop(context); // Close Dialog
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role Updated Successfully!'), backgroundColor: Colors.green));
                            }
                         } else {
                            if (context.mounted) {
                              setState(() { isProcessing = false; error = 'Incorrect Password'; });
                            }
                         }
                      } catch (e) {
                         if (context.mounted) {
                           setState(() { isProcessing = false; error = e.toString().replaceAll('Exception:', ''); });
                         }
                      }
                   }, 
                   child: const Text('Confirm')
                 ),
               ],
             );
           }
         );
      }
    );
  }
}
