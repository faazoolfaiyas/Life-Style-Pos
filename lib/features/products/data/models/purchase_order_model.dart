import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderItem {
  final String variantId; // The constructed Smart ID (e.g., prodCode+Batch+Design+Size+Color)
  // Note: Since this is a *future* order, batch number might not be assigned yet in reality, 
  // but we can generate a temporary ID or just rely on size/color/design IDs for matching. 
  // actually for the "smart ID" logic to work we need the parts. 
  // Let's store the constituent parts to be safe and reconstruct ID or use a placeholder if needed.
  // Ideally, PO items correspond to what we *will* add to stock.
  
  final String? designId;
  final String sizeId;
  final String colorId;
  final double? purchasePrice; // Optional as requested
  final int quantity;

  PurchaseOrderItem({
    required this.variantId,
    this.designId,
    required this.sizeId,
    required this.colorId,
    this.purchasePrice,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'variantId': variantId,
      'designId': designId,
      'sizeId': sizeId,
      'colorId': colorId,
      'purchasePrice': purchasePrice,
      'quantity': quantity,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      variantId: map['variantId'] ?? '',
      designId: map['designId'],
      sizeId: map['sizeId'] ?? '',
      colorId: map['colorId'] ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble(),
      quantity: map['quantity']?.toInt() ?? 0,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String productId;
  final String? supplierId;
  final String? note;
  final List<PurchaseOrderItem> items;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime expiresAt;

  PurchaseOrder({
    required this.id,
    required this.productId,
    this.supplierId,
    this.note,
    required this.items,
    required this.createdAt,
    this.updatedAt,
    required this.expiresAt,
  });

  PurchaseOrder copyWith({
    String? id,
    String? productId,
    String? supplierId,
    String? note,
    List<PurchaseOrderItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      note: note ?? this.note,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'supplierId': supplierId,
      'note': note,
      'items': items.map((x) => x.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      supplierId: map['supplierId'],
      note: map['note'],
      items: List<PurchaseOrderItem>.from(
        (map['items'] as List<dynamic>? ?? []).map<PurchaseOrderItem>(
          (x) => PurchaseOrderItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
    );
  }
}
