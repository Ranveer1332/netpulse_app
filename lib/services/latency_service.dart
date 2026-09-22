import 'dart:io';

/// Measures network latency (round-trip time) and jitter.
///
/// Technique: open a TCP socket to a known-open port and time the
/// three-way handshake (SYN → SYN-ACK → ACK).  The elapsed time
/// approximates the network RTT because the handshake is the very
/// first thing that happens — no application-layer data is exchanged.
///
/// We use Google Public DNS (8.8.8.8) on port 53 because:
///   • It's always up and accepting TCP connections.
///   • Port 53 (DNS) is rarely blocked by firewalls.
class LatencyService {
  /// Default target for latency measurement.
  static const defaultHost = '8.8.8.8';
  static const defaultPort = 53;

  /// Measure a single RTT to [host]:[port] in milliseconds.
  ///
  /// Returns -1 if the host is unreachable within [timeout].
  Future<int> ping(
    String host, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } on SocketException catch (e) {
      stopwatch.stop();
      // "Connection refused" means the host IS reachable (it sent a TCP RST),
      // but the port is closed.  The RTT is still valid in that case.
      // Error code 61 = macOS ECONNREFUSED, 111 = Linux/Android ECONNREFUSED.
      if (e.osError != null &&
          (e.osError!.errorCode == 61 || e.osError!.errorCode == 111) &&
          stopwatch.elapsedMilliseconds < timeout.inMilliseconds ~/ 2) {
        return stopwatch.elapsedMilliseconds;
      }
      return -1; // truly unreachable / timed out
    } catch (_) {
      return -1;
    }
  }

  /// Take [count] consecutive latency readings and return the average
  /// latency (ms) and jitter (ms).
  ///
  /// Jitter = mean absolute difference between consecutive readings.
  /// This matches the RFC 3550 definition used in VoIP / real-time apps.
  ///
  /// Returns (avgLatency, jitter).  Both are -1 if no readings succeed.
  Future<({double latency, double jitter})> measureWithJitter({
    String host = defaultHost,
    int port = defaultPort,
    int count = 5,
  }) async {
    final readings = <int>[];

    for (int i = 0; i < count; i++) {
      final ms = await ping(host, port: port);
      if (ms >= 0) readings.add(ms);
      // Small delay between pings to avoid overwhelming the target.
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    if (readings.isEmpty) {
      return (latency: -1.0, jitter: -1.0);
    }

    // Average latency
    final avgLatency = readings.reduce((a, b) => a + b) / readings.length;

    // Jitter: average |difference| between consecutive readings
    double jitter = 0;
    if (readings.length >= 2) {
      double totalDiff = 0;
      for (int i = 1; i < readings.length; i++) {
        totalDiff += (readings[i] - readings[i - 1]).abs();
      }
      jitter = totalDiff / (readings.length - 1);
    }

    return (latency: avgLatency, jitter: jitter);
  }
}
