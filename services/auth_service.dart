import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_models.dart';

class AdminAuthService {
  AdminAuthService._();
  static final instance = AdminAuthService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  String _emailForUsername(String username) =>
      '${username.trim().toLowerCase()}@corn-disease-app.local';

  Future<AdminProfile> signIn(String username, String password) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      throw const FormatException('Enter both username and password.');
    }

    if (normalized == 'admin' && password == 'admin123') {
      try {
        return await _bootstrapDefaultAdmin();
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') {
          throw AuthException(_messageFor(error));
        }
      }
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailForUsername(normalized),
        password: password,
      );
      return _requireAdmin(credential.user!);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  Future<AdminProfile> _bootstrapDefaultAdmin() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _emailForUsername('admin'),
      password: 'admin123',
    );
    final user = credential.user!;
    await _firestore.collection('admin_users').doc(user.uid).set({
      'username': 'admin',
      'email': user.email,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return AdminProfile(
      uid: user.uid,
      username: 'admin',
      email: user.email ?? '',
    );
  }

  Future<AdminProfile> _requireAdmin(User user) async {
    final doc = await _firestore.collection('admin_users').doc(user.uid).get();
    if (!doc.exists || doc.data()?['role'] != 'admin') {
      await _auth.signOut();
      throw const AuthException(
        'This account is not authorized for the admin panel.',
      );
    }
    return AdminProfile.fromDoc(doc);
  }

  Future<void> updateCredentials({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(normalized)) {
      throw const FormatException(
        'Username must be 3-32 letters, numbers, dots, underscores, or hyphens.',
      );
    }
    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters.');
    }
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('Your session has expired.');
    final profile = await _requireAdmin(user);
    final newEmail = _emailForUsername(normalized);
    if (user.email != newEmail) await user.verifyBeforeUpdateEmail(newEmail);
    await user.updatePassword(password);
    await _firestore.collection('admin_users').doc(profile.uid).update({
      'username': normalized,
      'email': newEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => _auth.signOut();

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid username or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return error.message ?? 'Unable to sign in.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
