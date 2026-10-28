import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/cards.dart';
import '../state/app_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Compute stats from watched state (not context.read which is a Provider anti-pattern).
    final withDownload = state.historyRecords.where((r) => r.downloadMbps > 0).toList();
    final avg = withDownload.isEmpty
        ? 0.0
        : withDownload.map((r) => r.downloadMbps).reduce((a, b) => a + b) / withDownload.length;
    final peak = withDownload.isEmpty
        ? 0.0
        : withDownload.map((r) => r.downloadMbps).reduce(max);

    // Dynamic gauge max: round up to nearest nice number above peak/current.
    final rawMax = [peak, state.downloadSpeed, 50.0].reduce(max);
    final gaugeMax = (rawMax / 50).ceil() * 50.0; // 50, 100, 150, 200, …

    // For the sparkline, take up to last 10 records with download data
    final recentHistory = withDownload
        .take(10)
        .toList()
        .reversed
        .toList();
    final spots = recentHistory.isEmpty
        ? [const FlSpot(0, 0)]
        : recentHistory
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.downloadMbps))
            .toList();

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: () => state.runSpeedTest(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Row
            Row(
              children: [
                StatusChip(
                    label: state.connectionType,
                    dotColor: state.connectionType != 'None'
                        ? AppColors.teal
                        : AppColors.danger),
                const SizedBox(width: 8),
                if (state.wifiName.isNotEmpty)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cell_tower_rounded,
                            size: 14,
                            color: AppColors.muted.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            state.wifiName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Speed Gauge — dynamic max
            Center(
              child: SpeedGauge(speed: state.downloadSpeed, maxSpeed: gaugeMax),
            ),
            const SizedBox(height: 8),

            // Stream Stable chip (or Error if test failed)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: state.testError != null
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: state.testError != null
                            ? AppColors.danger
                            : AppColors.teal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (state.testError != null
                                    ? AppColors.danger
                                    : AppColors.teal)
                                .withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.testError != null
                          ? 'Test Failed'
                          : state.downloadSpeed > 0
                              ? 'Stream Stable • ${state.downloadSpeed.clamp(0, 100).toStringAsFixed(1)} Mbps'
                              : 'Pull down or tap Run Test',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: state.testError != null
                            ? AppColors.danger
                            : AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (state.anomalyInsight != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warn, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.anomalyInsight!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.warn),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Run Test Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: state.connectionType == 'None'
                      ? AppColors.muted
                      : AppColors.teal,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (state.connectionType != 'None')
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed:
                      (state.isTesting || state.connectionType == 'None')
                          ? null
                          : () => state.runSpeedTest(),
                  icon: state.isTesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(state.isTesting ? 'Testing…' : 'Run Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stats Row
            Row(
              children: [
                StatCard(
                  label: 'Upload',
                  value: state.uploadSpeed.toStringAsFixed(1),
                  unit: 'Mbps',
                  iconColor: AppColors.blue,
                  icon: Icons.upload_rounded,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Latency',
                  value: '${state.latency.toInt()}',
                  unit: 'ms',
                  iconColor: AppColors.teal,
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(width: 12),
                StatCard(
                  label: 'Jitter',
                  value: '${state.jitter.toInt()}',
                  unit: 'ms',
                  iconColor: AppColors.muted,
                  icon: Icons.show_chart_rounded,
                ),
              ],
            ),

            // Connection History
            NetCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Connection History',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Last ${recentHistory.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Avg / Peak row
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Avg ${avg.toStringAsFixed(1)} Mbps',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Peak ${peak.toStringAsFixed(1)} Mbps',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 80,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        minY: 0,
                        maxY: peak > 0 ? peak * 1.2 : 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.teal,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.teal.withValues(alpha: 0.2),
                                  AppColors.teal.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
