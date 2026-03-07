import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String productCode;
  final String name;
  final String? description;
  final String categoryId;
  final String categoryName;
  final List<String> images;
  final double price; // Kept for legacy/sorting, can represent avg or min
  final double minPrice;
  final double maxPrice;
  final int stockQuantity;
  final double totalCost;   // Added: Aggregate Purchase Price
  final double totalSales;  // Added: Aggregate Retail Price
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<String> designIds;
  final List<String> marketingNotes; // Added
  final String? aiImagePrompt; // Added

  Product({
    this.id,
    required this.productCode,
    required this.name,
    this.description,
    required this.categoryId,
    required this.categoryName,
    this.images = const [],
    this.price = 0.0,
    this.minPrice = 0.0,
    this.maxPrice = 0.0,
    this.stockQuantity = 0,
    this.totalCost = 0.0,
    this.totalSales = 0.0,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.designIds = const [],
    this.marketingNotes = const [],
    this.aiImagePrompt,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      productCode: map['productCode'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      minPrice: (map['minPrice'] as num?)?.toDouble() ?? 0.0,
      maxPrice: (map['maxPrice'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: map['stockQuantity'] ?? 0,
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      isActive: map['isActive'] ?? true,
      designIds: List<String>.from(map['designIds'] ?? []),
      marketingNotes: List<String>.from(map['marketingNotes'] ?? []),
      aiImagePrompt: map['aiImagePrompt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productCode': productCode,
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'images': images,
      'price': price,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'stockQuantity': stockQuantity,
      'totalCost': totalCost,
      'totalSales': totalSales,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'designIds': designIds,
      'marketingNotes': marketingNotes,
      'aiImagePrompt': aiImagePrompt,
    };
  }

  Product copyWith({
    String? id,
    String? productCode,
    String? name,
    String? description,
    String? categoryId,
    String? categoryName,
    List<String>? images,
    double? price,
    double? minPrice,
    double? maxPrice,
    int? stockQuantity,
    double? totalCost,
    double? totalSales,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? designIds,
    List<String>? marketingNotes,
    String? aiImagePrompt,
  }) {
    return Product(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      images: images ?? this.images,
      price: price ?? this.price,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      totalCost: totalCost ?? this.totalCost,
      totalSales: totalSales ?? this.totalSales,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      designIds: designIds ?? this.designIds,
      marketingNotes: marketingNotes ?? this.marketingNotes,
      aiImagePrompt: aiImagePrompt ?? this.aiImagePrompt,
    );
  }
}
