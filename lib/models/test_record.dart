/// A single test-cycle result, stored in Hive as a Map.
///
/// Fields match the project spec:
///   timestamp, downloadMbps, uploadMbps, latencyMs, jitterMs, connectionType
class TestRecord {
  final DateTime timestamp;
  final double downloadMbps;
  final double uploadMbps;
  final double latencyMs;
  final double jitterMs;
  final String connectionType;

  TestRecord({
    required this.timestamp,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.latencyMs,
    required this.jitterMs,
    required this.connectionType,
  });

  /// Deserialize from the Map stored in Hive.
  factory TestRecord.fromMap(Map<String, dynamic> m) {
    return TestRecord(
      timestamp: DateTime.parse(m['timestamp'] as String),
      downloadMbps: (m['downloadMbps'] as num).toDouble(),
      uploadMbps: (m['uploadMbps'] as num).toDouble(),
      latencyMs: (m['latencyMs'] as num).toDouble(),
      jitterMs: (m['jitterMs'] as num).toDouble(),
      connectionType: m['connectionType'] as String,
    );
  }

  /// Serialize to a plain Map for Hive storage (no type adapters needed).
  Map<String, dynamic> toMap() => {
        'timestamp': timestamp.toIso8601String(),
        'downloadMbps': downloadMbps,
        'uploadMbps': uploadMbps,
        'latencyMs': latencyMs,
        'jitterMs': jitterMs,
        'connectionType': connectionType,
      };
}
