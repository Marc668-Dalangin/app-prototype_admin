import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_models.dart';

class AdminDataService {
  AdminDataService._();
  static final instance = AdminDataService._();
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  Stream<List<ManagedUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ManagedUser.fromDoc).toList());

  Stream<List<DetectionRecord>> watchDetections() => _firestore
      .collectionGroup('analysis_results')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(DetectionRecord.fromDoc).toList());

  String describeError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firebase denied this read. Sign in with an admin account and verify the deployed Firestore rules.';
        case 'unauthenticated':
          return 'Your admin session has expired. Please sign in again.';
        case 'failed-precondition':
          return 'Firestore is not ready for this query. Check the collection and index configuration.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Firebase is temporarily unavailable. Check the network connection.';
        case 'not-found':
          return 'The requested Firebase resource was not found.';
        default:
          return error.message ??
              'Firebase returned an unexpected error (${error.code}).';
      }
    }
    return 'Unable to read Firebase data: $error';
  }

  Future<void> deleteUser(String uid) async {
    await _functions.httpsCallable('deleteManagedUser').call(<String, dynamic>{
      'uid': uid,
    });
  }
}
