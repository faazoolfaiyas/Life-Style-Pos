import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ConnectionModel {
  final String? id;
  final int connectionId;
  final String name;
  final String whatsappNumber;
  final String? email;
  final String address;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String type;

  ConnectionModel({
    this.id,
    required this.connectionId,
    required this.name,
    required this.whatsappNumber,
    this.email,
    required this.address,
    this.description,
    this.status = 'Active',
    required this.createdAt,
    this.updatedAt,
    required this.type,
  });

  Map<String, dynamic> toMap();
}

class Customer extends ConnectionModel {
  Customer({
    super.id,
    required super.connectionId,
    required super.name,
    required super.whatsappNumber,
    super.email,
    super.address = '',
    super.description,
    super.status,
    required super.createdAt,
    super.updatedAt,
  }) : super(type: 'Customer');

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      connectionId: map['connectionId'] ?? 0,
      name: map['name'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      email: map['email'],
      address: map['address'] ?? '',
      description: map['description'],
      status: map['status'] ?? 'Active',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'name': name,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'address': address,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type,
    };
  }
}

class Supplier extends ConnectionModel {
  final String shopName;
  final String? ownerName;
  final List<Map<String, String>> socialMedia; // [{'platform': 'FB', 'link': '...'}]
  final List<Map<String, String>> bankDetails; // [{'accountNumber': '...', 'bankName': '...'}]

  Supplier({
    super.id,
    required super.connectionId,
    required this.shopName,
    this.ownerName,
    required super.whatsappNumber,
    required super.address,
    super.email,
    this.socialMedia = const [],
    this.bankDetails = const [],
    super.description,
    super.status,
    required super.createdAt,
    super.updatedAt,
  }) : super(name: shopName, type: 'Supplier'); // Use shopName as main name

  factory Supplier.fromMap(Map<String, dynamic> map, String id) {
     return Supplier(
      id: id,
      connectionId: map['connectionId'] ?? 0,
      shopName: map['shopName'] ?? '',
      ownerName: map['ownerName'],
      whatsappNumber: map['whatsappNumber'] ?? '',
      address: map['address'] ?? '',
      email: map['email'],
      socialMedia: (map['socialMedia'] as List?)?.map((item) => Map<String, String>.from(
        (item as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
      )).toList() ?? [],
      bankDetails: (map['bankDetails'] as List?)?.map((item) => Map<String, String>.from(
        (item as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
      )).toList() ?? [],
      description: map['description'],
      status: map['status'] ?? 'Active',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'shopName': shopName,
      'ownerName': ownerName,
      'whatsappNumber': whatsappNumber,
      'address': address,
      'email': email,
      'socialMedia': socialMedia,
      'bankDetails': bankDetails,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type,
    };
  }
}

class Reseller extends ConnectionModel {
  final List<Map<String, String>> socialMedia;

  Reseller({
    super.id,
    required super.connectionId,
    required super.name,
    required super.whatsappNumber,
    super.email,
    required super.address,
    this.socialMedia = const [],
    super.description,
    super.status,
    required super.createdAt,
    super.updatedAt,
  }) : super(type: 'Reseller');

  factory Reseller.fromMap(Map<String, dynamic> map, String id) {
    return Reseller(
      id: id,
      connectionId: map['connectionId'] ?? 0,
      name: map['name'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      email: map['email'],
      address: map['address'] ?? '',
      socialMedia: (map['socialMedia'] as List?)?.map((item) => Map<String, String>.from(
        (item as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
      )).toList() ?? [],
      description: map['description'],
      status: map['status'] ?? 'Active',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'name': name,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'address': address,
      'socialMedia': socialMedia,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type,
    };
  }
}

class Affiliate extends ConnectionModel {
  final String threewheelerNumber;
  final List<Map<String, String>> bankDetails;

  Affiliate({
    super.id,
    required super.connectionId,
    required super.name,
    required super.whatsappNumber,
    super.email,
    required super.address,
    required this.threewheelerNumber,
    this.bankDetails = const [],
    super.description,
    super.status,
    required super.createdAt,
    super.updatedAt,
  }) : super(type: 'Affiliate');

   factory Affiliate.fromMap(Map<String, dynamic> map, String id) {
    return Affiliate(
      id: id,
      connectionId: map['connectionId'] ?? 0,
      name: map['name'] ?? '',
      whatsappNumber: map['whatsappNumber'] ?? '',
      email: map['email'],
      address: map['address'] ?? '',
      threewheelerNumber: map['threewheelerNumber'] ?? '',
      bankDetails: (map['bankDetails'] as List?)?.map((item) => Map<String, String>.from(
        (item as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
      )).toList() ?? [],
      description: map['description'],
      status: map['status'] ?? 'Active',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
       'connectionId': connectionId,
      'name': name,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'address': address,
      'threewheelerNumber': threewheelerNumber,
      'bankDetails': bankDetails,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type,
    };
  }
}
