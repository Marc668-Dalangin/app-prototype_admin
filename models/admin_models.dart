import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) return value.toDate();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.username,
    required this.email,
  });

  final String uid;
  final String username;
  final String email;

  factory AdminProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminProfile(
      uid: doc.id,
      username: data['username'] as String? ?? 'admin',
      email: data['email'] as String? ?? '',
    );
  }
}

class ManagedUser {
  const ManagedUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.lastSeen,
    required this.status,
  });

  final String uid;
  final String username;
  final String email;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final String status;

  factory ManagedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ManagedUser(
      uid: doc.id,
      username: data['username'] as String? ?? 'Unnamed user',
      email: data['email'] as String? ?? '',
      createdAt: readDate(data, 'createdAt') ?? readDate(data, 'createdAtMs'),
      lastSeen: readDate(data, 'lastSeen') ?? readDate(data, 'lastLoginAt'),
      status: data['status'] as String? ?? 'active',
    );
  }
}

class DetectionRecord {
  const DetectionRecord({
    required this.id,
    required this.uid,
    required this.diseaseName,
    required this.confidence,
    required this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String diseaseName;
  final double confidence;
  final String imageUrl;
  final DateTime? createdAt;

  factory DetectionRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return DetectionRecord(
      id: doc.id,
      uid: data['uid'] as String? ?? doc.reference.parent.parent?.id ?? '',
      diseaseName: data['diseaseName'] as String? ?? 'Unknown',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
      createdAt:
          readDate(data, 'createdAtServer') ?? readDate(data, 'createdAtMs'),
    );
  }
}
