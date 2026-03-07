import 'package:cloud_firestore/cloud_firestore.dart';

class StockItem {
  final String id;
  final String productId;
  final int batchNumber;
  final String supplierId;
  final String? description;
  final String? designId; // Optional single design
  final String sizeId;
  final String colorId;
  final double purchasePrice;
  final double retailPrice;
  final double wholesalePrice;
  final int quantity;
  final DateTime dateAdded;
  final List<DateTime>? editedAt;

  StockItem({
    required this.id,
    required this.productId,
    required this.batchNumber,
    required this.supplierId,
    this.description,
    this.designId,
    required this.sizeId,
    required this.colorId,
    required this.purchasePrice,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.quantity,
    required this.dateAdded,
    this.editedAt,
  });

  StockItem copyWith({
    String? id,
    String? productId,
    int? batchNumber,
    String? supplierId,
    String? description,
    String? designId,
    String? sizeId,
    String? colorId,
    double? purchasePrice,
    double? retailPrice,
    double? wholesalePrice,
    int? quantity,
    DateTime? dateAdded,
    List<DateTime>? editedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      supplierId: supplierId ?? this.supplierId,
      description: description ?? this.description,
      designId: designId ?? this.designId,
      sizeId: sizeId ?? this.sizeId,
      colorId: colorId ?? this.colorId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
      dateAdded: dateAdded ?? this.dateAdded,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'batchNumber': batchNumber,
      'supplierId': supplierId,
      'description': description,
      'designId': designId,
      'sizeId': sizeId,
      'colorId': colorId,
      'purchasePrice': purchasePrice,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'quantity': quantity,
      'dateAdded': Timestamp.fromDate(dateAdded),
      if (editedAt != null) 'editedAt': editedAt!.map((e) => Timestamp.fromDate(e)).toList(),
    };
  }

  factory StockItem.fromMap(Map<String, dynamic> map) {
    return StockItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      batchNumber: map['batchNumber']?.toInt() ?? 0,
      supplierId: map['supplierId'] ?? '',
      description: map['description'],
      designId: map['designId'],
      sizeId: map['sizeId'] ?? '',
      colorId: map['colorId'] ?? '',
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      retailPrice: (map['retailPrice'] ?? 0.0).toDouble(),
      wholesalePrice: (map['wholesalePrice'] ?? 0.0).toDouble(),
      quantity: map['quantity']?.toInt() ?? 0,
      dateAdded: (map['dateAdded'] as Timestamp).toDate(),
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] as List).map((e) => (e as Timestamp).toDate()).toList()
          : null,
    );
  }
}
