import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../models/audit_model.dart';

final productServiceProvider = Provider((ref) => ProductService());

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Product>> getProducts() {
    return _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<AuditLogEntry>> getHistory(String productId) {
    return _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AuditLogEntry.fromMap(doc.data())).toList();
    });
  }

  Future<void> addProduct(Product product) async {
    final generatedCode = await _generateProductCode(product.categoryId);
    
    // Ensure stockQuantity is 0 and set generated code
    final newProduct = Product(
      id: product.id,
      productCode: generatedCode,
      name: product.name,
      description: product.description,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      images: product.images,
      price: product.price,
      minPrice: 0.0,
      maxPrice: 0.0,
      stockQuantity: 0, // Always 0 initially
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      isActive: product.isActive,
    );

    // Using auto-ID for document, but keeping consistent path
    await _firestore
        .collection('Products') // Collection
        .doc('details') // Document
        .collection('datas') // Sub-collection
        .add(newProduct.toMap());
  }

  Future<String> _generateProductCode(String categoryId) async {
    try {
      // 1. Get Category Index from the correct collection path
      final categoryDoc = await _firestore
          .collection('attributes')
          .doc('category')
          .collection('data')
          .doc(categoryId)
          .get();

      if (!categoryDoc.exists) return '000'; // Fallback
      
      final categoryIndex = categoryDoc.data()?['index'] ?? 0;

      // 2. Count existing products in this category (using efficient count aggregate)
      final productQuery = await _firestore
          .collection('Products')
          .doc('details')
          .collection('datas')
          .where('categoryId', isEqualTo: categoryId)
          .count()
          .get();

      final count = productQuery.count ?? 0;
      
      // 3. Format: {CategoryIndex}{Count + 1}
      return '$categoryIndex${count + 1}';
    } catch (e) {
      print('Error generating product code: $e');
      return DateTime.now().millisecondsSinceEpoch.toString().substring(8); // Fallback
    }
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    await _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('Products').doc('details').collection('datas').doc(id).delete();
  }

  Future<Product?> getProductByCode(String code) async {
    try {
      final query = await _firestore
          .collection('Products')
          .doc('details')
          .collection('datas')
          .where('productCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Product.fromMap(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error finding product by code: $e');
      return null;
    }
  }

  Future<bool> isCategoryUsed(String categoryId) async {
    final query = await _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> addAuditLog(String productId, AuditLogEntry entry) async {
    await _firestore
        .collection('Products')
        .doc('details')
        .collection('datas')
        .doc(productId)
        .collection('history')
        .add(entry.toMap());
  }
}
