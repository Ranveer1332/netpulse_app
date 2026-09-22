import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Measures download and upload speed in Mbps.
///
/// Download: opens multiple parallel HTTP streams to saturate the pipe
///           (same technique as Ookla/Fast.com), measures aggregate
///           bytes-over-time with per-stream counters (no data races).
///
/// Upload:   POSTs a generated payload using a streamed request so we
///           only time the upload phase, not the response download.
///
/// Formula:  Mbps = (total_bits) / (elapsed_seconds) / 1,000,000
class SpeedTestService {
  // ── Download test endpoints (tried in order) ──────────────────────
  // These are direct-download URLs (no redirects) served from global CDNs.
  static const _downloadUrls = [
    'http://speedtest.mumbai1.linode.com/100MB-mumbai.bin',
    'http://speedtest.singapore.linode.com/100MB-singapore.bin',
    'https://proof.ovh.net/files/100Mb.dat',
    'http://speedtest.tele2.net/100MB.zip',
  ];

  // ── Upload test endpoint ──────────────────────────────────────────
  static const _uploadUrl = 'https://httpbin.org/post';

  // ── Tuning constants ──────────────────────────────────────────────
  static const _numConnections = 6;
  static const _maxTestDurationMs = 12000; // 12 seconds hard cap
  static const _uploadBytes = 2000000; // 2 MB

  /// Stream-download a test file and return the measured speed in Mbps.
  ///
  /// Opens [_numConnections] parallel HTTP streams against a CDN and
  /// sums the downloaded bytes across all of them.  Each stream has its
  /// own byte counter (no shared mutable state between stream callbacks).
  ///
  /// Optionally calls [onProgress] with the current aggregate Mbps,
  /// useful for animating the gauge in real-time.
  ///
  /// Returns -1 on timeout or network error.
  Future<double> measureDownload({
    void Function(double currentMbps)? onProgress,
  }) async {
    for (final url in _downloadUrls) {
      final result = await _tryDownload(url, onProgress: onProgress);
      if (result >= 0) return result;
    }
    return -1; // all mirrors failed
  }

  Future<double> _tryDownload(
    String url, {
    void Function(double currentMbps)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Per-stream byte counters — avoids any shared-mutation issues.
    final byteCounts = List<int>.filled(_numConnections, 0);
    bool isTesting = true;
    bool anySuccess = false;

    // Completer fires when ALL streams have finished (or failed).
    final allDone = Completer<void>();
    int finishedCount = 0;

    void onStreamFinished() {
      finishedCount++;
      if (finishedCount >= _numConnections && !allDone.isCompleted) {
        allDone.complete();
      }
    }

    // Launch parallel download streams.
    for (int i = 0; i < _numConnections; i++) {
      _runStream(i, url, byteCounts, () => isTesting, (success) {
        if (success) anySuccess = true;
        onStreamFinished();
      });
    }

    // Wait a moment for streams to start connecting.
    await Future.delayed(const Duration(milliseconds: 500));

    // Progress reporting loop — exits when EITHER:
    //   • all streams finish (allDone completes), OR
    //   • max duration elapses (hard cap).
    while (isTesting && stopwatch.elapsedMilliseconds < _maxTestDurationMs) {
      // Race: wait 250ms OR allDone, whichever comes first.
      await Future.any([
        Future.delayed(const Duration(milliseconds: 250)),
        allDone.future,
      ]);

      final totalBytes = byteCounts.reduce((a, b) => a + b);
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds > 0.5 && onProgress != null) {
        onProgress((totalBytes * 8) / seconds / 1000000);
      }

      // If all streams are done, no point waiting longer.
      if (allDone.isCompleted) break;
    }

    // Signal streams to stop.
    isTesting = false;

    // Give streams a moment to close gracefully.
    if (!allDone.isCompleted) {
      await Future.any([
        allDone.future,
        Future.delayed(const Duration(seconds: 2)),
      ]);
    }

    stopwatch.stop();

    final totalBytes = byteCounts.reduce((a, b) => a + b);
    if (!anySuccess || totalBytes == 0) return -1;

    final seconds = stopwatch.elapsedMilliseconds / 1000.0;
    if (seconds <= 0) return -1;

    return (totalBytes * 8) / seconds / 1000000; // Mbps
  }

  /// Run a single download stream, writing its byte count to [byteCounts[index]].
  void _runStream(
    int index,
    String url,
    List<int> byteCounts,
    bool Function() shouldContinue,
    void Function(bool success) onDone,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      // CRITICAL: follow redirects — many CDN URLs (Google, etc.) use 302 redirects.
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await for (final chunk in response.stream) {
          if (!shouldContinue()) break;
          byteCounts[index] += chunk.length;
        }
        onDone(true);
      } else {
        // Drain the response body to free resources.
        await response.stream.drain();
        onDone(false);
      }
    } catch (_) {
      onDone(false);
    } finally {
      client.close();
    }
  }

  /// Measure upload speed in Mbps.
  ///
  /// Uses a StreamedRequest so we can time ONLY the upload phase
  /// (sending the request body), not the server's response download.
  ///
  /// Returns -1 on timeout or any network error.
  Future<double> measureUpload() async {
    final client = http.Client();
    final payload = Uint8List(_uploadBytes);

    try {
      final request = http.StreamedRequest('POST', Uri.parse(_uploadUrl));
      request.headers['Content-Type'] = 'application/octet-stream';
      request.contentLength = _uploadBytes;

      final stopwatch = Stopwatch()..start();

      // Send the request (starts the upload).
      final responseFuture = client.send(request);

      // Write the payload.
      request.sink.add(payload);
      await request.sink.close();

      // Wait for the server to acknowledge.
      final response = await responseFuture.timeout(
        const Duration(seconds: 30),
      );

      stopwatch.stop();

      // Drain response to free resources (don't time this).
      await response.stream.drain();

      if (response.statusCode == 200) {
        final bits = _uploadBytes * 8;
        final seconds = stopwatch.elapsedMilliseconds / 1000.0;
        if (seconds <= 0) return 0;
        return bits / seconds / 1000000; // Mbps
      }
      return -1;
    } catch (_) {
      return -1;
    } finally {
      client.close();
    }
  }
}
