import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? readDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) {
    try {
      return value.toDate();
    } on Object {
      return null;
    }
  }
  if (value is num && value.isFinite) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } on RangeError {
      return null;
    }
  }
  if (value is String) {
    final parsedDate = DateTime.tryParse(value);
    if (parsedDate != null) return parsedDate;
    final milliseconds = num.tryParse(value);
    if (milliseconds != null && milliseconds.isFinite) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
      } on RangeError {
        return null;
      }
    }
  }
  return null;
}

String readString(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key];
  return value is String && value.trim().isNotEmpty ? value : fallback;
}

double readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return 0;
}

Object? normalizeFirestoreValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        '${entry.key}': normalizeFirestoreValue(entry.value),
    });
  }
  if (value is Iterable) {
    final normalized = value.map(normalizeFirestoreValue).toList();
    if (normalized.every((item) => item is String)) {
      return List<String>.unmodifiable(normalized.whereType<String>());
    }
    return List<Object?>.unmodifiable(normalized);
  }
  return value;
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
      username: readString(data, 'username', 'admin'),
      email: readString(data, 'email'),
    );
  }
}

class ManagedUser {
  const ManagedUser({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.lastSeen,
    required this.status,
  });

  final String uid;
  final String displayName;
  final String username;
  final String email;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final String status;

  factory ManagedUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ManagedUser(
      uid: doc.id,
      displayName: readString(data, 'displayName'),
      username: readString(
        data,
        'username',
        readString(data, 'displayName', 'Unnamed user'),
      ),
      email: readString(data, 'email'),
      createdAt: readDate(data, 'createdAt') ?? readDate(data, 'createdAtMs'),
      lastSeen: readDate(data, 'lastSeen') ?? readDate(data, 'lastLoginAt'),
      status: readString(data, 'status', 'active'),
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
    required this.storagePath,
    required this.localImagePath,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.analysisDetails,
  });

  final String id;
  final String uid;
  final String diseaseName;
  final double confidence;
  final String imageUrl;
  final String storagePath;
  final String localImagePath;
  final String username;
  final String email;
  final DateTime? createdAt;
  final Map<String, dynamic> analysisDetails;

  factory DetectionRecord.fromAnalysisDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return DetectionRecord(
      id: doc.id,
      uid: readString(
        data,
        'uid',
        readString(
          data,
          'userId',
          readString(
            data,
            'userAccount',
            readString(data, 'user_id', doc.reference.parent.parent?.id ?? ''),
          ),
        ),
      ),
      diseaseName: readString(data, 'diseaseName', 'Unknown'),
      confidence: readDouble(data, 'confidence'),
      imageUrl: readString(data, 'imageUrl'),
      storagePath: readString(data, 'storagePath'),
      localImagePath: '',
      username: readString(data, 'username'),
      email: readString(data, 'email'),
      createdAt:
          readDate(data, 'createdAtServer') ?? readDate(data, 'createdAtMs'),
      analysisDetails: _analysisDetails(data),
    );
  }

  factory DetectionRecord.fromHistoryDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return DetectionRecord(
      id: doc.id,
      uid: readString(
        data,
        'uid',
        readString(
          data,
          'userId',
          readString(
            data,
            'userAccount',
            readString(data, 'user_id', doc.reference.parent.parent?.id ?? ''),
          ),
        ),
      ),
      diseaseName: readString(data, 'diseaseName', 'Unknown'),
      confidence: readDouble(data, 'confidence'),
      imageUrl: readString(data, 'imageUrl'),
      storagePath: readString(data, 'storagePath'),
      localImagePath: readString(data, 'localImagePath'),
      username: readString(data, 'username'),
      email: readString(data, 'email'),
      createdAt:
          readDate(data, 'detectedAt') ??
          readDate(data, 'localDetectedAt') ??
          readDate(data, 'createdAtMs'),
      analysisDetails: _analysisDetails(data),
    );
  }

  factory DetectionRecord.fromDetectionDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final parentUserId = doc.reference.parent.parent?.id ?? '';
    return DetectionRecord(
      id: doc.id,
      uid: readString(
        data,
        'uid',
        readString(
          data,
          'userId',
          readString(
            data,
            'userAccount',
            readString(data, 'user_id', parentUserId),
          ),
        ),
      ),
      diseaseName: readString(
        data,
        'diseaseName',
        readString(
          data,
          'diagnosis',
          readString(data, 'predictedClass', 'Unknown'),
        ),
      ),
      confidence: readDouble(data, 'confidenceScore') != 0
          ? readDouble(data, 'confidenceScore')
          : readDouble(data, 'confidence'),
      imageUrl: readString(data, 'imageUrl', readString(data, 'downloadUrl')),
      storagePath: readString(
        data,
        'storagePath',
        readString(data, 'imagePath'),
      ),
      localImagePath: readString(data, 'localImagePath'),
      username: readString(data, 'username'),
      email: readString(data, 'email'),
      createdAt:
          readDate(data, 'createdAt') ??
          readDate(data, 'detectedAt') ??
          readDate(data, 'timestamp') ??
          readDate(data, 'createdAtServer') ??
          readDate(data, 'createdAtMs'),
      analysisDetails: _analysisDetails(data),
    );
  }

  static Map<String, dynamic> _analysisDetails(Map<String, dynamic> data) {
    const excludedFields = {
      'uid',
      'userid',
      'useraccount',
      'user_id',
      'user_account',
      'id',
      'username',
      'email',
      'diseasename',
      'diagnosis',
      'predictedclass',
      'confidence',
      'confidencescore',
      'imageurl',
      'imagepath',
      'downloadurl',
      'storagepath',
      'localimagepath',
      'createdat',
      'timestamp',
      'createdatserver',
      'createdatms',
      'detectedat',
      'localdetectedat',
      'deletedat',
    };
    return Map.unmodifiable({
      for (final entry in data.entries)
        if (!excludedFields.contains(entry.key.toLowerCase()) &&
            entry.value != null)
          entry.key: normalizeFirestoreValue(entry.value),
    });
  }
}
