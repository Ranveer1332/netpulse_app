import 'dart:math';

/// Result of an anomaly check.
class AnomalyResult {
  final bool isAnomaly;
  final String message;
  final double zScore;
  final double mean;
  final double stdDev;

  AnomalyResult({
    required this.isAnomaly,
    required this.message,
    required this.zScore,
    required this.mean,
    required this.stdDev,
  });
}

/// Lightweight statistical anomaly detection — NO ML libraries.
///
/// Maintains a rolling window of the last ~20 latency readings and
/// flags new readings that deviate more than 2 standard deviations
/// from the rolling average.
///
/// The math (for viva):
///
///   mean   = Σ(values) / n
///   stddev = √( Σ(xi − mean)² / n )
///   z-score = |new_value − mean| / stddev
///
///   If z-score > 2  →  the reading is in the top/bottom ~2.3% of
///   the distribution, which we flag as anomalous.
///
/// This is a standard z-score test, the same concept used in process
/// control (Six Sigma) and network monitoring.
class AnomalyService {
  static const int windowSize = 20;
  static const double threshold = 2.0;

  /// Check whether [newLatency] is anomalous given [latencyHistory].
  ///
  /// [latencyHistory] should be ordered oldest-first and contain at
  /// least 5 readings for the statistics to be meaningful.
  ///
  /// Returns null if there isn't enough data to make a judgement.
  static AnomalyResult? check(
    List<double> latencyHistory,
    double newLatency,
  ) {
    // Not enough data to establish a baseline.
    if (latencyHistory.length < 5) return null;

    // Take the most recent `windowSize` readings as our rolling window.
    final window = latencyHistory.length > windowSize
        ? latencyHistory.sublist(latencyHistory.length - windowSize)
        : latencyHistory;

    // ── Step 1: Compute the mean ──────────────────────────────────
    final mean = window.reduce((a, b) => a + b) / window.length;

    // ── Step 2: Compute the standard deviation ────────────────────
    final sumSquaredDiffs =
        window.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b);
    final variance = sumSquaredDiffs / window.length;
    final stdDev = sqrt(variance);

    // If all readings are identical, stddev is 0 — can't compute z-score.
    if (stdDev == 0) return null;

    // ── Step 3: Compute z-score for the new reading ───────────────
    final zScore = (newLatency - mean).abs() / stdDev;

    // ── Step 4: Flag if beyond threshold ──────────────────────────
    if (zScore > threshold) {
      final direction =
          newLatency > mean ? 'spiked well above' : 'dropped well below';
      return AnomalyResult(
        isAnomaly: true,
        message:
            'Latency $direction your normal range '
            '(avg: ${mean.toStringAsFixed(0)} ms, '
            'yours: ${newLatency.toStringAsFixed(0)} ms).',
        zScore: zScore,
        mean: mean,
        stdDev: stdDev,
      );
    }

    return AnomalyResult(
      isAnomaly: false,
      message: '',
      zScore: zScore,
      mean: mean,
      stdDev: stdDev,
    );
  }
}
