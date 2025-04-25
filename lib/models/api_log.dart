class ApiLog {
  final String id;
  final DateTime timestamp;
  final String ipAddress;
  final String requestMethod;
  final String endpoint;
  final int statusCode;
  final String payload;
  final String? deviceId;
  final String? errorMessage;

  const ApiLog({
    required this.id,
    required this.timestamp,
    required this.ipAddress,
    required this.requestMethod,
    required this.endpoint,
    required this.statusCode,
    required this.payload,
    this.deviceId,
    this.errorMessage,
  });

  // Create from Firestore document
  factory ApiLog.fromMap(Map<String, dynamic> map, String docId) {
    // Handle different timestamp formats from Firestore
    DateTime parseTimestamp(dynamic timestampValue) {
      if (timestampValue == null) {
        return DateTime.now();
      } else if (timestampValue is String) {
        return DateTime.parse(timestampValue);
      } else {
        // For Firestore Timestamp objects
        try {
          return timestampValue.toDate();
        } catch (e) {
          return DateTime.now();
        }
      }
    }

    return ApiLog(
      id: docId,
      timestamp: parseTimestamp(map['timestamp']),
      ipAddress: map['ipAddress'] ?? '',
      requestMethod: map['requestMethod'] ?? '',
      endpoint: map['endpoint'] ?? '',
      statusCode: map['statusCode'] ?? 0,
      payload: map['payload'] ?? '',
      deviceId: map['deviceId'],
      errorMessage: map['errorMessage'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'ipAddress': ipAddress,
      'requestMethod': requestMethod,
      'endpoint': endpoint,
      'statusCode': statusCode,
      'payload': payload,
      'deviceId': deviceId,
      'errorMessage': errorMessage,
    };
  }
} 