import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/connection_list.dart';
import '../widgets/connection_form_dialog.dart';
import '../../services/connection_service.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    String type = 'Customer';
    switch (_tabController.index) {
      case 0: type = 'Customer'; break;
      case 1: type = 'Supplier'; break;
      case 2: type = 'Reseller'; break;
      case 3: type = 'Affiliate'; break;
    }

    showDialog(
      context: context,
      builder: (context) => ConnectionFormDialog(
        type: type,
        onSubmit: (data) async {
          final service = ref.read(connectionServiceProvider);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await service.addConnection(type, data);
            if (context.mounted) {
               // Navigator.pop(context); // Dialog closes itself inside usually?? No, ConnectionFormDialog usually calls onSubmit and might wait.
               // Let's assume FormDialog handles pop or not? 
               // Looking at ConnectionList: onSubmit just calls service. 
               // The dialog usually closes via Navigator.pop(context) button?
               // Usually Form widgets handle their own closing on success if they manage state, or parent closes.
               // Let's check ConnectionFormDialog structure if needed. 
               // Standard pattern: Button onPressed -> Validate -> onSubmit -> Pop.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Connections', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            const SizedBox(width: 32),
            SizedBox(
              width: 350,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() {}), // Trigger rebuild to pass new query
                decoration: InputDecoration(
                  hintText: 'Search connections...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(text: 'Customers'),
            Tab(text: 'Suppliers'),
            Tab(text: 'Resellers'),
            Tab(text: 'Affiliates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ConnectionList(type: 'Customer', searchQuery: _searchCtrl.text),
          ConnectionList(type: 'Supplier', searchQuery: _searchCtrl.text),
          ConnectionList(type: 'Reseller', searchQuery: _searchCtrl.text),
          ConnectionList(type: 'Affiliate', searchQuery: _searchCtrl.text),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
