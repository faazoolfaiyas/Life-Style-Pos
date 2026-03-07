import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role; // 'Administrator', 'Admin', 'Cashier'
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  bool get isAdministrator => role == 'Administrator';
  bool get isAdmin => role == 'Admin' || role == 'Administrator';
  bool get isCashier => role == 'Cashier';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Cashier', // Default fallback
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
  
  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
