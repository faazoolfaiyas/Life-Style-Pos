import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ProductAttribute {
  String? id;
  String name;
  bool isActive;
  int index;
  final String type;
  DateTime? createdAt;

  ProductAttribute({
    this.id,
    required this.name,
    this.isActive = true,
    this.index = 0,
    required this.type,
    this.createdAt,
  });

  Map<String, dynamic> toMap();
}

class ProductCategory extends ProductAttribute {
  final String? description;
  final String? colorHex; // Hex color string e.g. #FF0000

  ProductCategory({
    super.id,
    required super.name,
    super.isActive,
    this.description,
    this.colorHex,
    super.index,
    super.createdAt,
  }) : super(type: 'Category');

  factory ProductCategory.fromMap(Map<String, dynamic> map, String id) {
    return ProductCategory(
      id: id,
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      description: map['description'],
      colorHex: map['colorHex'],
      index: map['index'] ?? 0,
       createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'description': description,
      'colorHex': colorHex,
      'index': index,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ProductSize extends ProductAttribute {
  final String code; // e.g., "S", "M", "XL"
  final int sortOrder; // For sorting e.g., 1, 2, 3

  ProductSize({
    super.id,
    required super.name, // e.g., "Small"
    super.isActive,
    required this.code,
    this.sortOrder = 0,
    super.index,
    super.createdAt,
  }) : super(type: 'Size');

  factory ProductSize.fromMap(Map<String, dynamic> map, String id) {
    return ProductSize(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
      index: map['index'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'index': index,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ProductColor extends ProductAttribute {
  final String hexCode; // e.g., "#FF0000"

  ProductColor({
    super.id,
    required super.name,
    super.isActive,
    required this.hexCode,
    super.index,
    super.createdAt,
  }) : super(type: 'Color');

  factory ProductColor.fromMap(Map<String, dynamic> map, String id) {
    return ProductColor(
      id: id,
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      hexCode: map['hexCode'] ?? '#000000',
      index: map['index'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'hexCode': hexCode,
      'index': index,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ProductDesign extends ProductAttribute {
  final String? imageUrl;

  ProductDesign({
    super.id,
    required super.name,
    super.isActive,
    this.imageUrl,
    super.index,
    super.createdAt,
  }) : super(type: 'Design');

  factory ProductDesign.fromMap(Map<String, dynamic> map, String id) {
    return ProductDesign(
      id: id,
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      imageUrl: map['imageUrl'],
      index: map['index'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'imageUrl': imageUrl,
      'index': index,
      'type': type,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
