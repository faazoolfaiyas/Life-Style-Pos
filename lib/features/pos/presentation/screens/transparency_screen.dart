import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/models/bill_model.dart';
import '../widgets/bill_detail_dialog.dart';

class TransparencyScreen extends ConsumerStatefulWidget {
  const TransparencyScreen({super.key});

  @override
  ConsumerState<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends ConsumerState<TransparencyScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('yyyy-MM-dd');
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Bill Manager (Transparency)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: _getUsedBillIds(startOfDay, endOfDay),
        initialData: const [],
        builder: (context, snapshot) {
          final excludeIds = snapshot.data ?? [];
          
          return Row(
            children: [
              // Left Column: Transparency/Curated View
              Expanded(
                child: _buildColumn(
                  context,
                  title: 'Curated View',
                  subtitle: 'Visible to Standard Users (Bill-Origin + Temp)',
                  color: Colors.green,
                  isCurated: true,
                  start: startOfDay,
                  end: endOfDay,
                  // Pass null stream here as it uses internal logic
                  stream: const Stream.empty(), 
                ),
              ),
              const VerticalDivider(width: 1),
              // Right Column: Master Record (Original-Bills)
              Expanded(
                child: _buildColumn(
                  context,
                  title: 'Master Record',
                  subtitle: 'Full History (Original-Bills)',
                  color: Colors.blue,
                  stream: FirebaseFirestore.instance
                      .collection('bills')
                      .where('createdAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
                      .where('createdAt', isLessThanOrEqualTo: endOfDay.toIso8601String())
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  isCurated: false,
                  start: startOfDay,
                  end: endOfDay,
                  excludeIds: excludeIds,
                ),
              ),
            ],
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _verifyDate(startOfDay, endOfDay),
        label: const Text('Verify Date (Move Temp -> Origin)'),
        icon: const Icon(Icons.verified),
        backgroundColor: Colors.amber[800],
      ),
    );
  }

  Stream<List<String>> _getUsedBillIds(DateTime start, DateTime end) {
     final tempStream = FirebaseFirestore.instance
        .collection('temp_origin')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .snapshots();
     
     final originStream = FirebaseFirestore.instance
        .collection('bill_origin')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .snapshots();

     return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<String>>(
       tempStream, 
       originStream, 
       (temp, origin) {
         final tempIds = temp.docs.map((d) => d.id).toList();
         final originIds = origin.docs.map((d) => d.id).toList();
         return [...tempIds, ...originIds];
       }
     );
  }

  Stream<QuerySnapshot> _getCuratedStream(DateTime start, DateTime end) {
    // Placeholder - not used directly by UI anymore but kept for safety
    return FirebaseFirestore.instance.collection('dummy').snapshots();
  }


  Widget _buildColumn(BuildContext context, {
    required String title, 
    required String subtitle, 
    required Color color, 
    required Stream<QuerySnapshot> stream,
    required bool isCurated,
    required DateTime start,
    required DateTime end,
    List<String> excludeIds = const [],
  }) {
    if (isCurated) {
      // Logic handled by _buildCuratedList
      return _buildCuratedList(start, end);
    }
    
    // Master Record Logic
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
         if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
         if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
         
         final allDocs = snapshot.data?.docs ?? [];
         // Filter excluded
         final docs = allDocs.where((doc) => !excludeIds.contains(doc.id)).toList();
         
         // Calculate Total (Use allDocs to show TRUE original total, including hidden ones)
         final total = allDocs.fold(0.0, (sum, doc) => sum + ((doc.data() as Map)['totalAmount'] as num).toDouble());

         return Column(
           children: [
             _buildHeader(context, title, subtitle, color, total, isCurated: false, onRedo: () => _showRedoDialog(total, start, end)),
             Expanded(
               child: ListView.separated(
                 padding: const EdgeInsets.all(16),
                 itemCount: docs.length,
                 separatorBuilder: (_, __) => const SizedBox(height: 8),
                 itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildBillTile(context, data, isCurated: false);
                 },
               ),
             ),
           ],
         );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String title, String subtitle, Color color, double total, {required bool isCurated, VoidCallback? onRedo}) {
      final theme = Theme.of(context);
      return Container(
          padding: const EdgeInsets.all(16),
          color: color.withOpacity(0.1),
          child: Row(
            children: [
              Icon(isCurated ? Icons.visibility : Icons.storage, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  ],
                ),
              ),
              Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                    Text('Total', style: TextStyle(fontSize: 10, color: theme.hintColor)),
                    Text('LKR ${total.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                 ],
              ),
              if (!isCurated && onRedo != null)
                 IconButton(
                   icon: const Icon(Icons.refresh, color: Colors.blue),
                   tooltip: 'Re-do / Auto-Fill Session',
                   onPressed: onRedo,
                 ),
            ],
          ),
        );
  }

  Widget _buildCuratedList(DateTime start, DateTime end) {
     final tempStream = FirebaseFirestore.instance
        .collection('temp_origin')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .snapshots();
     
     final originStream = FirebaseFirestore.instance
        .collection('bill_origin')
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .snapshots();

     return StreamBuilder<List<QuerySnapshot>>(
       stream: Rx.zip([tempStream, originStream], (values) => values.cast<QuerySnapshot>()), 
       initialData: const [],
       builder: (context, snapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: tempStream,
            builder: (ctx, tempSnap) {
               return StreamBuilder<QuerySnapshot>(
                 stream: originStream,
                 builder: (ctx, originSnap) {
                    final tempDocs = tempSnap.data?.docs ?? [];
                    final originDocs = originSnap.data?.docs ?? [];
                    
                    final allDocs = [...tempDocs, ...originDocs];
                    allDocs.sort((a, b) {
                       final tA = (a.data() as Map)['timestamp'] as Timestamp?;
                       final tB = (b.data() as Map)['timestamp'] as Timestamp?;
                       return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
                    });

                    final hasTemp = tempDocs.isNotEmpty;

                    // Calculate Total for Curated View
                    final total = allDocs.fold(0.0, (sum, doc) => sum + ((doc.data() as Map)['totalAmount'] as num).toDouble());

                    return Column(
                      children: [
                        _buildHeader(context, 'Curated View', 'Visible to Standard Users (Bill-Origin + Temp)', Colors.green, total, isCurated: true),
                        Expanded(
                          child: DragTarget<Map<String, dynamic>>(
                            onAccept: (data) => _manualAddToTemp(data),
                            builder: (context, candidates, rejects) {
                              return Container(
                                color: candidates.isNotEmpty ? Colors.green.withOpacity(0.1) : null,
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: allDocs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                     final doc = allDocs[index];
                                     final isTemp = doc.reference.parent.id == 'temp_origin';
                                     return _buildBillTile(context, doc.data() as Map<String, dynamic>, isCurated: true, isTemp: isTemp, docId: doc.id);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        if (hasTemp)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: FloatingActionButton.extended(
                                onPressed: () => _verifyDate(start, end),
                                label: const Text('Verify Session (Move Temp -> Origin)'),
                                icon: const Icon(Icons.verified),
                                backgroundColor: Colors.amber[800],
                              ),
                            ),
                          ),
                      ],
                    );
                 }
               );
            }
          );
       }
     );
  }

  Widget _buildBillTile(BuildContext context, Map<String, dynamic> data, {required bool isCurated, bool isTemp = false, String? docId}) {
    final theme = Theme.of(context);
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    // Fix: Use 'billNumber' from map if available, else 'id', else 'billId'
    // Note: In Original-Bills, 'billNumber' is likely standard. In Origin, it might be copied.
    final displayId = data['billNumber'] ?? data['id'] ?? data['billId'] ?? 'Unknown';
    
    // Date handling
    DateTime? date;
    if (data['createdAt'] is String) {
        date = DateTime.tryParse(data['createdAt']);
    } else if (data['createdAt'] is Timestamp) {
        date = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] is Timestamp) {
        date = (data['timestamp'] as Timestamp).toDate();
    }

    final tile = Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () {
          // Show Detail Popup
          try {
             // Create a safe copy of data for the model
             final safeData = Map<String, dynamic>.from(data);
             safeData['id'] = displayId; // Ensure ID is present
             safeData['billNumber'] = displayId;
             // Ensure items list is valid (it might be dynamic from Firestore)
             if (safeData['items'] == null) safeData['items'] = [];
             
             final bill = Bill.fromMap(safeData);
             showDialog(
               context: context, 
               builder: (_) => BillDetailDialog(bill: bill) // Reuse existing dialog
             );
          } catch (e) {
             print('Error parsing bill for detail: $e');
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open details: $e')));
          }
        },
        leading: isCurated 
          ? Text(isTemp ? '⏳' : '🟢', style: const TextStyle(fontSize: 24))
          : const Icon(Icons.receipt_long),
        title: Text('Bill #$displayId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(date != null ? DateFormat('hh:mm a').format(date) : '--:--', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LKR ${total.toStringAsFixed(0)}', 
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, 
                color: isCurated ? (isTemp ? Colors.amber[800] : Colors.green) : theme.textTheme.bodyMedium?.color
              )
            ),
            if (isCurated)
               IconButton(
                 icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                 onPressed: () => _manualRemoveFromCurated(docId!, isTemp), // docId required for delete
                 tooltip: 'Remove from Transparency',
               ),
            if (!isCurated)
               IconButton(
                 icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                 onPressed: () => _manualAddToTemp(data),
                 tooltip: 'Add to Transparency',
               ),
          ],
        ),
      ),
    );

    if (!isCurated) {
      return Draggable<Map<String, dynamic>>(
        data: data,
        feedback: Material(
          child: SizedBox(
            width: 300,
            child: tile,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: tile),
        child: tile,
      );
    }
    return tile;
  }

  Future<void> _manualAddToTemp(Map<String, dynamic> data) async {
     // Add to temp_origin
     final billId = data['id'] ?? data['billId']; 
     if (billId == null) return;

     // Fix: Use ORIGINAL date (createdAt) instead of ServerTimestamp to ensure it stays in the correct "Session"
     dynamic originalTimestamp = data['createdAt'];
     
     // Ensure it's a Timestamp object for consistency in queries
     if (originalTimestamp is String) {
        // Convert String ISO to Timestamp
        originalTimestamp = Timestamp.fromDate(DateTime.parse(originalTimestamp));
     } else if (originalTimestamp == null && data['timestamp'] != null) {
        originalTimestamp = data['timestamp'];
     }
     
     // Fallback to now if absolutely no date found (unlikely for a bill)
     originalTimestamp ??= FieldValue.serverTimestamp();

     await FirebaseFirestore.instance.collection('temp_origin').doc(billId).set({
        ...data,
        'timestamp': originalTimestamp, 
        'date': originalTimestamp is Timestamp ? originalTimestamp.toDate().toIso8601String() : originalTimestamp, // Redundant but useful
        'status': 'pending'
     }, SetOptions(merge: true));
     
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Pending Review')));
  }

  Future<void> _manualRemoveFromCurated(String docId, bool isTemp) async {
      final collection = isTemp ? 'temp_origin' : 'bill_origin';
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Curated View')));
  }

  Future<void> _verifyDate(DateTime start, DateTime end) async {
     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Verify Date?'),
         content: const Text('This will move ALL Temp-Origin (⏳) bills for this date to Verified Bill-Origin (🟢). This action cannot be easily undone.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
           FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
         ],
       )
     );

     if (confirm == true) {
        final batch = FirebaseFirestore.instance.batch();
        final tempSnapshot = await FirebaseFirestore.instance.collection('temp_origin')
           .where('timestamp', isGreaterThanOrEqualTo: start)
           .where('timestamp', isLessThanOrEqualTo: end)
           .get();

        for (var doc in tempSnapshot.docs) {
           final data = doc.data();
           // Move to Bill-Origin
           batch.set(FirebaseFirestore.instance.collection('bill_origin').doc(doc.id), {
             ...data,
             'status': 'verified'
           });
           // Delete from Temp
           batch.delete(doc.reference);
        }

        await batch.commit();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date Verified! All temp bills moved to origin.')));
        }
     }
  }
  Future<void> _showRedoDialog(double originalTotal, DateTime start, DateTime end) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-do Transparency Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will CLEAR the current transparency session for this date and auto-fill it with original bills until the target value is reached.'),
            const SizedBox(height: 16),
            Text('Original Total: LKR ${originalTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Transparency Value (LKR)',
                border: OutlineInputBorder(),
                prefixText: 'LKR ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
               if (controller.text.isEmpty) return;
               Navigator.pop(ctx, true);
            }, 
            child: const Text('Start Auto-Fill')
          ),
        ],
      )
    );

    if (confirm == true) {
       final target = double.tryParse(controller.text) ?? 0.0;
       if (target > 0) {
          await _regenerateTransparency(start, end, target);
       }
    }
  }

  Future<void> _regenerateTransparency(DateTime start, DateTime end, double targetValue) async {
     try {
       // 1. Show Loading
       showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

       final firestore = FirebaseFirestore.instance;
       final batch = firestore.batch();

       // 2. Clear Existing Transparency Data for this Date
       // Query both collections
       final tempSnapshot = await firestore.collection('temp_origin')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();
       
       final originSnapshot = await firestore.collection('bill_origin')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

       for (var doc in tempSnapshot.docs) batch.delete(doc.reference);
       for (var doc in originSnapshot.docs) batch.delete(doc.reference);

       // 3. Fetch Original Bills (Sorted by Time for Organic Growth check, but shuffled for random selection)
       final originalSnapshot = await firestore.collection('bills')
          .where('createdAt', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
          .get();
       
       // Randomize the list to simulate "realistic" distribution throughout the day
       // instead of just filling up the morning hours first.
       final allBills = originalSnapshot.docs.toList();
       allBills.shuffle();

       double currentTotal = 0.0;
       int addedCount = 0;

       // 4. Smart Selection Algorithm (Randomized Greedy)
       for (var doc in allBills) {
          final data = doc.data();
          final amount = (data['totalAmount'] as num).toDouble();

          // Simple Greedy on Shuffled List:
          // Try to fit this bill into the remaining budget.
          // This naturally picks bills from different times of the day.
          
          if (currentTotal + amount <= targetValue * 1.05) { // Allow slight overshoot (5%)
             // Add to Temp Origin
             final newDocRef = firestore.collection('temp_origin').doc(doc.id);
             
             // Ensure Timestamp is set correctly from original data
             dynamic originalTimestamp = data['createdAt'];
             if (originalTimestamp is String) {
                originalTimestamp = Timestamp.fromDate(DateTime.parse(originalTimestamp));
             }

             batch.set(newDocRef, {
               ...data,
               'timestamp': originalTimestamp,
               'status': 'pending',
             });

             currentTotal += amount;
             addedCount++;
          }
       }

       // 5. Commit
       await batch.commit();
       
       // 6. Dismiss Loading & Notify
       if (mounted) {
          Navigator.pop(context); // Dismiss Loading
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Regenerated Session! Added $addedCount bills. Total: ${currentTotal.toStringAsFixed(0)}')));
       }

     } catch (e) {
       if (mounted) Navigator.pop(context); // Dismiss Loading
       print('Error regenerating: $e');
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }
}
