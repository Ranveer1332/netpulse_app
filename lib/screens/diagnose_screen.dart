import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../state/app_state.dart';

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  _HopStatus _parseStatus(String? status) {
    switch (status) {
      case 'good':
        return _HopStatus.good;
      case 'warn':
        return _HopStatus.warn;
      case 'bad':
        return _HopStatus.bad;
      default:
        return _HopStatus.testing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diag = state.lastDiagnosis;
    final isDiagnosing = state.isDiagnosing;

    final deviceHop = _HopData(
        'Device',
        diag?.deviceLatency ?? 1,
        isDiagnosing
            ? _HopStatus.testing
            : _parseStatus(diag?.deviceStatus ?? 'good'));

    final routerHop = _HopData(
        'Router',
        diag?.routerLatency ?? 0,
        isDiagnosing
            ? _HopStatus.testing
            : (diag == null
                ? _HopStatus.good
                : _parseStatus(diag.routerStatus)));

    final internetHop = _HopData(
        'Internet',
        diag?.externalLatency ?? 0,
        isDiagnosing
            ? _HopStatus.testing
            : (diag == null
                ? _HopStatus.good
                : _parseStatus(diag.externalStatus)));

    final verdict = isDiagnosing
        ? 'Running diagnosis…'
        : (state.diagnosisError ??
            diag?.verdict ??
            'Ready to run diagnosis.');

    final packetLoss = diag?.packetLoss ?? 0.0;
    final jitterVar = diag?.jitter ?? 0.0;
    final dnsRes = diag?.dnsResolutionMs ?? 0;
    final ispGateway = diag?.routerIp ?? 'Unknown';

    bool isWanOnly = diag?.hopDiagnosisMode == 'wanOnly';
    if (diag == null) {
      isWanOnly = state.connectionType == 'Mobile';
    }

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: () => state.runDiagnosis(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with Live Link badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diagnose',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Hop-by-hop connectivity analysis',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                // Live Link badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.teal.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE LINK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Network Topology Route card
            NetCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.device_hub_rounded,
                              size: 16, color: AppColors.muted),
                          const SizedBox(width: 6),
                          const Text(
                            'NETWORK TOPOLOGY ROUTE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDim,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isWanOnly ? '2 Hops' : '3 Hops',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hop Chain — wrapped in FittedBox to prevent overflow
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HopNode(
                            data: deviceHop,
                            icon: Icons.phone_android_rounded),
                        if (!isWanOnly) const _HopConnector(label: 'LAN'),
                        if (!isWanOnly)
                          _HopNode(
                              data: routerHop,
                              icon: Icons.router_rounded),
                        const _HopConnector(label: 'WAN'),
                        _HopNode(
                            data: internetHop,
                            icon: Icons.language_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isWanOnly)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Router-level diagnosis isn't available on mobile data — no local, pingable gateway exists on cellular networks.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),

                  // Latency summary row
                  if (diag != null && !isDiagnosing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isWanOnly)
                          Text(
                            '• Internal ${deviceHop.ping + routerHop.ping} ms',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted),
                          ),
                        if (!isWanOnly)
                          const SizedBox(width: 16),
                        Text(
                          isWanOnly
                              ? '• External ${internetHop.ping} ms'
                              : '• External +${internetHop.ping - routerHop.ping > 0 ? internetHop.ping - routerHop.ping : 0} ms',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Verdict Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DIAGNOSTIC VERDICT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        internetHop.status == _HopStatus.bad ||
                                state.diagnosisError != null
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: internetHop.status == _HopStatus.bad ||
                                state.diagnosisError != null
                            ? AppColors.danger
                            : AppColors.teal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          verdict,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: state.diagnosisError != null
                                ? AppColors.danger
                                : AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Grid — real measured values
            Row(
              children: [
                Expanded(
                  child: _DiagStatCard(
                    icon: Icons.blur_circular_rounded,
                    label: 'Packet Loss',
                    value: '${packetLoss.toStringAsFixed(1)}%',
                    subtitle: packetLoss > 5
                        ? 'Elevated'
                        : packetLoss > 0
                            ? 'Minor Loss'
                            : 'Zero Loss',
                    color: packetLoss > 5 ? AppColors.danger : AppColors.teal,
                    subtitleColor: packetLoss > 5 ? AppColors.warn : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DiagStatCard(
                    icon: Icons.show_chart_rounded,
                    label: 'Jitter',
                    value: '${jitterVar.toStringAsFixed(1)} ms',
                    subtitle: jitterVar > 10
                        ? 'Unstable'
                        : jitterVar > 5
                            ? 'Moderate'
                            : 'Stable',
                    color: AppColors.blue,
                    subtitleColor: jitterVar > 10 ? AppColors.warn : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DiagStatCard(
                    icon: Icons.dns_rounded,
                    label: 'DNS Resolution',
                    value: '$dnsRes ms',
                    subtitle: 'Primary (8.8.8.8)',
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DiagStatCard(
                    icon: Icons.cell_tower_rounded,
                    label: 'Gateway',
                    value: ispGateway,
                    subtitle: routerHop.status == _HopStatus.good
                        ? 'Optimal'
                        : 'Elevated',
                    color: routerHop.status == _HopStatus.good
                        ? AppColors.teal
                        : AppColors.warn,
                    subtitleColor: routerHop.status == _HopStatus.good
                        ? AppColors.teal
                        : AppColors.warn,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Re-run Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    state.isDiagnosing ? null : () => state.runDiagnosis(),
                icon: state.isDiagnosing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.blue,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: Text(state.isDiagnosing
                    ? 'Diagnosing…'
                    : 'Re-run Diagnosis'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.card,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Data models ---

enum _HopStatus { good, warn, bad, testing }

class _HopData {
  final String label;
  final int ping;
  final _HopStatus status;
  _HopData(this.label, this.ping, this.status);
}

// --- Sub-widgets ---

class _HopNode extends StatelessWidget {
  final _HopData data;
  final IconData icon;
  const _HopNode({required this.data, required this.icon});

  Color get _ringColor => switch (data.status) {
        _HopStatus.good => AppColors.teal,
        _HopStatus.warn => AppColors.warn,
        _HopStatus.bad => AppColors.danger,
        _HopStatus.testing => AppColors.muted,
      };

  String get _statusLabel => switch (data.status) {
        _HopStatus.good => 'Optimal',
        _HopStatus.warn => 'Elevated',
        _HopStatus.bad => 'Critical',
        _HopStatus.testing => '…',
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ringColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _ringColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                ),
              ],
            ),
            child: data.status == _HopStatus.testing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.muted,
                    ),
                  )
                : Icon(icon, color: _ringColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.status == _HopStatus.testing ? '…' : '${data.ping} ms',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 10,
              color: _ringColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HopConnector extends StatelessWidget {
  final String label;
  const _HopConnector({this.label = ''});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            children: [
              ...List.generate(
                3,
                (_) => Container(
                  width: 4,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  color: AppColors.muted.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '›',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.muted.withValues(alpha: 0.5),
                  height: 1,
                ),
              ),
            ],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.teal.withValues(alpha: 0.6),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final Color? subtitleColor;

  const _DiagStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor ?? AppColors.muted,
              fontWeight:
                  subtitleColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
