import 'package:cloud_firestore/cloud_firestore.dart';

class SystemConfig {
  final String version;
  final bool maintenanceMode;
  final bool fingerprintEnabled;
  final bool messagingEnabled;
  final bool multiSchoolEnabled;
  final String? defaultCountry;
  final String? supportEmail;
  final DateTime? updatedAt;

  const SystemConfig({
    this.version = '1.0.0',
    this.maintenanceMode = false,
    this.fingerprintEnabled = true,
    this.messagingEnabled = true,
    this.multiSchoolEnabled = true,
    this.defaultCountry,
    this.supportEmail,
    this.updatedAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    if (v is DateTime) return v;
    return null;
  }

  factory SystemConfig.fromFirestore(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? const {};
    final settings = data['settings'] as Map<String, dynamic>? ?? const {};
    return SystemConfig(
      version: data['version'] ?? '1.0.0',
      maintenanceMode: data['maintenanceMode'] ?? false,
      fingerprintEnabled: features['fingerprintEnabled'] ?? true,
      messagingEnabled: features['messagingEnabled'] ?? true,
      multiSchoolEnabled: features['multiSchoolEnabled'] ?? true,
      defaultCountry: settings['defaultCountry'],
      supportEmail: settings['supportEmail'],
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'version': version,
      'maintenanceMode': maintenanceMode,
      'features': {
        'fingerprintEnabled': fingerprintEnabled,
        'messagingEnabled': messagingEnabled,
        'multiSchoolEnabled': multiSchoolEnabled,
      },
      'settings': {
        if (defaultCountry != null) 'defaultCountry': defaultCountry,
        if (supportEmail != null) 'supportEmail': supportEmail,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SystemConfig copyWith({
    String? version,
    bool? maintenanceMode,
    bool? fingerprintEnabled,
    bool? messagingEnabled,
    bool? multiSchoolEnabled,
    String? defaultCountry,
    String? supportEmail,
  }) {
    return SystemConfig(
      version: version ?? this.version,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
      messagingEnabled: messagingEnabled ?? this.messagingEnabled,
      multiSchoolEnabled: multiSchoolEnabled ?? this.multiSchoolEnabled,
      defaultCountry: defaultCountry ?? this.defaultCountry,
      supportEmail: supportEmail ?? this.supportEmail,
      updatedAt: updatedAt,
    );
  }
}
