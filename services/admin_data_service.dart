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

  Future<void> deleteUser(String uid) async {
    await _functions.httpsCallable('deleteManagedUser').call(<String, dynamic>{
      'uid': uid,
    });
  }
}
