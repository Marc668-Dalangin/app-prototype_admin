import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_models.dart';

class AdminDataService {
  AdminDataService._();
  static final instance = AdminDataService._();
  final _firestore = FirebaseFirestore.instance;
  List<DetectionRecord> _latestDetections = const [];
  Map<String, ManagedUser> _usersById = const {};
  Future<Map<String, ManagedUser>>? _usersByIdFuture;
  int _userCacheGeneration = 0;
  final Set<String> _locallyDeletedUserIds = <String>{};
  late final Stream<List<DetectionRecord>> _detections =
      _watchDetectionsForSession().asBroadcastStream();

  Stream<List<ManagedUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ManagedUser.fromDoc).toList())
      .map((users) {
        _userCacheGeneration++;
        _usersById = Map.unmodifiable({
          for (final user in users) user.uid: user,
        });
        _usersByIdFuture = Future.value(_usersById);
        return users;
      });

  Map<String, ManagedUser> get usersById => _usersById;

  Future<Map<String, ManagedUser>> loadUsersById() {
    final cached = _usersByIdFuture;
    if (cached != null) return cached;

    final generation = _userCacheGeneration;
    final request = _firestore.collection('users').get().then((snapshot) {
      final users = {
        for (final document in snapshot.docs)
          document.id: ManagedUser.fromDoc(document),
      };
      if (generation == _userCacheGeneration) {
        _usersById = Map.unmodifiable(users);
      }
      return users;
    });
    _usersByIdFuture = request;
    return request;
  }

  Stream<List<DetectionRecord>> watchDetections() => _detections;

  List<DetectionRecord> get latestDetections => _latestDetections;

  void clearSessionCache() {
    _userCacheGeneration++;
    _latestDetections = const [];
    _usersById = const {};
    _usersByIdFuture = null;
    _locallyDeletedUserIds.clear();
  }

  void removeUserDetectionsLocally(String uid) {
    _locallyDeletedUserIds.add(uid);
    _latestDetections = List.unmodifiable(
      _latestDetections.where((record) => record.uid != uid),
    );
  }

  Stream<List<DetectionRecord>>
  _watchDetectionsForSession() => FirebaseAuth.instance.authStateChanges().asyncExpand((
    user,
  ) {
    if (user == null) return Stream.value(const <DetectionRecord>[]);

    return Stream.multi((controller) {
      final records = <String, DetectionRecord>{};
      var analysisDone = false;
      var historyDone = false;
      var detectionsDone = false;

      void emit() {
        final values =
            records.values
                .where((record) => !_locallyDeletedUserIds.contains(record.uid))
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );
        _latestDetections = List.unmodifiable(values);
        controller.add(values);
      }

      void completeIfDone() {
        if (analysisDone && historyDone && detectionsDone) controller.close();
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
                try {
                  records['analysis_results/${doc.reference.path}'] =
                      DetectionRecord.fromAnalysisDoc(doc);
                } catch (error) {
                  debugPrint(
                    'Skipped malformed analysis record ${doc.reference.path}: $error',
                  );
                }
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
                  try {
                    records['detection_history/${doc.reference.path}'] =
                        DetectionRecord.fromHistoryDoc(doc);
                  } catch (error) {
                    debugPrint(
                      'Skipped malformed detection record ${doc.reference.path}: $error',
                    );
                  }
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

      final detectionsSubscription = _firestore
          .collectionGroup('detections')
          .snapshots()
          .listen(
            (snapshot) {
              records.removeWhere(
                (key, value) => key.startsWith('detections/'),
              );
              for (final doc in snapshot.docs) {
                try {
                  records['detections/${doc.reference.path}'] =
                      DetectionRecord.fromDetectionDoc(doc);
                } catch (error) {
                  debugPrint(
                    'Skipped malformed detection ${doc.reference.path}: $error',
                  );
                }
              }
              emit();
            },
            onError: controller.addError,
            onDone: () {
              detectionsDone = true;
              completeIfDone();
            },
          );

      controller.onCancel = () async {
        await analysisSubscription.cancel();
        await historySubscription.cancel();
        await detectionsSubscription.cancel();
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
    final failures = <String>[];

    for (final collectionName in ['detection_history', 'analysis_results']) {
      await _tryFirestoreCleanup(
        'top-level $collectionName by uid',
        () => _deleteTopLevelRecords(collectionName, 'uid', uid),
        failures,
      );
      await _tryFirestoreCleanup(
        'top-level $collectionName by userId',
        () => _deleteTopLevelRecords(collectionName, 'userId', uid),
        failures,
      );
    }

    for (final collectionName in ['detection_history', 'analysis_results']) {
      await _tryFirestoreCleanup(
        'users/$uid/$collectionName',
        () => _deleteUserSubcollection(uid, collectionName),
        failures,
      );
    }

    if (failures.isNotEmpty) {
      throw StateError(
        'Could not completely delete detection records. '
        'The user profile was kept so deletion can be retried:\n'
        '${failures.join('\n')}',
      );
    }

    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (error) {
      throw StateError('User profile: $error');
    }
  }

  Future<void> _tryFirestoreCleanup(
    String step,
    Future<void> Function() cleanup,
    List<String> failures,
  ) async {
    try {
      await cleanup();
    } catch (error) {
      debugPrint('Failed to delete $step: $error');
      failures.add('$step: $error');
    }
  }

  Future<void> _deleteTopLevelRecords(
    String collectionName,
    String userField,
    String uid,
  ) async {
    final collection = _firestore
        .collection(collectionName)
        .where(userField, isEqualTo: uid);

    while (true) {
      final snapshot = await collection.limit(450).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await _commitDeleteBatch(
        batch,
        'top-level $collectionName by $userField',
      );
    }
  }

  Future<void> _deleteUserSubcollection(
    String uid,
    String collectionName,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection(collectionName);

    while (true) {
      final snapshot = await collection.limit(450).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await _commitDeleteBatch(batch, 'users/$uid/$collectionName');
    }
  }

  Future<void> _commitDeleteBatch(WriteBatch batch, String step) async {
    try {
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to commit deletion batch for $step: $error');
      rethrow;
    }
  }
}
