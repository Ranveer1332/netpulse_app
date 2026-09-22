import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Listens for network state changes via connectivity_plus.
///
/// Exposes [connectionType] (sync) and [onChanged] (stream) so the UI
/// can react to WiFi ↔ Mobile ↔ None transitions without polling.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  String _currentType = 'Unknown';

  /// The most-recently-observed connection type as a human-readable string.
  String get connectionType => _currentType;

  /// Stream that fires whenever the network type changes.
  /// Each event is a human-readable label: 'WiFi', 'Mobile', 'None', etc.
  final _controller = StreamController<String>.broadcast();
  Stream<String> get onChanged => _controller.stream;

  /// Start listening. Call once at app startup.
  Future<void> init() async {
    // Read current state immediately.
    final initial = await _connectivity.checkConnectivity();
    _currentType = _mapResults(initial);
    _controller.add(_currentType);

    // Subscribe to future changes.
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _currentType = _mapResults(results);
      _controller.add(_currentType);
    });
  }

  /// Map a list of ConnectivityResult enums to a single display label.
  String _mapResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.mobile)) return 'Mobile';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    if (results.contains(ConnectivityResult.none)) return 'None';
    return 'Unknown';
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
