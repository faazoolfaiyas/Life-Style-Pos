import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_model.dart';

import '../../../../features/products/data/services/stock_service.dart';
import '../../../../features/products/data/models/stock_model.dart';
import '../../../../features/products/data/models/attribute_models.dart';
import '../../../../features/products/data/models/product_model.dart'; // For Product
import 'package:uuid/uuid.dart';

import '../../../../features/products/data/services/product_service.dart';
import '../../../../features/products/data/models/audit_model.dart';
import 'package:rxdart/rxdart.dart';

final posServiceProvider = Provider((ref) => PosService(ref.watch(stockServiceProvider), ref.watch(productServiceProvider)));

class PosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StockService _stockService;
  final ProductService _productService; // Added

  PosService(this._stockService, this._productService);

  // Save a completed bill and update stock
  Future<void> processCheckout(Bill bill, List<ProductSize> allSizes, List<ProductColor> allColors) async {
    print('Processing checkout for Bill ${bill.billNumber} with ${bill.items.length} items (Edit Mode: ${bill.originalBillId != null})');
    final batch = _firestore.batch();
    
    // 1. Save Bill (Overwrite if exists using same ID)
    final billRef = _firestore.collection('bills').doc(bill.id);
    batch.set(billRef, bill.toMap(), SetOptions(merge: true));

    // 2. Manage Stock Updates
    if (bill.originalBillId != null) {
      // Delta Update (Smart Edit)
      await _handleEditStockUpdate(bill, allSizes, allColors, batch);
    } else {
      // Standard Deduction (New Bill)
      await _handleNewBillStockDeduction(bill, allSizes, allColors, batch);
      _logBillHistory(bill.id, 'Bill Created', 'Items: ${bill.items.length}, Total: ${bill.totalAmount}', batch);
    }

    print('Committing checkout batch...');
    await batch.commit();
    print('Checkout batch committed successfully.');

    // --- Auto-Transparency Trigger ---
    try {
      final configDoc = await _firestore.collection('bill_settings').doc('config').get();
      if (configDoc.exists) {
        final targetVal = (configDoc.data()?['origin_target_value'] as num?)?.toDouble() ?? 0.0;
        if (targetVal > 0) {
           print('Triggering Auto-Transparency for Target: $targetVal');
           // Fire and forget? Or await? Await to ensure consistency before UI updates.
           // Use bill.createdAt for the date
           await _regenerateDailyTransparency(bill.createdAt, targetVal);
        }
      }
    } catch (e) {
      print('Auto-Transparency Trigger Failed: $e');
    }
  }

  // --- Auto-Transparency Algorithm ---
  Future<void> _regenerateDailyTransparency(DateTime date, double targetValue) async {
     try {
       final start = DateTime(date.year, date.month, date.day);
       final end = start.add(const Duration(days: 1));
       
       print('Regenerating Transparency for $start with Target $targetValue');

       final batch = _firestore.batch();

       // 1. Clear Existing Transparency Data for this Date
       final tempSnapshot = await _firestore.collection('temp_origin')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();
       
       final originSnapshot = await _firestore.collection('bill_origin')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

       for (var doc in tempSnapshot.docs) batch.delete(doc.reference);
       for (var doc in originSnapshot.docs) batch.delete(doc.reference);

       // 2. Fetch Original Bills 
       final originalSnapshot = await _firestore.collection('bills')
          .where('createdAt', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
          .get();

       // 3. Randomize Distribution
       final allBills = originalSnapshot.docs.toList();
       allBills.shuffle(); // Valid "Random Look"

       double currentTotal = 0.0;
       int addedCount = 0;

       // 4. Smart Selection (Randomized Greedy)
       for (var doc in allBills) {
          final data = doc.data();
          final amount = (data['totalAmount'] as num).toDouble();
          
          if (currentTotal + amount <= targetValue * 1.05) { 
             final newDocRef = _firestore.collection('temp_origin').doc(doc.id);
             
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

       await batch.commit();
       print('Auto-Transparency Complete. Added $addedCount bills. Total: $currentTotal');

     } catch (e) {
       print('Error in _regenerateDailyTransparency: $e');
     }
  }

  // --- New Helper: Standard Deduction ---
  Future<void> _handleNewBillStockDeduction(Bill bill, List<ProductSize> allSizes, List<ProductColor> allColors, WriteBatch batch) async {
      for (var item in bill.items) {
          if (item.productId == 'TEMP-001') continue; // Skip Quick Sale items

          if (item.quantity > 0) {
             await _resolveAndDeduct(item, item.quantity, allSizes, allColors, batch);
          } else if (item.quantity < 0) {
             // Handle Return (add back to stock)
             // We pass positive quantity for restoration
             // We use a simplified item with positive qty for the restore function
             final restoreItem = item.copyWith(quantity: item.quantity.abs());
             await _restoreStock(restoreItem, allSizes, allColors, batch, reason: 'Bill Return/Exchange');
          }
      }
  }

  // --- New Helper: Delta Update (Edit Mode) ---
  Future<void> _handleEditStockUpdate(Bill newBill, List<ProductSize> allSizes, List<ProductColor> allColors, WriteBatch batch) async {
      // A. Fetch Old Bill
      // Note: If newBill.id == newBill.originalBillId, the doc might be partially updated in memory/transaction? 
      // But we haven't committed batch yet. Firestore.get() returns committed data. 
      // So fetching originalBillId (which is the same ID) gets the OLD state. Safe.
      final oldBillDoc = await _firestore.collection('bills').doc(newBill.originalBillId).get();
      
      if (!oldBillDoc.exists) {
          // Fallback: If old bill is missing, treat as new bill? 
          // Or duplicate deduction risk? Safest to just process as new items if NO record of old items exists.
          print('Warning: Original bill ${newBill.originalBillId} not found during edit. Treating as new transaction.');
          await _handleNewBillStockDeduction(newBill, allSizes, allColors, batch);
          return;
      }
      
      final oldBill = Bill.fromMap(oldBillDoc.data()!);
      print('Comparing Old Bill #${oldBill.billNumber} vs New Bill #${newBill.billNumber}');

      // B. Map Items by Key
      Map<String, double> oldQtyMap = {};
      Map<String, BillItem> oldItemMap = {}; // Retention for restoration context
      
      for (var item in oldBill.items) {
          if (item.productId == 'TEMP-001') continue; // Skip Quick Sale items
          final key = _getStockKey(item);
          oldQtyMap[key] = (oldQtyMap[key] ?? 0) + item.quantity;
          oldItemMap[key] = item;
      }

      Map<String, double> newQtyMap = {};
      Map<String, BillItem> newItemMap = {};
      
      for (var item in newBill.items) {
          if (item.productId == 'TEMP-001') continue; // Skip Quick Sale items
          final key = _getStockKey(item);
          newQtyMap[key] = (newQtyMap[key] ?? 0) + item.quantity;
          newItemMap[key] = item;
      }
      
      // C. Calculate Differences
      final allKeys = {...oldQtyMap.keys, ...newQtyMap.keys};
      
      for (var key in allKeys) {
          final oldQty = oldQtyMap[key] ?? 0;
          final newQty = newQtyMap[key] ?? 0;
          final diff = newQty - oldQty;
          
          if (diff == 0) continue; // No Change
          
          if (diff > 0) {
              // Stock Reduced (Updated Qty > Old Qty, or New Item)
              print('Delta: Deducting $diff for $key (Added/Increased)');
              // Use New Item Context
              await _resolveAndDeduct(newItemMap[key]!, diff.toInt(), allSizes, allColors, batch);
          } else {
              // Stock Returned (Updated Qty < Old Qty, or Removed Item)
              // Restore positive amount |diff|
              final restoreQty = diff.abs().toInt();
              print('Delta: Restoring $restoreQty for $key (Removed/Decreased)');
              
              // Use Old Item Context to ensure we restore what was originally taken
              final itemCtx = oldItemMap[key] ?? newItemMap[key]!; 
              final restoreItem = itemCtx.copyWith(quantity: restoreQty);
              
              await _restoreStock(restoreItem, allSizes, allColors, batch, reason: 'Bill Edit Adjustment');
          }
      }
      
      _logBillHistory(newBill.id, 'Bill Edited', 'Updated via Delta Sync', batch);
  }

  // --- Helper: Unique Check Key ---
  String _getStockKey(BillItem item) {
      if (item.stockId != null) return item.stockId!;
      // Fallback for legacy items without stockId
      return '${item.productId}_${item.selectedSize ?? "NA"}_${item.selectedColor ?? "NA"}';
  }

  // --- Helper: Resolve & Deduct Logic (Extracted) ---
  Future<void> _resolveAndDeduct(BillItem item, int qty, List<ProductSize> allSizes, List<ProductColor> allColors, WriteBatch batch) async {
      if (qty <= 0) return; // Should not happen in pure deduction logic

      print('Processing item: ${item.productName} (ID: ${item.productId}) - Deduct Qty: $qty');
      try {
        // Resolve Attributes
        final sizeObj = allSizes.firstWhere(
          (s) => s.code.trim().toLowerCase() == (item.selectedSize ?? '').trim().toLowerCase() || 
                 s.name.trim().toLowerCase() == (item.selectedSize ?? '').trim().toLowerCase() ||
                 s.id == item.selectedSize,
          orElse: () => ProductSize(name: 'Unknown', code: 'UNK')
        );

        String baseColorName = item.selectedColor ?? 'Unknown';
        if (baseColorName.contains(' - ')) {
           baseColorName = baseColorName.split(' - ').first.trim();
        }

        final colorObj = allColors.firstWhere(
          (c) => c.name.trim().toLowerCase() == baseColorName.trim().toLowerCase() || 
                 c.id == baseColorName,
          orElse: () => ProductColor(name: 'Unknown', hexCode: '#000000')
        );

        String? sizeId = sizeObj.id;
        String? colorId = colorObj.id;
        
        if (sizeId == null || colorId == null) {
          print('Warning: Missing attributes for ${item.productName}. Decrementing global count only.');
          _deductGlobalOnly(item.productId, qty, item.price, batch);
        } else {
           await _deductStock(item.productId, qty, sizeId, colorId, batch, stockId: item.stockId);
        }
      } catch (e) {
        print('Error updating stock for ${item.productName}: $e');
        try {
           _deductGlobalOnly(item.productId, qty, item.price, batch);
        } catch (globalErr) {
           print('Critical: Failed to decrement even global stock: $globalErr');
        }
      }
  }

  void _logBillHistory(String billId, String action, String details, WriteBatch batch) {
      final historyRef = _firestore.collection('bills').doc(billId).collection('history').doc();
      batch.set(historyRef, {
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
  }

  void _deductGlobalOnly(String productId, int quantityToDeduct, double retailPrice, WriteBatch batch) {
      final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);
      
      final totalDeductedSales = quantityToDeduct * retailPrice;

      batch.update(productRef, {
        'stockQuantity': FieldValue.increment(-quantityToDeduct),
        'totalSales': FieldValue.increment(-totalDeductedSales),
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  Future<void> _deductStock(String productId, int quantityToDeduct, String sizeId, String colorId, WriteBatch batch, {String? stockId}) async {
      print('[Stock Debug] Deducting: Product: $productId, Size: $sizeId, Color: $colorId, Qty: $quantityToDeduct, StockId: $stockId');
      
      final stocksRef = _firestore.collection('Products').doc('stocks').collection(productId);
      
      List<DocumentSnapshot> targetDocs = [];

      if (stockId != null) {
         final doc = await stocksRef.doc(stockId).get();
         if (doc.exists) {
            targetDocs = [doc];
         } else {
             print('[Stock Debug] StockId $stockId not found. Falling back to FIFO.');
         }
      }

      if (targetDocs.isEmpty) {
        // FIFO Fallback
        QuerySnapshot querySnapshot;
        try {
           querySnapshot = await stocksRef
            .where('sizeId', isEqualTo: sizeId)
            .where('colorId', isEqualTo: colorId)
            .get();
           targetDocs = querySnapshot.docs.toList()
             ..sort((a, b) {
                final dateA = (a.data() as Map<String, dynamic>?)?['dateAdded'] as Timestamp?;
                final dateB = (b.data() as Map<String, dynamic>?)?['dateAdded'] as Timestamp?;
                if (dateA == null) return -1;
                if (dateB == null) return 1;
                return dateA.compareTo(dateB); 
             });
        } catch (e) {
          print('[Stock Debug] Query Failed: $e');
          rethrow;
        }
      }

      if (targetDocs.isEmpty) {
        throw Exception('No stock batches found for this variant ($sizeId / $colorId). Please check inventory.');
      }
      
      final sortedDocs = targetDocs;
      double totalDeductedCost = 0.0;
      double totalDeductedSales = 0.0;
      
      int remaining = quantityToDeduct;

      for (var doc in sortedDocs) {
        if (remaining <= 0) break;

        final data = doc.data() as Map<String, dynamic>;
        int currentQty = (data['quantity'] as num).toInt();
        double pPrice = (data['purchasePrice'] as num?)?.toDouble() ?? 0.0;
        double rPrice = (data['retailPrice'] as num?)?.toDouble() ?? 0.0;
        
        if (currentQty <= 0) continue; 

        if (currentQty >= remaining) {
          // Fully covered
          batch.update(doc.reference, {'quantity': currentQty - remaining});
          totalDeductedCost += (remaining * pPrice);
          totalDeductedSales += (remaining * rPrice);
          remaining = 0;
          print('[Stock Debug] Deducted from Batch ${doc.id}');
        } else {
          // Partial cover
          batch.update(doc.reference, {'quantity': 0});
          totalDeductedCost += (currentQty * pPrice);
          totalDeductedSales += (currentQty * rPrice);
          remaining -= currentQty;
          print('[Stock Debug] Emptied Batch ${doc.id}. Needed $remaining more.');
        }
      }
      
      if (remaining > 0) {
        print('[Stock Debug] Stock Underflow ($remaining). Forcing deduction from last batch.');
        if (sortedDocs.isNotEmpty) {
           final lastDoc = sortedDocs.last; 
           final data = lastDoc.data() as Map<String, dynamic>;
           double pPrice = (data['purchasePrice'] as num?)?.toDouble() ?? 0.0;
           double rPrice = (data['retailPrice'] as num?)?.toDouble() ?? 0.0;
           
           batch.update(lastDoc.reference, {'quantity': FieldValue.increment(-remaining)});
           totalDeductedCost += (remaining * pPrice);
           totalDeductedSales += (remaining * rPrice);
        } else {
           throw Exception('Critical: Stock batches vanished during processing.');
        }
      }

      final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);
      batch.update(productRef, {
        'stockQuantity': FieldValue.increment(-quantityToDeduct),
        'totalCost': FieldValue.increment(-totalDeductedCost),
        'totalSales': FieldValue.increment(-totalDeductedSales),
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  // Save a Pending Bill
  Future<void> holdBill(Bill bill) async {
    await _firestore.collection('pending_bills').doc(bill.id).set(bill.toMap());
  }

  // Delete Pending Bill (after resuming)
  Future<void> deletePendingBill(String id) async {
    await _firestore.collection('pending_bills').doc(id).delete();
  }

  // Delete Completed Bill
  Future<void> deleteBill(String id) async {
    final batch = _firestore.batch();
    
    batch.delete(_firestore.collection('bills').doc(id));
    batch.delete(_firestore.collection('bill_origin').doc(id));
    batch.delete(_firestore.collection('temp_origin').doc(id));

    await batch.commit();
  }

  // Restore Stock from Bill (Now accepts batch)
  Future<void> restoreBillStock(Bill bill, List<ProductSize> allSizes, List<ProductColor> allColors, {required String userId, required String userEmail}) async {
    final batch = _firestore.batch();
    
    for (var item in bill.items) {
       if (item.productId == 'TEMP-001') continue; // Skip Quick Sale items
       await _restoreStock(item, allSizes, allColors, batch, reason: 'Bill Deletion');
    }
    
    await batch.commit();
    print('Stock restoration committed for Bill ${bill.billNumber}');
  }

  // CORE RESTORE LOGIC (Batched)
  Future<void> _restoreStock(BillItem item, List<ProductSize> allSizes, List<ProductColor> allColors, WriteBatch batch, {required String reason, String? userId, String? userEmail}) async {
      final quantity = item.quantity.abs(); // Ensure positive restoration
      if (quantity == 0) return;
      
      print('Restoring item: ${item.productName} ($quantity)');
      
      final sizeObj = allSizes.firstWhere(
        (s) => s.code.trim().toLowerCase() == (item.selectedSize ?? '').trim().toLowerCase() ||
               s.name.trim().toLowerCase() == (item.selectedSize ?? '').trim().toLowerCase() ||
               s.id == item.selectedSize, 
        orElse: () => ProductSize(name: 'Unknown', code: 'UNK')
      );
      
      String baseColorName = item.selectedColor ?? 'Unknown';
      if (baseColorName.contains(' - ')) {
         baseColorName = baseColorName.split(' - ').first.trim();
      }

      final colorObj = allColors.firstWhere(
        (c) => c.name.trim().toLowerCase() == baseColorName.trim().toLowerCase() ||
               c.id == baseColorName,
        orElse: () => ProductColor(name: 'Unknown', hexCode: '#000000')
      );
      
      if (sizeObj.id == null || colorObj.id == null) {
          print('CRITICAL: Cannot resolve attributes for ${item.productName}. SizeId: ${sizeObj.id}, ColorId: ${colorObj.id}');
          throw Exception('Cannot restore stock for ${item.productName}: Invalid Size/Color combination in system.');
      }

      final stocksRef = _firestore.collection('Products').doc('stocks').collection(item.productId);
      
      DocumentSnapshot? targetBatch;

      if (item.stockId != null) {
          final doc = await stocksRef.doc(item.stockId).get();
          if (doc.exists) {
            targetBatch = doc;
          }
      }

      if (targetBatch == null) {
          final querySnapshot = await stocksRef
              .where('sizeId', isEqualTo: sizeObj.id)
              .where('colorId', isEqualTo: colorObj.id)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
             final sortedDocs = querySnapshot.docs.toList()
               ..sort((a, b) {
                  final dateA = (a.data() as Map<String, dynamic>)['dateAdded'] as Timestamp?;
                  final dateB = (b.data() as Map<String, dynamic>)['dateAdded'] as Timestamp?;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA); 
               });
             targetBatch = sortedDocs.first;
          }
      }

      double restoredCost = 0.0;
      double restoredSales = 0.0;

      if (targetBatch != null) {
        batch.update(targetBatch.reference, {
          'quantity': FieldValue.increment(quantity)
        });
        
        final data = targetBatch.data() as Map<String, dynamic>;
        double pPrice = (data['purchasePrice'] as num?)?.toDouble() ?? 0.0;
        double rPrice = (data['retailPrice'] as num?)?.toDouble() ?? 0.0;
        
        restoredCost = quantity * pPrice;
        restoredSales = quantity * rPrice;
        
        print('Restoring to Batch ${targetBatch.id}');
      } else {
        final nextBatchInfo = await _stockService.getNextBatchNumber(item.productId);
        final newStockItem = StockItem(
            id: const Uuid().v4(),
            productId: item.productId,
            batchNumber: nextBatchInfo,
            supplierId: 'RETURN/RESTORE',
            description: reason,
            sizeId: sizeObj.id!,
            colorId: colorObj.id!,
            purchasePrice: 0, 
            retailPrice: item.price,
            wholesalePrice: 0,
            quantity: quantity,
            dateAdded: DateTime.now(),
          );
          
         final docRef = stocksRef.doc(newStockItem.id);
         batch.set(docRef, newStockItem.toMap());
         
         restoredCost = 0.0; 
         restoredSales = quantity * item.price;
      }

      final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(item.productId);
      batch.update(productRef, {
         'stockQuantity': FieldValue.increment(quantity),
         'totalCost': FieldValue.increment(restoredCost),
         'totalSales': FieldValue.increment(restoredSales),
         'updatedAt': FieldValue.serverTimestamp(),
      });
      
      final historyRef = productRef.collection('history').doc();
      final logEntry = AuditLogEntry(
        id: historyRef.id,
        userId: userId ?? 'POS_SYSTEM',
        userEmail: userEmail ?? 'System',
        action: 'Stock Restored',
        details: 'Restored $quantity x ${item.productName} ($reason)',
        timestamp: DateTime.now(),
      );
      batch.set(historyRef, logEntry.toMap());
  }

  Stream<List<Bill>> getRecentBills({bool isAdministrator = false}) {
    if (isAdministrator) {
      return _firestore
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Bill.fromMap(doc.data())).toList());
    } else {
       // Standard User: Curated View
       // We can't easily limit 20 across two collections without fetching all.
       // Approximation: Fetch recent 20 from both, merge, sort, take top 20.
       
       final originStream = _firestore.collection('bill_origin').orderBy('timestamp', descending: true).limit(20).snapshots();
       final tempStream = _firestore.collection('temp_origin').orderBy('timestamp', descending: true).limit(20).snapshots();
       
       return Rx.zip([originStream, tempStream], (lists) => lists).asyncMap((lists) async {
           final allDocs = [...lists[0].docs, ...lists[1].docs];
           
           // Sort by timestamp desc and take top 20 IDs
           allDocs.sort((a, b) {
              final tA = (a.data()['timestamp'] as Timestamp?) ?? Timestamp.now();
              final tB = (b.data()['timestamp'] as Timestamp?) ?? Timestamp.now();
              return tB.compareTo(tA);
           });
           
           final topDocs = allDocs.take(20).toList();
           if (topDocs.isEmpty) return [];
           
           final chunk = topDocs.map((d) => d.id).toList();
           
           // Fetch full data
           final query = await _firestore.collection('bills').where(FieldPath.documentId, whereIn: chunk).get();
           final bills = query.docs.map((d) => Bill.fromMap(d.data())).toList();
           
           // Re-sort because whereIn doesn't preserve order
           bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
           return bills;
       });
    }
  }

  // Used for Dashboard Analytics (Last 30 Days)
  // UPDATED: Controlled Transparency Logic
  Stream<List<Bill>> getBillsInRange(DateTime start, DateTime end, {bool isAdministrator = false}) {
    if (isAdministrator) {
      // Admin: See Master Record
      return _firestore
          .collection('bills')
          .where('createdAt', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: end.toIso8601String())
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Bill.fromMap(doc.data())).toList());
    } else {
      // Standard User: See Curated Record (Bill-Origin + Temp-Origin)
      // fetching from two collections and merging
      
      final originStream = _firestore
          .collection('bill_origin')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .snapshots();

      final tempStream = _firestore
          .collection('temp_origin')
           .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .snapshots();
          
      // Combine streams
      return Rx.zip([originStream, tempStream], (lists) => lists).asyncMap((lists) async {
         final originDocs = lists[0].docs;
         final tempDocs = lists[1].docs;
         
         final allIds = <String>{};
         for (var d in originDocs) allIds.add(d.id);
         for (var d in tempDocs) allIds.add(d.id);
         
         if (allIds.isEmpty) return <Bill>[]; // Explicit type
         
         // Fetch actual bill data (limited to 10 at a time or simple loop)
         List<Bill> finalBills = [];
         
         // Batch fetch by 10 ids
         final chunks = <List<String>>[];
         final idsList = allIds.toList();
         for (var i = 0; i < idsList.length; i += 10) {
            chunks.add(idsList.sublist(i, i + 10 > idsList.length ? idsList.length : i + 10));
         }
         
         for (var chunk in chunks) {
            final query = await _firestore.collection('bills').where(FieldPath.documentId, whereIn: chunk).get();
            finalBills.addAll(query.docs.map((d) => Bill.fromMap(d.data())));
         }
         
         // Sort by date descending
         finalBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
         
         return finalBills;
      });
    }
  }

  Stream<List<Bill>> getPendingBills() {
    return _firestore
        .collection('pending_bills')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Bill.fromMap(doc.data())).toList());
  }

  // Universal Search Bypass: Fetch ANY bill by ID directly from Master Record
  Future<Bill?> getBillById(String id) async {
    try {
      final doc = await _firestore.collection('bills').doc(id).get();
      if (doc.exists) {
        return Bill.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error fetching bill by ID: $e');
      return null;
    }
  }

  // --- Quick Sale Support ---
  Future<void> updateQuickSaleCost(String billId, String productId, double costPrice) async {
    final billDoc = await _firestore.collection('bills').doc(billId).get();
    if (!billDoc.exists) throw Exception('Bill not found');

    final bill = Bill.fromMap(billDoc.data()!);
    final updatedItems = bill.items.map((item) {
      if (item.productId == productId && (item.costPrice == null || item.costPrice == 0.0)) {
        return item.copyWith(costPrice: costPrice);
      }
      return item;
    }).toList();

    await _firestore.collection('bills').doc(billId).update({
      'items': updatedItems.map((x) => x.toMap()).toList(),
    });
  }

  Stream<List<Bill>> getPendingCostBills() {
    // We fetch all bills and filter locally since array-contains doesn't work for partial object matching
    // For efficiency, in a real app, this should be a cloud function or a dedicated 'pending_costs' collection.
    // For now, streaming recent bills and filtering is acceptable. 
    return _firestore
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .limit(100) // Limit to recent 100 bills for performance
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final items = data['items'] as List<dynamic>?;
            if (items == null) return false;
            return items.any((item) {
               return item['productId'] == 'TEMP-001' && (item['costPrice'] == null || item['costPrice'] == 0.0);
            });
          }).map((doc) => Bill.fromMap(doc.data())).toList();
    });
  }
}
