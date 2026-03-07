import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/connection_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionServiceProvider = Provider((ref) => ConnectionService());

final streamConnectionProvider = StreamProvider.family<List<ConnectionModel>, String>((ref, type) {
  return ref.watch(connectionServiceProvider).getConnectionsStream(type);
});

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getCollection(String type) {
    // Structure: connections (col) -> type (doc) -> sc_data (col) -> docId
    return _firestore.collection('connections').doc(type.toLowerCase()).collection('sc_data');
  }

  // Generate Next ID (Gap Filling Logic)
  Future<int> _generateNextId(String type) async {
    final snapshot = await _getCollection(type).get();
    final ids = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['connectionId'] as int?)
        .where((id) => id != null)
        .cast<int>()
        .toList();
    
    ids.sort();

    int nextId = 1;
    for (final id in ids) {
      if (id == nextId) {
        nextId++;
      } else if (id > nextId) {
        return nextId; // Gap found
      }
    }
    return nextId;
  }

  // Add Connection
  Future<void> addConnection(String type, Map<String, dynamic> data) async {
    final nextId = await _generateNextId(type);
    
    // Create appropriate model instance
    ConnectionModel model;
    final now = DateTime.now();

    // Common fields
    final baseData = {
      'connectionId': nextId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'status': 'Active', // Default status
      ...data,
    };

    if (type == 'Customer') {
      model = Customer.fromMap(baseData, '');
    } else if (type == 'Supplier') {
      model = Supplier.fromMap(baseData, '');
    } else if (type == 'Reseller') {
      model = Reseller.fromMap(baseData, '');
    } else {
      model = Affiliate.fromMap(baseData, '');
    }

    await _getCollection(type).add(model.toMap());
  }

  // Update Connection
  Future<void> updateConnection(String type, String id, Map<String, dynamic> data) async {
    final updateData = {
      ...data,
      'updatedAt': Timestamp.now(),
    };
    await _getCollection(type).doc(id).update(updateData);
  }

  // Delete Connection
  Future<void> deleteConnection(String type, String id) async {
    await _getCollection(type).doc(id).delete();
  }

  // Get Stream
  Stream<List<ConnectionModel>> getConnectionsStream(String type) {
    return _getCollection(type)
        .orderBy('connectionId', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;
        
        switch (type) {
          case 'Customer':
            return Customer.fromMap(data, id);
          case 'Supplier':
            return Supplier.fromMap(data, id);
          case 'Reseller':
            return Reseller.fromMap(data, id);
          case 'Affiliate':
            return Affiliate.fromMap(data, id);
          default:
            throw Exception('Unknown type: $type');
        }
      }).toList();
    });
  }
}
