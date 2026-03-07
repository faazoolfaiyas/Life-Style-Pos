import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attribute_models.dart';

class AttributeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to get collection based on type
  CollectionReference _getCollection(String type) {
    return _firestore.collection('attributes').doc(type.toLowerCase()).collection('data');
  }

  // Collection References
  CollectionReference get _categories => _getCollection('category');
  CollectionReference get _sizes => _getCollection('size');
  CollectionReference get _colors => _getCollection('color');
  CollectionReference get _designs => _getCollection('design');

  // --- Generic Helpers ---
  Future<void> _add(CollectionReference collection, ProductAttribute item) async {
    await collection.add(item.toMap());
  }

  Future<void> _update(CollectionReference collection, String id, Map<String, dynamic> data) async {
    await collection.doc(id).update(data);
  }

  Future<void> _delete(CollectionReference collection, String id) async {
    await collection.doc(id).delete();
  }

  Stream<List<T>> _stream<T>(CollectionReference collection, T Function(Map<String, dynamic>, String) fromMap) {
    return collection.orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  // --- Smart Indexing Helper ---
  Future<int> _getNextIndex(CollectionReference collection) async {
    final snapshot = await collection.get();
    final indices = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['index'] as int? ?? 0)
        .where((index) => index > 0)
        .toSet();

    int nextIndex = 1;
    while (indices.contains(nextIndex)) {
      nextIndex++;
    }
    return nextIndex;
  }

  // --- Category ---
  Future<void> addCategory(ProductCategory category) async {
    int index = await _getNextIndex(_categories);
    category.index = index;
    // Set createdAt if not present (though model toMap handles null with serverTimestamp, setting it here ensures client-side consistency if needed immediately)
    category.createdAt ??= DateTime.now(); 
    await _add(_categories, category);
  }
  Future<void> updateCategory(String id, ProductCategory category) => _update(_categories, id, category.toMap());
  
  // Update Category Status Only
  Future<void> updateCategoryStatus(String id, bool isActive) async {
    await _categories.doc(id).update({'isActive': isActive});
  }

  Future<void> deleteCategory(String id) => _delete(_categories, id);
  Stream<List<ProductCategory>> getCategories() => _stream(_categories, ProductCategory.fromMap);

  // --- Size ---
  Future<void> addSize(ProductSize size) async {
     int index = await _getNextIndex(_sizes);
     size.index = index;
     size.createdAt ??= DateTime.now();
     await _add(_sizes, size);
  }
  Future<void> updateSize(String id, ProductSize size) => _update(_sizes, id, size.toMap());
  Future<void> deleteSize(String id) => _delete(_sizes, id);
  Stream<List<ProductSize>> getSizes() {
    // Sizes usually need custom sorting by sortOrder
    return _sizes.orderBy('sortOrder').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProductSize.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  // --- Color ---
  Future<void> addColor(ProductColor color) async {
    int index = await _getNextIndex(_colors);
    color.index = index;
    color.createdAt ??= DateTime.now();
    await _add(_colors, color);
  }
  Future<void> updateColor(String id, ProductColor color) => _update(_colors, id, color.toMap());
  Future<void> deleteColor(String id) => _delete(_colors, id);
  Stream<List<ProductColor>> getColors() => _stream(_colors, ProductColor.fromMap);

  // --- Design ---
  Future<void> addDesign(ProductDesign design) async {
    int index = await _getNextIndex(_designs);
    design.index = index;
    design.createdAt ??= DateTime.now();
    await _add(_designs, design);
  }
  Future<void> updateDesign(String id, ProductDesign design) => _update(_designs, id, design.toMap());
  Future<void> deleteDesign(String id) => _delete(_designs, id);
  Stream<List<ProductDesign>> getDesigns() => _stream(_designs, ProductDesign.fromMap);
}

final attributeServiceProvider = Provider<AttributeService>((ref) => AttributeService());
