/// One row from `GET /api/users/:deviceId` on the zenda-api-v2 server.
///
/// The backend stores these in SQLite and refreshes them whenever a device
/// publishes a `status` MQTT message with its current user table.
class DeviceEnrolledUser {
  final int userId;
  final String userName;
  final String? userPhone;
  final String? cardId;

  const DeviceEnrolledUser({
    required this.userId,
    required this.userName,
    this.userPhone,
    this.cardId,
  });

  factory DeviceEnrolledUser.fromJson(Map<String, dynamic> data) {
    return DeviceEnrolledUser(
      userId: _parseInt(data['userId'] ?? data['id']) ?? 0,
      userName:
          (data['userName'] ?? data['name'] ?? '').toString().trim().isEmpty
              ? 'Unknown'
              : (data['userName'] ?? data['name']).toString(),
      userPhone: _emptyToNull(data['userPhone'] ?? data['phone']),
      cardId: _emptyToNull(data['cardId'] ?? data['cardID']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static String? _emptyToNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
