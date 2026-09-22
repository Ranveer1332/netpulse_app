import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../state/app_state.dart';
import '../models/test_record.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<FlSpot> _getDownloadSpots(List<TestRecord> records) {
    final data = records.reversed.toList();
    return data.isEmpty
        ? [const FlSpot(0, 0)]
        : data
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.downloadMbps))
            .toList();
  }

  List<FlSpot> _getLatencySpots(List<TestRecord> records) {
    final data = records.reversed.toList();
    return data.isEmpty
        ? [const FlSpot(0, 0)]
        : data
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.latencyMs))
            .toList();
  }

  double _getAvgDownload(List<TestRecord> records) {
    final withDown = records.where((r) => r.downloadMbps > 0).toList();
    if (withDown.isEmpty) return 0.0;
    return withDown.map((r) => r.downloadMbps).reduce((a, b) => a + b) /
        withDown.length;
  }

  double _getMinLatency(List<TestRecord> records) {
    final withLat = records.where((r) => r.latencyMs > 0).toList();
    if (withLat.isEmpty) return 0.0;
    return withLat.map((r) => r.latencyMs).reduce(min);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final records = state.historyRecords;

    final avgDown = _getAvgDownload(records);
    final minLat = _getMinLatency(records);

    // Calculate dynamic Y-axis bounds to prevent lines from breaking out of the chart
    double maxVal = 100.0;
    if (records.isNotEmpty) {
      final maxDownload = records.map((r) => r.downloadMbps).fold(0.0, max);
      final maxLatency = records.map((r) => r.latencyMs.toDouble()).fold(0.0, max);
      final highest = max(maxDownload, maxLatency);
      if (highest > 80) {
        maxVal = highest + (highest * 0.2); // Add 20% padding at the top
      }
    }
    
    double yInterval = maxVal / 4;
    if (yInterval < 25) yInterval = 25;

    // Dynamic X-axis spacing to prevent overlaps
    double xInterval = (records.length / 5).ceilToDouble();
    if (xInterval < 1) xInterval = 1;

    final reversedRecords = records.reversed.toList();

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: () async => state.loadHistory(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with settings icon
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('History',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'Historical bandwidth & latency logs',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Day/Week Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _ToggleButton(
                    label: 'Day',
                    isActive: state.historyRange == 'day',
                    onTap: () => state.loadHistory(range: 'day'),
                  ),
                  _ToggleButton(
                    label: 'Week',
                    isActive: state.historyRange == 'week',
                    onTap: () => state.loadHistory(range: 'week'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chart Card
            NetCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  // Legend row
                  Row(
                    children: [
                      const _LegendDot(
                          color: AppColors.teal, label: 'Download'),
                      const SizedBox(width: 12),
                      const _LegendDot(
                          color: AppColors.blue, label: 'Latency'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Optimal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Avg ${avgDown.toStringAsFixed(1)} Mbps · ${minLat.toStringAsFixed(0)} ms (best)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(), // Prevent lines from drawing outside the chart area
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: yInterval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white.withValues(alpha: 0.05),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: yInterval,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: xInterval,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= reversedRecords.length) {
                                  return const SizedBox.shrink();
                                }
                                
                                final dt = reversedRecords[i].timestamp;
                                String label;
                                if (state.historyRange == 'week') {
                                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  label = days[dt.weekday - 1];
                                } else {
                                  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                                  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                                  label = '$h $ampm';
                                }
                                
                                return Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textDim,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: maxVal,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _getDownloadSpots(records),
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
                                  AppColors.teal.withValues(alpha: 0.15),
                                  AppColors.teal.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: _getLatencySpots(records),
                            isCurved: true,
                            color: AppColors.blue,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.blue.withValues(alpha: 0.1),
                                  AppColors.blue.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 400),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Past Readings
            NetCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Past Readings',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${records.length} tests recorded',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => state.clearHistory(),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  AppColors.danger.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No history for this period.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                  ...List.generate(records.length, (i) {
                    final r = records[i];
                    return Column(
                      children: [
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 18,
                            endIndent: 18,
                            color: AppColors.border,
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTime(r.timestamp),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${r.downloadMbps.toStringAsFixed(1)} ',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.teal,
                                        ),
                                      ),
                                      const Text(
                                        'Mbps',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textDim,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${r.latencyMs.toInt()} ',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.blue,
                                        ),
                                      ),
                                      const Text(
                                        'ms',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textDim,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.connectionType,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  if (records.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'End of logs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.teal.withValues(alpha: 0.7),
                          ),
                        ),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    String prefix;
    if (diff.inDays == 0 && now.day == dt.day) {
      prefix = 'Today';
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != dt.day)) {
      prefix = 'Yesterday';
    } else {
      prefix = '${dt.month}/${dt.day}';
    }

    final h = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$prefix, $h:$m $ampm';
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.teal.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.teal : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
