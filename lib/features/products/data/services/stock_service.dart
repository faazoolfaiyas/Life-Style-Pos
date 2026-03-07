import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_model.dart';
import '../models/audit_model.dart';
import 'package:uuid/uuid.dart';

final stockServiceProvider = Provider((ref) => StockService());

// Combined provider for optimizations (Using String key "pid|sid|cid" for value equality)
final variantStockInfoProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 3) throw Exception('Invalid key format');
  
  final pid = parts[0];
  final sid = parts[1];
  final cid = parts[2];

  final stockService = ref.read(stockServiceProvider);
  final qty = await stockService.getVariantStockCount(
      productId: pid, sizeId: sid, colorId: cid);
  final cost = await stockService.getVariantLastCost(
      productId: pid, sizeId: sid, colorId: cid);
  return {'qty': qty, 'cost': cost};
});

class StockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to update product price range based on current stocks
  Future<void> updateProductPriceRange(String productId) async {
    final stocksQuery = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .where('quantity', isGreaterThan: 0) // Only count available items
        .get();

    if (stocksQuery.docs.isEmpty) {
      // No stock, reset prices
      await _firestore.collection('Products').doc('details').collection('datas').doc(productId).update({
        'price': 0.0,
        'minPrice': 0.0,
        'maxPrice': 0.0,
      });
      return;
    }

    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var doc in stocksQuery.docs) {
      final price = (doc.data()['retailPrice'] as num?)?.toDouble() ?? 0.0;
      if (price < min) min = price;
      if (price > max) max = price;
    }

    if (min == double.infinity) min = 0.0;
    if (max == double.negativeInfinity) max = 0.0;

    await _firestore.collection('Products').doc('details').collection('datas').doc(productId).update({
      'price': min, // Show min price as main
      'minPrice': min,
      'maxPrice': max,
    });
  }



  // Re-index all product designs (Migration Tool)
  Future<int> reindexProductDesigns() async {
    final productsSnapshot = await _firestore.collection('Products').doc('details').collection('datas').get();
    var batch = _firestore.batch();
    int batchCount = 0;
    int updatedProducts = 0;

    for (var doc in productsSnapshot.docs) {
      final productId = doc.id;
      
      // Get stocks for this product
      final stocksQuery = await _firestore
          .collection('Products')
          .doc('stocks')
          .collection(productId)
          .get();

      final Set<String> designIds = {};
      for (var stockDoc in stocksQuery.docs) {
        final data = stockDoc.data();
        if (data['designId'] != null && (data['designId'] as String).isNotEmpty) {
          designIds.add(data['designId'] as String);
        }
      }

      if (designIds.isNotEmpty) {
        batch.update(doc.reference, {
          'designIds': designIds.toList(),
        });
        updatedProducts++;
        
        batchCount++;
        if (batchCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }
    }
    if (batchCount > 0) {
      await batch.commit();
    }
    return updatedProducts;
  }

  // Recalculate Total Cost, Sales, and Qty for ALL Products (Correction Tool)
  Future<int> recalculateInventoryTotals() async {
    final productsSnapshot = await _firestore.collection('Products').doc('details').collection('datas').get();
    var batch = _firestore.batch();
    int batchCount = 0;
    int updatedCount = 0;

    for (var doc in productsSnapshot.docs) {
      final productId = doc.id;
      
      // Get all stocks for this product
      final stocksQuery = await _firestore
          .collection('Products')
          .doc('stocks')
          .collection(productId)
          .get();

      double totalCost = 0.0;
      double totalSales = 0.0;
      int totalQty = 0;

      for (var sDoc in stocksQuery.docs) {
        final data = sDoc.data();
        final qty = (data['quantity'] as int?) ?? 0;
        final cost = (data['purchasePrice'] as num?)?.toDouble() ?? 0.0;
        final sell = (data['retailPrice'] as num?)?.toDouble() ?? 0.0;
        
        if (qty > 0) {
          totalCost += (cost * qty);
          totalSales += (sell * qty);
          totalQty += qty;
        }
      }
      
      // Update Product
      batch.update(doc.reference, {
        'stockQuantity': totalQty,
        'totalCost': totalCost,
        'totalSales': totalSales,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updatedCount++;
      batchCount++;

      if (batchCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }
    return updatedCount;
  }

  // Recalculate prices for ALL products (Migration/Fix)
  Future<void> recalculateAllProductPrices() async {
    final productsSnapshot = await _firestore.collection('Products').doc('details').collection('datas').get();
    
    for (var doc in productsSnapshot.docs) {
      await updateProductPriceRange(doc.id);
    }
  }

  // Get stock items for a specific product
  Stream<List<StockItem>> getStockForProduct(String productId) {
    return _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId) // Uses productId as collection name
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => StockItem.fromMap(doc.data())).toList();
    });
  }

  // Get Summary of Total Stock for a product (Optional helper)
  Future<int> getTotalStockCount(String productId) async {
    final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .get();
    
    return query.docs.fold<int>(0, (int sum, doc) => sum + (doc.data()['quantity'] as int? ?? 0));
  }

  // Get next batch number for a product
  Future<int> getNextBatchNumber(String productId) async {
    final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .orderBy('batchNumber', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return 1;
    return (query.docs.first.data()['batchNumber'] as int) + 1;
  }

  // Add multiple stock items (batch add)
  Future<void> addStockBatch(List<StockItem> items, {required String userId, required String userEmail}) async {
    final batch = _firestore.batch();
    
    // Check if items are empty to prevent errors, though UI checks this
    if (items.isEmpty) return;

    final productId = items.first.productId;
    final collection = _firestore.collection('Products').doc('stocks').collection(productId);

    for (var item in items) {
      final docRef = collection.doc(item.id);
      batch.set(docRef, item.toMap());
    }

    // Also update the total stock count in the main Product document
    final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);
    
    // We increment the stockQuantity and update designIds.
    int totalNewQty = 0;
    double totalAddedCost = 0.0;
    double totalAddedSales = 0.0;

    final Set<String> newDesignIds = {};
    
    for (var item in items) {
      totalNewQty += item.quantity;
      totalAddedCost += (item.purchasePrice * item.quantity);
      totalAddedSales += (item.retailPrice * item.quantity);
      if (item.designId != null && item.designId!.isNotEmpty) {
        newDesignIds.add(item.designId!);
      }
    }

    final Map<String, dynamic> productUpdate = {
      'stockQuantity': FieldValue.increment(totalNewQty),
      'totalCost': FieldValue.increment(totalAddedCost),
      'totalSales': FieldValue.increment(totalAddedSales),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newDesignIds.isNotEmpty) {
      productUpdate['designIds'] = FieldValue.arrayUnion(newDesignIds.toList());
    }

    batch.update(productRef, productUpdate);

    // --- Audit Log ---
    final auditRef = _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .doc();

    final auditEntry = AuditLogEntry(
      id: auditRef.id,
      userId: userId,
      userEmail: userEmail,
      action: 'Stock Batch Added',
      details: 'Added ${items.length} items (Batch #${items.first.batchNumber})',
      timestamp: DateTime.now(),
    );

    batch.set(auditRef, auditEntry.toMap());
    // -----------------

    await batch.commit();
    
    // Update Price Range
    await updateProductPriceRange(productId);
  }

  // Get latest cost price for a variant (Robust Client-Side Sort with Fallback)
  Future<double?> getVariantLastCost({
    required String productId, 
    required String sizeId, 
    required String colorId,
    String? supplierId,
    String? designId,
  }) async {
    try {
     final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .where('sizeId', isEqualTo: sizeId)
        .where('colorId', isEqualTo: colorId)
        // Removed orderBy/limit to avoid index issues. doing client-side sort.
        .get();

      if (query.docs.isEmpty) return null;
      
      var docs = query.docs.map((d) => d.data()).toList();

      // Sort by dateAdded descending (Global Sort first)
      docs.sort((a, b) {
        final dateA = (a['dateAdded'] as Timestamp).toDate();
        final dateB = (b['dateAdded'] as Timestamp).toDate();
        return dateB.compareTo(dateA); 
      });

      // Strict Filter: Design (If design changes, price/item likely changes)
      if (designId != null) {
        docs = docs.where((d) => d['designId'] == designId).toList();
      }

      if (docs.isEmpty) return null;

      // Strategy: 
      // 1. If Supplier selected, try to find latest from THAT Supplier.
      // 2. If not found (or no supplier selected), use Global Latest (Fallback).
      
      if (supplierId != null) {
        final supplierMatch = docs.where((d) => d['supplierId'] == supplierId).firstOrNull;
        if (supplierMatch != null) {
          return (supplierMatch['purchasePrice'] as num?)?.toDouble();
        }
      }

      // Fallback to latest global
      return (docs.first['purchasePrice'] as num?)?.toDouble();

    } catch (e) {
      print('Error fetching last cost: $e');
      return null;
    }
  }

  // Update a stock item
  Future<void> updateStock(StockItem item, {required String userId, required String userEmail}) async {
    final productId = item.productId;
    final stockRef = _firestore.collection('Products').doc('stocks').collection(productId).doc(item.id);
    final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);


    // Audit ref
    final auditRef = _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .doc();

    try {
      final batch = _firestore.batch();

      // Get Current State (Optimistic Concurrency - standard fetch)
      // Note: On Windows, runTransaction crashes due to native threading issues. 
      // Switching to Batch Writes is safer here.
      final stockDoc = await stockRef.get();
      if (!stockDoc.exists) throw Exception("Stock item not found");

      final oldQty = (stockDoc.data()?['quantity'] as int?) ?? 0;
      final oldBuy = (stockDoc.data()?['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      final oldSell = (stockDoc.data()?['retailPrice'] as num?)?.toDouble() ?? 0.0;
      
      final newQty = item.quantity;
      final diffQty = newQty - oldQty;
      
      final oldTotalCost = oldQty * oldBuy;
      final newTotalCost = newQty * item.purchasePrice;
      final diffCost = newTotalCost - oldTotalCost;

      final oldTotalSales = oldQty * oldSell;
      final newTotalSales = newQty * item.retailPrice;
      final diffSales = newTotalSales - oldTotalSales;

      // Detect Changes for Audit
      List<String> changes = [];
      if (diffQty != 0) changes.add('Qty: $oldQty -> $newQty');
      if (item.purchasePrice != oldBuy) changes.add('Buy: $oldBuy -> ${item.purchasePrice}');
      if (item.retailPrice != oldSell) changes.add('Sell: $oldSell -> ${item.retailPrice}');
      
      String auditDetails = changes.isEmpty ? 'Stock Updated' : changes.join(', ');

      final updateData = item.toMap();
      updateData['editedAt'] = FieldValue.arrayUnion([Timestamp.now()]);

      batch.update(stockRef, updateData);
      
      final bool hasDesign = item.designId != null && item.designId!.isNotEmpty;
      
      // Update Product if any value affecting metric changed
      if (diffQty != 0 || diffCost != 0 || diffSales != 0 || hasDesign) {
        final Map<String, dynamic> productUpdate = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (diffQty != 0) productUpdate['stockQuantity'] = FieldValue.increment(diffQty);
        if (diffCost != 0) productUpdate['totalCost'] = FieldValue.increment(diffCost);
        if (diffSales != 0) productUpdate['totalSales'] = FieldValue.increment(diffSales);
        
        if (hasDesign) {
           productUpdate['designIds'] = FieldValue.arrayUnion([item.designId!]);
        }
        
        batch.update(productRef, productUpdate);
      }

      if (changes.isNotEmpty) {
        final auditEntry = AuditLogEntry(
          id: auditRef.id,
          userId: userId,
          userEmail: userEmail,
          action: 'Stock Item Updated',
          details: 'Item ${item.id}: $auditDetails',
          timestamp: DateTime.now(),
        );
        batch.set(auditRef, auditEntry.toMap());
      }
      
      await batch.commit();

      // Update Price Range
      try {
        await updateProductPriceRange(productId);
      } catch (e) {
        print('Price update warning: $e');
      }

    } catch (e) {
      print('Update Stock Error: $e');
      throw Exception('Failed to update stock: $e');
    }
  }

  // Delete a stock item
  Future<void> deleteStock(String productId, String stockId, {required String userId, required String userEmail}) async {
    if (productId.isEmpty || stockId.isEmpty) throw Exception('Invalid ID');

    final stockRef = _firestore.collection('Products').doc('stocks').collection(productId).doc(stockId);
    final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);

    try {
      // Audit ref
      final auditRef = _firestore
          .collection('Products')
          .doc('details')
          .collection('datas')
          .doc(productId)
          .collection('history')
          .doc();

      final batch = _firestore.batch();
      
      // Get Current State (Standard get)
      final stockDoc = await stockRef.get();
      if (!stockDoc.exists) return; // Already deleted

      final qty = (stockDoc.data()?['quantity'] as int?) ?? 0;
      final buy = (stockDoc.data()?['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      final sell = (stockDoc.data()?['retailPrice'] as num?)?.toDouble() ?? 0.0;

      batch.delete(stockRef);
      
      if (qty > 0) {
        batch.update(productRef, {
          'stockQuantity': FieldValue.increment(-qty),
          'totalCost': FieldValue.increment(-(qty * buy)),
          'totalSales': FieldValue.increment(-(qty * sell)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Write Audit
      final auditEntry = AuditLogEntry(
        id: auditRef.id,
        userId: userId,
        userEmail: userEmail,
        action: 'Stock Item Deleted',
        details: 'Deleted Item $stockId',
        timestamp: DateTime.now(),
      );
      batch.set(auditRef, auditEntry.toMap());

      await batch.commit();

      // Update Price Range
      await updateProductPriceRange(productId);
    } catch (e) {
      print('Delete Stock Error: $e');
      throw Exception('Failed to delete stock: $e');
    }
  }

  // Update Supplier or Design for a whole batch
  Future<void> updateBatchFields(String productId, int batchNumber, {String? supplierId, String? designId, required String userId, required String userEmail}) async {
    final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .where('batchNumber', isEqualTo: batchNumber)
        .get();
    
    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    Map<String, dynamic> updates = {
      'editedAt': FieldValue.arrayUnion([Timestamp.now()]),
    };
    if (supplierId != null) updates['supplierId'] = supplierId;
    if (designId != null) updates['designId'] = designId;

    for (var doc in query.docs) {
      batch.update(doc.reference, updates);
    }

    // Use batch update to add designId to product if present
    if (designId != null && designId.isNotEmpty) {
       final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);
       batch.update(productRef, {
         'designIds': FieldValue.arrayUnion([designId]),
         'updatedAt': FieldValue.serverTimestamp(),
       });
    }

    final auditRef = _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .doc();

    final auditEntry = AuditLogEntry(
      id: auditRef.id,
      userId: userId,
      userEmail: userEmail,
      action: 'Batch Bulk Update',
      details: 'Batch #$batchNumber: ${supplierId != null ? "Supplier updated " : ""}${designId != null ? "Design updated" : ""}',
      timestamp: DateTime.now(),
    );
    batch.set(auditRef, auditEntry.toMap());

    try {
       await batch.commit();
    } catch (e) {
       print('Batch update failed: $e');
       throw Exception('Failed to update batch: $e');
    }
  }
  // Delete an entire stock batch safely
  Future<void> deleteStockBatch(String productId, int batchNumber, {required String userId, required String userEmail}) async {
    final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .where('batchNumber', isEqualTo: batchNumber)
        .get();

    if (query.docs.isEmpty) return;

    final batch = _firestore.batch();
    final productRef = _firestore.collection('Products').doc('details').collection('datas').doc(productId);

    int totalQtyToRemove = 0;
    double totalCostToRemove = 0.0;
    double totalSalesToRemove = 0.0;
    
    for (var doc in query.docs) {
      final qty = (doc.data()['quantity'] as int?) ?? 0;
      final buy = (doc.data()['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      final sell = (doc.data()['retailPrice'] as num?)?.toDouble() ?? 0.0;

      totalQtyToRemove += qty;
      totalCostToRemove += (qty * buy);
      totalSalesToRemove += (qty * sell);
      
      batch.delete(doc.reference);
    }

    if (totalQtyToRemove > 0) {
      batch.update(productRef, {
        'stockQuantity': FieldValue.increment(-totalQtyToRemove),
        'totalCost': FieldValue.increment(-totalCostToRemove),
        'totalSales': FieldValue.increment(-totalSalesToRemove),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Audit
    final auditRef = _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .doc();

    final auditEntry = AuditLogEntry(
      id: auditRef.id,
      userId: userId,
      userEmail: userEmail,
      action: 'Batch Deleted',
      details: 'Deleted Batch #$batchNumber (${query.docs.length} items)',
      timestamp: DateTime.now(),
    );
    batch.set(auditRef, auditEntry.toMap());

    try {
      await batch.commit();
      // Update Price Range
      try {
        await updateProductPriceRange(productId);
      } catch (e) {
        print('Price update warning: $e');
      }
    } catch (e) {
        print('Batch delete failed: $e');
        throw Exception('Failed to delete batch: $e');
    }
  }

  // Get single stock item from a known product
  Future<StockItem?> getStockItem(String productId, String stockId) async {
    try {
      final doc = await _firestore
          .collection('Products')
          .doc('stocks')
          .collection(productId)
          .doc(stockId)
          .get();

      if (doc.exists) {
        return StockItem.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting stock item: $e');
      return null;
    }
  }

  // Global search for a stock item by its ID (for POS scanning)
  Future<StockItem?> findStockItemById(String stockId) async {
     // ... legacy implementation kept but likely unused ...
     return null;
  }
  // Get aggregate stock count for a specific variant (Size + Color)
  Future<int> getVariantStockCount({
    required String productId,
    required String sizeId,
    required String colorId,
  }) async {
    final query = await _firestore
        .collection('Products')
        .doc('stocks')
        .collection(productId)
        .where('sizeId', isEqualTo: sizeId)
        .where('colorId', isEqualTo: colorId)
        .get();

    return query.docs.fold<int>(0, (sum, doc) => sum + (doc.data()['quantity'] as int? ?? 0));
  }
}
