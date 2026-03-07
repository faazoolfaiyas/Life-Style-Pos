import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes (mapped to UserModel?)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign In
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure user document exists or update it? 
      // Ideally we check if doc exists, if not create default.
      await _syncUserToFirestore(cred.user!);
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign Up
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _syncUserToFirestore(cred.user!);
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sync User to Firestore
  Future<void> _syncUserToFirestore(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // New User Default Logic
      String role = 'Admin'; // Default for everyone per requirements
      
      // Override for Super Admin
      if (user.email == 'faazoolfaiyas@gmail.com') {
        role = 'Administrator';
      }

      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        role: role,
        createdAt: DateTime.now(),
      );
      await userDoc.set(newUser.toMap());
    } else {
      // Logic to Force Administrator if matches email (Self-correction)
      if (user.email == 'faazoolfaiyas@gmail.com') {
        final data = snapshot.data();
        if (data != null && data['role'] != 'Administrator') {
           await userDoc.update({'role': 'Administrator'});
        }
      }
    }
  }

  // Get Current User Details
  Future<UserModel?> getCurrentUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  // Get All Users (For Admin Panel)
  Stream<List<UserModel>> getAllUsersStream() {
    return _firestore.collection('users').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  // Update User Role
  Future<void> updateUserRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({'role': newRole});
  }

  // Re-authenticate (Security Check)
  Future<bool> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    try {
      // Use signInWithEmailAndPassword instead of re-auth to verify credentials
      // This is often more reliable if re-auth hangs
      await _auth.signInWithEmailAndPassword(email: user.email!, password: password);
      return true;
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'wrong-password') {
         // Pass explicit error? The UI handles boolean, but we could return false.
         return false; 
      }
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
