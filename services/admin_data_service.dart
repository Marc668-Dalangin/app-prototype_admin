import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_models.dart';

class AdminDataService {
  AdminDataService._();
  static final instance = AdminDataService._();
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  List<DetectionRecord> _latestDetections = const [];
  late final Stream<List<DetectionRecord>> _detections =
      _watchDetectionsForSession().asBroadcastStream();

  Stream<List<ManagedUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ManagedUser.fromDoc).toList());

  Stream<List<DetectionRecord>> watchDetections() => _detections;

  List<DetectionRecord> get latestDetections => _latestDetections;

  Stream<List<DetectionRecord>> _watchDetectionsForSession() =>
      FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
        if (user == null) return Stream.value(const <DetectionRecord>[]);

        return Stream.multi((controller) {
          final records = <String, DetectionRecord>{};
          var analysisDone = false;
          var historyDone = false;

          void emit() {
            final values = records.values.toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );
            _latestDetections = List.unmodifiable(values);
            controller.add(values);
          }

          void completeIfDone() {
            if (analysisDone && historyDone) controller.close();
          }

          final analysisSubscription = _firestore
              .collectionGroup('analysis_results')
              .snapshots()
              .listen(
                (snapshot) {
                  records.removeWhere(
                    (key, value) => key.startsWith('analysis_results/'),
                  );
                  for (final doc in snapshot.docs) {
                    records['analysis_results/${doc.reference.path}'] =
                        DetectionRecord.fromAnalysisDoc(doc);
                  }
                  emit();
                },
                onError: controller.addError,
                onDone: () {
                  analysisDone = true;
                  completeIfDone();
                },
              );

          final historySubscription = _firestore
              .collectionGroup('detection_history')
              .snapshots()
              .listen(
                (snapshot) {
                  records.removeWhere(
                    (key, value) => key.startsWith('detection_history/'),
                  );
                  for (final doc in snapshot.docs) {
                    final data = doc.data();
                    if (data['deletedAt'] == null) {
                      records['detection_history/${doc.reference.path}'] =
                          DetectionRecord.fromHistoryDoc(doc);
                    }
                  }
                  emit();
                },
                onError: controller.addError,
                onDone: () {
                  historyDone = true;
                  completeIfDone();
                },
              );

          controller.onCancel = () async {
            await analysisSubscription.cancel();
            await historySubscription.cancel();
          };
        });
      });

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
