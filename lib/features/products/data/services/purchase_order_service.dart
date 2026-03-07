import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/purchase_order_model.dart';
import '../../../settings/data/providers/settings_provider.dart';
import 'package:uuid/uuid.dart';

final purchaseOrderServiceProvider = Provider((ref) => PurchaseOrderService(ref));

class PurchaseOrderService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PurchaseOrderService(this._ref);

  // --- Collection References ---
  CollectionReference _getCollection(String productId) {
    return _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('purchase_orders');
  }

  // --- CRUD Operations ---

  Stream<List<PurchaseOrder>> getPurchaseOrders(String productId) {
    // Lazy Cleanup hook: When we fetch, we can check for expired items.
    // However, doing write on read stream can be tricky. 
    // We'll trust the UI or a separate init call to trigger cleanup, 
    // or just filter them out in the stream if we don't want to show them.
    // Ideally, we physically delete them. 
    cleanupExpiredOrders(productId);

    return _getCollection(productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PurchaseOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  // --- Global Queries ---
  
  Stream<List<PurchaseOrder>> getAllPendingOrdersStream() {
    // Uses Collection Group Query to fetch POs for ALL products.
    return _firestore.collectionGroup('purchase_orders')
        .snapshots()
        .map((snapshot) {
       return snapshot.docs.map((doc) => PurchaseOrder.fromMap(doc.data() as Map<String, dynamic>)).toList();
    });
  }

  Future<void> addPurchaseOrder(PurchaseOrder po) async {
    // Calculate Expiry based on settings
    final settingsAsync = _ref.read(settingsProvider); // Note: ideally use watch if inside a provider update, but read is fine here for fetching current state. 
    // However, since we are inside a method called by UI, reading the current state is correct.
    // Ensure we handle loading/error state safely by defaulting if not ready.
    final retentionDays = settingsAsync.value?.purchaseOrderRetentionDays ?? 30;
    
    final expiresAt = po.createdAt.add(Duration(days: retentionDays));
    
    final poWithExpiry = po.copyWith(expiresAt: expiresAt);

    await _getCollection(po.productId).doc(po.id).set(poWithExpiry.toMap());
  }

  Future<void> updatePurchaseOrder(PurchaseOrder po) async {
    // No audit history required for POs as per requirement.
    await _getCollection(po.productId).doc(po.id).update(po.toMap());
  }

  Future<void> deletePurchaseOrder(String productId, String poId) async {
    await _getCollection(productId).doc(poId).delete();
  }

  // --- Lazy Cleanup ---
  Future<void> cleanupExpiredOrders(String productId) async {
    final now = Timestamp.now();
    final expiredQuery = await _getCollection(productId)
        .where('expiresAt', isLessThan: now)
        .get();

    for (var doc in expiredQuery.docs) {
      await doc.reference.delete();
    }
  }

  // --- Smart Price Lookup (Logic Highlighting) ---
  
  // Finds the latest price for a specific variant (Design + Size + Color)
  // If supplierId is provided, looks for stocks from that supplier first.
  // If no stock from that supplier (or no supplier provided), looks for *any* latest stock.
  Future<double?> getLatestPrice({
    required String productId,
    required String sizeId,
    required String colorId,
    String? designId,
    String? supplierId,
  }) async {
    // We need to query the 'stocks' collection for this product
    final stocksRef = _firestore.collection('Products').doc('stocks').collection(productId);

    Query query = stocksRef
        .where('sizeId', isEqualTo: sizeId)
        .where('colorId', isEqualTo: colorId);
    
    if (designId != null) {
      query = query.where('designId', isEqualTo: designId);
    } else {
      query = query.where('designId', isNull: true);
    }
    
    // 1. Try with Supplier if provided (Client-Side Sorting to avoid Index)
    if (supplierId != null) {
      final supplierQuery = query.where('supplierId', isEqualTo: supplierId);
      final snapshot = await supplierQuery.get();
      
      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs;
        docs.sort((a, b) {
           final dateA = (a.data() as Map<String, dynamic>)['dateAdded'] as Timestamp;
           final dateB = (b.data() as Map<String, dynamic>)['dateAdded'] as Timestamp;
           return dateB.compareTo(dateA); // Descending
        });
        return (docs.first.data() as Map<String, dynamic>)['purchasePrice'] as double?;
      }
    }

    // 2. Fallback: Local Sort global (Client-Side Sorting to avoid Index)
    final snapshot = await query.get();
    
    if (snapshot.docs.isNotEmpty) {
      final docs = snapshot.docs;
      docs.sort((a, b) {
          final dateA = (a.data() as Map<String, dynamic>)['dateAdded'] as Timestamp;
          final dateB = (b.data() as Map<String, dynamic>)['dateAdded'] as Timestamp;
          return dateB.compareTo(dateA); // Descending
      });
      return (docs.first.data() as Map<String, dynamic>)['purchasePrice'] as double?;
    }

    // 3. Not found
    return null;
  }
}
