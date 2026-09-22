import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return RefreshIndicator(
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        // Just reload to refresh counts etc.
        state.loadHistory();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            const Text(
              'Diagnostics configuration & telemetry preferences',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 28),

            // --- MONITORING ---
            const _SectionLabel(label: 'MONITORING'),
            const SizedBox(height: 12),
            NetCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.autorenew_rounded,
                    title: 'Auto-Refresh',
                    subtitle: 'Periodically re-test speed',
                    trailing: Switch(
                      value: state.autoRefreshEnabled,
                      activeTrackColor:
                          AppColors.teal.withValues(alpha: 0.4),
                      activeThumbColor: AppColors.teal,
                      onChanged: (v) => state.toggleAutoRefresh(v),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.border,
                  ),
                  _SettingsTile(
                    icon: Icons.schedule_rounded,
                    title: 'Refresh Interval',
                    subtitle: 'Background diagnostic cycle',
                    trailing: DropdownButton<int>(
                      value: state.refreshIntervalMinutes,
                      dropdownColor: AppColors.cardHover,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: AppColors.teal),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 1, child: Text('1 min')),
                        DropdownMenuItem(
                            value: 5, child: Text('5 min')),
                        DropdownMenuItem(
                            value: 15, child: Text('15 min')),
                        DropdownMenuItem(
                            value: 60, child: Text('60 min')),
                      ],
                      onChanged: (v) {
                        if (v != null) state.setRefreshInterval(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- DIAGNOSIS ---
            const _SectionLabel(label: 'DIAGNOSIS'),
            const SizedBox(height: 12),
            NetCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                icon: Icons.dns_rounded,
                title: 'External Test Server',
                subtitle: 'Used for WAN hop testing',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '8.8.8.8',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- DATA ---
            const _SectionLabel(label: 'DATA'),
            const SizedBox(height: 12),
            NetCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear History',
                    subtitle: '${state.historyCount} stored readings',
                    trailing: _ActionChip(
                      label: 'Clear',
                      color: AppColors.danger,
                      icon: Icons.delete_outline_rounded,
                      onTap: () {
                        state.clearHistory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('History cleared'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.border,
                  ),
                  _SettingsTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export as CSV',
                    subtitle: '${state.historyCount} records to export',
                    trailing: _ActionChip(
                      label: _isExporting ? 'Exporting…' : 'Export',
                      color: AppColors.teal,
                      icon: Icons.file_download_outlined,
                      onTap: _isExporting
                          ? () {}
                          : () async {
                              if (state.historyCount == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('No data to export yet.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              setState(
                                  () => _isExporting = true);
                              try {
                                await state.exportCsv();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Export failed: $e'),
                                    duration:
                                        const Duration(seconds: 3),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(
                                      () => _isExporting = false);
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- ABOUT ---
            const _SectionLabel(label: 'ABOUT'),
            const SizedBox(height: 12),
            NetCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: '',
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    color: AppColors.border,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.teal
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.wifi_tethering_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NetPulse',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time network speed & connectivity diagnostics for your device. Continuous latency monitoring, packet loss detection, and gateway telemetry.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.muted
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

// --- Section label ---
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textDim,
        letterSpacing: 1.4,
      ),
    );
  }
}

// --- Settings tile ---
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// --- Action chip button ---
class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
