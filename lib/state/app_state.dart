import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/test_record.dart';
import '../services/connectivity_service.dart';
import '../services/speed_test_service.dart';
import '../services/latency_service.dart';
import '../services/diagnosis_service.dart';
import '../services/history_service.dart';
import '../services/anomaly_service.dart';

/// Central application state — consumed by all screens via Provider.
///
/// Holds current connectivity, test results, diagnosis, history,
/// settings, and anomaly insights.  Calls notifyListeners() whenever
/// any property changes so that listening widgets rebuild.
class AppState extends ChangeNotifier {
  // ── Services ─────────────────────────────────────────────────────
  final ConnectivityService _connectivity = ConnectivityService();
  final SpeedTestService _speedTest = SpeedTestService();
  final LatencyService _latency = LatencyService();
  final DiagnosisService _diagnosis = DiagnosisService();
  final HistoryService _history = HistoryService();
  final NetworkInfo _networkInfo = NetworkInfo();

  StreamSubscription<String>? _connectivitySub;
  Timer? _autoRefreshTimer;

  // ── Settings box (persistent) ────────────────────────────────────
  late Box _settingsBox;

  // ── Connectivity ─────────────────────────────────────────────────
  String connectionType = 'Unknown';
  String wifiName = '';

  // ── Speed Test results ───────────────────────────────────────────
  double downloadSpeed = 0;
  double uploadSpeed = 0;
  double latency = 0;
  double jitter = 0;
  bool isTesting = false;
  String? testError;

  // ── Diagnosis results ────────────────────────────────────────────
  DiagnosisResult? lastDiagnosis;
  bool isDiagnosing = false;
  String? diagnosisError;

  // ── History ──────────────────────────────────────────────────────
  List<TestRecord> historyRecords = [];
  String historyRange = 'day';

  // ── Settings ─────────────────────────────────────────────────────
  bool autoRefreshEnabled = false;
  int refreshIntervalMinutes = 1;

  // ── Anomaly ──────────────────────────────────────────────────────
  String? anomalyInsight;

  // ── Initialization ───────────────────────────────────────────────

  /// Call once at app start, after Hive is initialized.
  Future<void> init() async {
    // Open the persistent settings box.
    _settingsBox = await Hive.openBox('settings');

    // Restore saved settings.
    autoRefreshEnabled = _settingsBox.get('autoRefreshEnabled', defaultValue: false);
    refreshIntervalMinutes = _settingsBox.get('refreshIntervalMinutes', defaultValue: 1);

    // Start listening to connectivity changes.
    await _connectivity.init();
    connectionType = _connectivity.connectionType;

    // Read WiFi SSID.
    await _updateWifiName();

    _connectivitySub = _connectivity.onChanged.listen((type) {
      connectionType = type;
      // _updateWifiName() is async and calls notifyListeners() when done.
      // No need to call notifyListeners() here — it would fire before
      // wifiName is updated, showing stale data.
      _updateWifiName();
    });

    // Open the Hive history box.
    await _history.init();

    // Load initial history.
    loadHistory();

    // Restore auto-refresh if it was enabled.
    if (autoRefreshEnabled) {
      _startAutoRefresh();
    }
  }

  /// Read the WiFi SSID from the OS.
  Future<void> _updateWifiName() async {
    if (connectionType == 'WiFi') {
      try {
        final name = await _networkInfo.getWifiName();
        // network_info_plus returns the name wrapped in quotes on some platforms.
        wifiName = name?.replaceAll('"', '') ?? '';
      } catch (_) {
        wifiName = '';
      }
    } else {
      wifiName = connectionType; // 'Mobile', 'Ethernet', etc.
    }
    notifyListeners();
  }

  // ── Speed Test ───────────────────────────────────────────────────

  /// Run a full test cycle: download → upload → latency/jitter.
  /// Saves the result to history and checks for anomalies.
  Future<void> runSpeedTest() async {
    if (isTesting) return;
    isTesting = true;
    testError = null;
    downloadSpeed = 0;
    uploadSpeed = 0;
    notifyListeners();

    try {
      // 1. Download (with real-time gauge updates)
      final down = await _speedTest.measureDownload(
        onProgress: (currentMbps) {
          downloadSpeed = currentMbps;
          notifyListeners();
        },
      );
      if (down < 0) {
        testError = 'Download test failed — check your connection.';
        isTesting = false;
        notifyListeners();
        return;
      }
      downloadSpeed = down;
      notifyListeners();

      // 2. Upload
      final up = await _speedTest.measureUpload();
      if (up < 0) {
        uploadSpeed = 0;
        testError = 'Upload test failed (download succeeded).';
      } else {
        uploadSpeed = up;
      }
      notifyListeners();

      // 3. Latency + Jitter
      final result = await _latency.measureWithJitter();
      if (result.latency >= 0) {
        latency = result.latency;
        jitter = result.jitter;
      } else {
        latency = 0;
        jitter = 0;
      }
      notifyListeners();

      // 4. Save to history
      final record = TestRecord(
        timestamp: DateTime.now(),
        downloadMbps: downloadSpeed,
        uploadMbps: uploadSpeed,
        latencyMs: latency,
        jitterMs: jitter,
        connectionType: connectionType,
      );
      await _history.saveRecord(record);

      // 5. Check for anomalies
      _checkAnomaly(latency);

      // 6. Reload history so the History screen sees the new record.
      loadHistory();
    } catch (e) {
      testError = 'Test failed: ${e.toString()}';
    } finally {
      isTesting = false;
      notifyListeners();
    }
  }

  // ── Diagnosis ────────────────────────────────────────────────────

  /// Run a hop-by-hop diagnosis.
  Future<void> runDiagnosis() async {
    if (isDiagnosing) return;
    isDiagnosing = true;
    diagnosisError = null;
    lastDiagnosis = null;
    notifyListeners();

    try {
      lastDiagnosis = await _diagnosis.diagnose();
    } catch (e) {
      diagnosisError = 'Diagnosis failed: ${e.toString()}';
    } finally {
      isDiagnosing = false;
      notifyListeners();
    }
  }

  // ── History ──────────────────────────────────────────────────────

  /// Reload history records from Hive for the given range.
  void loadHistory({String? range}) {
    if (range != null) historyRange = range;
    historyRecords = _history.getRecords(range: historyRange);
    notifyListeners();
  }

  /// Delete all stored records.
  Future<void> clearHistory() async {
    await _history.clearAll();
    historyRecords = [];
    notifyListeners();
  }

  /// Total number of records ever stored.
  int get historyCount => _history.count;

  // ── CSV Export ───────────────────────────────────────────────────

  /// Export all history records as a CSV file and open the share sheet.
  Future<void> exportCsv() async {
    final records = _history.getAllRecords();
    if (records.isEmpty) return;

    // Build CSV string.
    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Download (Mbps),Upload (Mbps),Latency (ms),Jitter (ms),Connection');
    for (final r in records) {
      buffer.writeln(
        '${r.timestamp.toIso8601String()},'
        '${r.downloadMbps.toStringAsFixed(2)},'
        '${r.uploadMbps.toStringAsFixed(2)},'
        '${r.latencyMs.toStringAsFixed(1)},'
        '${r.jitterMs.toStringAsFixed(1)},'
        '${r.connectionType}',
      );
    }

    // Write to a temporary file.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/netpulse_history.csv');
    await file.writeAsString(buffer.toString());

    // Trigger native share sheet.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'NetPulse History Export',
    );
  }

  // ── Auto-Refresh ─────────────────────────────────────────────────

  /// Toggle the auto-refresh timer (persisted to Hive).
  void toggleAutoRefresh(bool enabled) {
    autoRefreshEnabled = enabled;
    _settingsBox.put('autoRefreshEnabled', enabled);
    if (enabled) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
    notifyListeners();
  }

  /// Change the refresh interval in minutes (persisted to Hive).
  void setRefreshInterval(int minutes) {
    refreshIntervalMinutes = minutes;
    _settingsBox.put('refreshIntervalMinutes', minutes);
    if (autoRefreshEnabled) {
      _stopAutoRefresh();
      _startAutoRefresh();
    }
    notifyListeners();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(
      Duration(minutes: refreshIntervalMinutes),
      (_) => _runLightweightTest(),
    );
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Lightweight test for auto-refresh: connectivity + latency only.
  Future<void> _runLightweightTest() async {
    if (isTesting) return;

    try {
      final result = await _latency.measureWithJitter();
      if (result.latency >= 0) {
        latency = result.latency;
        jitter = result.jitter;

        final record = TestRecord(
          timestamp: DateTime.now(),
          downloadMbps: 0,
          uploadMbps: 0,
          latencyMs: latency,
          jitterMs: jitter,
          connectionType: connectionType,
        );
        await _history.saveRecord(record);
        _checkAnomaly(latency);
        loadHistory();
      }
    } catch (_) {}
  }

  // ── Anomaly Detection ────────────────────────────────────────────

  void _checkAnomaly(double newLatency) {
    final allRecords = _history.getAllRecords();
    final latencyHistory =
        allRecords.map((r) => r.latencyMs).where((l) => l > 0).toList();

    final result = AnomalyService.check(latencyHistory, newLatency);
    if (result != null && result.isAnomaly) {
      anomalyInsight = result.message;
    } else {
      anomalyInsight = null;
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────────

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _stopAutoRefresh();
    _connectivity.dispose();
    super.dispose();
  }
}
