class BillItem {
  final String productId;
  final String? stockId; // Added for precise stock tracking
  final String productName;
  final String categoryName; 
  final double price;
  final int quantity;
  final double discount;
  final String? selectedColor;
  final String? selectedSize;
  final double? costPrice; // Added for Non-Inventory Quick Sale

  const BillItem({
    required this.productId,
    this.stockId,
    required this.productName,
    this.categoryName = 'Uncategorized',
    required this.price,
    required this.quantity,
    this.discount = 0.0,
    this.selectedColor,
    this.selectedSize,
    this.costPrice,
  });

  double get total => (price * quantity) - discount;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'stockId': stockId,
      'productName': productName,
      'categoryName': categoryName,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'selectedColor': selectedColor,
      'selectedSize': selectedSize,
      'costPrice': costPrice,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      productId: map['productId'] as String,
      stockId: map['stockId'] as String?,
      productName: map['productName'] as String,
      categoryName: map['categoryName'] as String? ?? 'Uncategorized',
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      selectedColor: map['selectedColor'] as String?,
      selectedSize: map['selectedSize'] as String?,
      costPrice: (map['costPrice'] as num?)?.toDouble(),
    );
  }

  BillItem copyWith({
    int? quantity,
    double? discount,
    String? categoryName,
    String? stockId,
    double? costPrice,
  }) {
    return BillItem(
      productId: productId,
      stockId: stockId ?? this.stockId,
      productName: productName,
      categoryName: categoryName ?? this.categoryName,
      price: price,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      selectedColor: selectedColor,
      selectedSize: selectedSize,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}


class Bill {
  final String id;
  final String billNumber;
  final List<BillItem> items;
  final double totalAmount;
  final double subTotal;
  final double discount;
  
  bool get isReturn => items.any((item) => item.quantity < 0);

  final double tax;
  final String paymentMethod;
  final String status; // 'Completed', 'Pending', 'Cancelled'
  final DateTime createdAt;
  final String? customerName;
  final String? customerPhone;
  final String? affiliateName;
  final int? customerId;
  final int? affiliateId;
  final double? receivedAmount;
  final double? splitCashAmount; // NEW: For split payments
  final double? splitCardAmount; // NEW: For split payments
  final String? referenceBillId; // For returns: ID of the bill being returned/referenced
  final String? originalBillId; // For edits: ID of the bill being edited/replaced
  final DateTime? billDate; // Custom User-set date
  final DateTime? lastEditedAt;
  final bool? showProductDiscount;

  const Bill({
    required this.id,
    required this.billNumber,
    required this.items,
    required this.totalAmount,
    required this.subTotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.affiliateName,
    this.customerId,
    this.affiliateId,
    this.receivedAmount,
    this.splitCashAmount,
    this.splitCardAmount,
    this.referenceBillId,
    this.originalBillId,
    this.billDate,
    this.lastEditedAt,
    this.showProductDiscount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billNumber': billNumber,
      'items': items.map((x) => x.toMap()).toList(),
      'totalAmount': totalAmount,
      'subTotal': subTotal,
      'discount': discount,
      'tax': tax,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'customerId': customerId,
      'affiliateId': affiliateId,
      'receivedAmount': receivedAmount,
      'splitCashAmount': splitCashAmount,
      'splitCardAmount': splitCardAmount,
      'referenceBillId': referenceBillId,
      'originalBillId': originalBillId,
      'billDate': billDate?.toIso8601String(),
      'lastEditedAt': lastEditedAt?.toIso8601String(),
      'showProductDiscount': showProductDiscount,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as String,
      billNumber: map['billNumber'] as String,
      items: List<BillItem>.from(
        (map['items'] as List<dynamic>).map<BillItem>((x) => BillItem.fromMap(x as Map<String, dynamic>)),
      ),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      subTotal: (map['subTotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      affiliateName: map['affiliateName'] as String?,
      customerId: map['customerId'] as int?,
      affiliateId: map['affiliateId'] as int?,
      receivedAmount: (map['receivedAmount'] as num?)?.toDouble(),
      splitCashAmount: (map['splitCashAmount'] as num?)?.toDouble(),
      splitCardAmount: (map['splitCardAmount'] as num?)?.toDouble(),
      referenceBillId: map['referenceBillId'] as String?,
      originalBillId: map['originalBillId'] as String?,
      billDate: map['billDate'] != null ? DateTime.parse(map['billDate'] as String) : null,
      lastEditedAt: map['lastEditedAt'] != null ? DateTime.parse(map['lastEditedAt'] as String) : null,
      showProductDiscount: map['showProductDiscount'] as bool?,
    );
  }
}
