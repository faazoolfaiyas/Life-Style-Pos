import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/connection_service.dart';
import '../../data/models/connection_model.dart';
import 'connection_form_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'connection_detail_dialog.dart';

class ConnectionList extends ConsumerStatefulWidget {
  final String type;
  final String searchQuery;
  
  const ConnectionList({
    super.key, 
    required this.type,
    this.searchQuery = '',
  });

  @override
  ConsumerState<ConnectionList> createState() => _ConnectionListState();
}

class _ConnectionListState extends ConsumerState<ConnectionList> {
  void _showFormDialog({Map<String, dynamic>? initialData, String? id}) {
    showDialog(
      context: context,
      builder: (context) => ConnectionFormDialog(
        type: widget.type,
        initialData: initialData,
        onSubmit: (data) async {
          final service = ref.read(connectionServiceProvider);
          final messenger = ScaffoldMessenger.of(context);
          try {
            if (id != null) {
              await service.updateConnection(widget.type, id, data);
            } else {
              await service.addConnection(widget.type, data);
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  void _deleteConnection(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: const Text('Are you sure you want to delete this connection? The ID will be reused for the next new connection.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(connectionServiceProvider).deleteConnection(widget.type, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(connectionServiceProvider);

    return Column(
      children: [
        // Header removed
        Expanded(
          child: StreamBuilder<List<ConnectionModel>>(
            stream: service.getConnectionsStream(widget.type),
            builder: (context, snapshot) {
              // ...
              final allContacts = snapshot.data ?? [];
              
              // Filter contacts
              final contacts = allContacts.where((contact) {
                 if (widget.searchQuery.isEmpty) return true;
                
                 final query = widget.searchQuery.toLowerCase();
                 // ... usage of query
                final nameMatches = contact.name.toLowerCase().contains(query);
                final idMatches = contact.connectionId.toString().contains(query);
                final phoneMatches = contact.whatsappNumber.contains(query);
                
                // For Suppliers, also search owner name if available
                bool ownerMatches = false;
                if (contact is Supplier && contact.ownerName != null) {
                  ownerMatches = contact.ownerName!.toLowerCase().contains(query);
                }

                // For Affiliates, search vehicle number
                bool vehicleMatches = false;
                if (contact is Affiliate) {
                  vehicleMatches = contact.threewheelerNumber.toLowerCase().contains(query);
                }

                return nameMatches || idMatches || phoneMatches || ownerMatches || vehicleMatches;
              }).toList();

              if (contacts.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(FontAwesomeIcons.users, size: 48, color: Colors.grey[300]),
                       const SizedBox(height: 16),
                       Text('No ${widget.type}s found', style: TextStyle(color: Colors.grey[500])),
                     ],
                   ),
                 );
              }

              return ListView.separated(
                itemCount: contacts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  // Cast to specific types to access specific fields if needed, 
                  // but for list view connectionId, name, whatsappUrl are common or can be accessed via base
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ConnectionDetailDialog(contact: contact),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                   color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                   shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '#${contact.connectionId}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name, // Access name directly
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.phone, size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          contact.whatsappNumber,
                                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        if (contact.status == 'Active')
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                             decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                             child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                           )
                                        else
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                             decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                             child: Text(contact.status, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                           )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                                    onPressed: () async {
                                      var phone = contact.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');
                                      // Add 94 if number starts with 0 and is likely Sri Lankan length (9 or 10 digits)
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
                                    },
                                    tooltip: 'Chat on WhatsApp',
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showFormDialog(initialData: contact.toMap(), id: contact.id);
                                      } else if (value == 'delete') {
                                         _deleteConnection(contact.id!);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, size: 16, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text('Edit', style: GoogleFonts.outfit()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, size: 16, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Text('Delete', style: GoogleFonts.outfit()),
                                          ],
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX();
                },
              );
            }
          ),
        ),
      ],
    );
  }
}
