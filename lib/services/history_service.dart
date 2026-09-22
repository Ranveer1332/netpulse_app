import 'package:hive_flutter/hive_flutter.dart';
import '../models/test_record.dart';

/// Persists test results locally using Hive.
///
/// Each record is stored as a plain `Map<String, dynamic>` — no type
/// adapters or code generation required.
class HistoryService {
  static const _boxName = 'test_history';
  late Box _box;

  /// Open the Hive box.  Call once at app startup (after Hive.initFlutter).
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Save a completed test record.
  Future<void> saveRecord(TestRecord record) async {
    await _box.add(record.toMap());
  }

  /// Fetch records filtered by time range.
  ///
  /// [range] is either 'day' (today only) or 'week' (last 7 days).
  /// Results are returned newest-first.
  List<TestRecord> getRecords({String range = 'day'}) {
    final now = DateTime.now();
    final DateTime cutoff;

    if (range == 'week') {
      cutoff = now.subtract(const Duration(days: 7));
    } else {
      // 'day' — from midnight today
      cutoff = DateTime(now.year, now.month, now.day);
    }

    final records = <TestRecord>[];
    for (int i = 0; i < _box.length; i++) {
      try {
        final raw = Map<String, dynamic>.from(_box.getAt(i) as Map);
        final record = TestRecord.fromMap(raw);
        if (record.timestamp.isAfter(cutoff)) {
          records.add(record);
        }
      } catch (_) {
        // Skip malformed entries
      }
    }

    // Newest first
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  /// Get ALL records (for anomaly detection rolling window).
  List<TestRecord> getAllRecords() {
    final records = <TestRecord>[];
    for (int i = 0; i < _box.length; i++) {
      try {
        final raw = Map<String, dynamic>.from(_box.getAt(i) as Map);
        records.add(TestRecord.fromMap(raw));
      } catch (_) {
        // Skip malformed
      }
    }
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records;
  }

  /// Delete all stored records.
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Number of stored records.
  int get count => _box.length;
}
