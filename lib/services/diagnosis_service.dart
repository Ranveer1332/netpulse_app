import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'latency_service.dart';

/// Result of a hop-by-hop diagnosis.
class DiagnosisResult {
  final String hopDiagnosisMode;
  /// 'good', 'warn', 'bad', or 'testing'
  final String deviceStatus;
  final int deviceLatency;

  final String routerStatus;
  final int routerLatency;
  final String? routerIp;

  final String externalStatus;
  final int externalLatency;

  final String verdict;

  /// Packet loss percentage (0–100).
  final double packetLoss;

  /// Jitter in ms (mean absolute diff between consecutive pings).
  final double jitter;

  /// DNS resolution time in ms.
  final int dnsResolutionMs;

  DiagnosisResult({
    required this.hopDiagnosisMode,
    required this.deviceStatus,
    required this.deviceLatency,
    required this.routerStatus,
    required this.routerLatency,
    this.routerIp,
    required this.externalStatus,
    required this.externalLatency,
    required this.verdict,
    required this.packetLoss,
    required this.jitter,
    required this.dnsResolutionMs,
  });
}

/// Hop-by-hop network diagnosis — the flagship feature.
///
/// How it works (for viva):
///
/// 1. The device itself is always considered reachable (hop 0, ~1 ms).
///
/// 2. We discover the local gateway (router) IP using network_info_plus,
///    which reads the OS routing table.  Then we open a TCP connection
///    to the router on port 80 (HTTP admin panel — most consumer routers
///    listen here) and measure the round-trip time.  This tells us how
///    healthy the LAN segment is.
///
/// 3. We open a TCP connection to Google Public DNS (8.8.8.8) on port 53.
///    This traverses the full path: device → router → ISP → internet.
///    The round-trip time tells us about the WAN segment.
///
/// 4. By comparing router RTT vs external RTT we can isolate WHERE the
///    bottleneck is:
///
///    | Router   | External   | Meaning                                     |
///    |----------|------------|---------------------------------------------|
///    | Fast     | Slow       | LAN is fine, ISP is the bottleneck           |
///    | Slow     | Slow       | LAN itself is the problem (bad WiFi/router)  |
///    | Timeout  | Any        | Can't even reach the router                  |
///    | Fast     | Timeout    | ISP or upstream is down                      |
///    | Fast     | Fast       | Everything looks healthy                     |
///
/// 5. Packet Loss: We send [pingCount] TCP pings and count how many fail.
///    packetLoss = (failures / total) × 100%.
///
/// 6. Jitter: For successful pings, we compute the mean absolute difference
///    between consecutive readings (RFC 3550).
///
class DiagnosisService {
  final LatencyService _latency = LatencyService();
  final NetworkInfo _networkInfo = NetworkInfo();

  static const int pingCount = 10;

  /// Run a full three-hop diagnosis and return the result.
  Future<DiagnosisResult> diagnose() async {
    final connResults = await Connectivity().checkConnectivity();
    final bool isMobile = connResults.contains(ConnectivityResult.mobile);
    final String hopDiagnosisMode = isMobile ? 'wanOnly' : 'full';

    // ─── Hop 0: Device ───────────────────────────────────────────────
    const deviceLatency = 1;
    const deviceStatus = 'good';

    // ─── Hop 1: Router (LAN) ─────────────────────────────────────────
    String? routerIp;
    int routerLatency = -1;
    String routerStatus = 'bad';

    if (!isMobile) {
      try {
        routerIp = await _networkInfo.getWifiGatewayIP();
      } catch (_) {}

      if (routerIp != null && routerIp.isNotEmpty) {
        // Try common router ports: 80 (HTTP admin), 443 (HTTPS), 53 (DNS relay).
        for (final port in [80, 443, 53]) {
          routerLatency = await _latency.ping(
            routerIp,
            port: port,
            timeout: const Duration(seconds: 2),
          );
          if (routerLatency >= 0) break;
        }

        if (routerLatency >= 0) {
          routerStatus = routerLatency < 50 ? 'good' : 'warn';
        }
      }
    } else {
      routerStatus = 'good';
      routerLatency = 0;
    }

    // ─── Hop 2: External / Internet (WAN) ────────────────────────────
    // Send multiple pings to measure packet loss and jitter.
    final readings = <int>[];
    int failures = 0;

    for (int i = 0; i < pingCount; i++) {
      final ms = await _latency.ping(
        '8.8.8.8',
        port: 53,
        timeout: const Duration(seconds: 3),
      );
      if (ms >= 0) {
        readings.add(ms);
      } else {
        failures++;
      }
      // Small delay between pings.
      if (i < pingCount - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // ── Packet loss ──
    final packetLoss = (failures / pingCount) * 100.0;

    // ── Average latency ──
    int externalLatency;
    if (readings.isNotEmpty) {
      externalLatency =
          (readings.reduce((a, b) => a + b) / readings.length).round();
    } else {
      externalLatency = -1;
    }

    // ── Jitter (RFC 3550: mean |diff| between consecutive readings) ──
    double jitter = 0;
    if (readings.length >= 2) {
      double totalDiff = 0;
      for (int i = 1; i < readings.length; i++) {
        totalDiff += (readings[i] - readings[i - 1]).abs();
      }
      jitter = totalDiff / (readings.length - 1);
    }

    // ── External status classification ──
    String externalStatus;
    if (externalLatency < 0) {
      externalStatus = 'bad';
    } else if (externalLatency > 100) {
      externalStatus = 'warn';
    } else {
      externalStatus = 'good';
    }

    // Also flag if packet loss is high.
    if (packetLoss >= 20 && externalStatus == 'good') {
      externalStatus = 'warn';
    }

    // ─── DNS Resolution time ─────────────────────────────────────────
    // Measure how long a TCP connect to 8.8.8.8:53 takes (simulates DNS).
    final dnsMs = readings.isNotEmpty ? readings.first : 0;

    // ─── Verdict logic ───────────────────────────────────────────────
    String verdict;

    if (isMobile) {
      if (externalStatus == 'good') {
        verdict = 'Mobile connection is healthy.';
      } else {
        verdict = 'Mobile/carrier connection is slow right now.';
      }
    } else {
      if (routerLatency < 0 && routerIp == null) {
        verdict = 'Cannot determine gateway — are you connected to WiFi?';
      } else if (routerLatency < 0) {
        verdict = 'Cannot reach your router — check your local network.';
      } else if (externalLatency < 0) {
        verdict =
            'Your router is reachable but the internet is not — possible ISP outage.';
      } else if (packetLoss > 10) {
        verdict =
            'High packet loss detected (${packetLoss.toStringAsFixed(0)}%). Your connection is unstable.';
      } else if (routerLatency < 50 && externalLatency > 100) {
        verdict =
            'Your WiFi is fine — the slowdown is from your ISP.';
      } else if (routerLatency >= 50 && externalLatency > 100) {
        verdict =
            'Both your router and internet are slow — the issue is likely your local WiFi/router.';
      } else {
        verdict =
            'All hops look healthy! Your connection is performing well.';
      }
    }

    return DiagnosisResult(
      hopDiagnosisMode: hopDiagnosisMode,
      deviceStatus: deviceStatus,
      deviceLatency: deviceLatency,
      routerStatus: routerStatus,
      routerLatency: routerLatency < 0 ? 0 : routerLatency,
      routerIp: routerIp,
      externalStatus: externalStatus,
      externalLatency: externalLatency < 0 ? 0 : externalLatency,
      verdict: verdict,
      packetLoss: packetLoss,
      jitter: jitter,
      dnsResolutionMs: dnsMs,
    );
  }
}
