import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance.dart';
import '../models/school.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [ThemeSwitcher()],
      ),
      body: const ReportsView(),
    );
  }
}

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  _ReportRange _selectedRange = _ReportRange.thirtyDays;
  _ReportsSnapshot? _snapshot;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final currentSession =
          AuthService.currentSession ?? await AuthService.restoreSession();
      final isOwner = currentSession?.role == UserRole.systemOwner;
      final scopedSchoolId = isOwner ? null : currentSession?.schoolId;

      if (!isOwner && (scopedSchoolId == null || scopedSchoolId.isEmpty)) {
        throw Exception(
          'This account is not assigned to a school. Ask the system owner to set a schoolId on your user profile.',
        );
      }

      final coreResults = await Future.wait([
        FirebaseService.getStudents(),
        FirebaseService.getSessions(schoolId: scopedSchoolId),
      ]);

      final students = coreResults[0] as List<Student>;
      final sessions = coreResults[1] as List<Session>;

      List<School> schools = const [];
      if (isOwner) {
        try {
          schools = await FirebaseService.getSchools();
        } catch (_) {
          schools = const [];
        }
      }

      List<Map<String, dynamic>> recentActivity = const [];
      try {
        recentActivity = await FirebaseService.getRecentActivity(limit: 18);
      } catch (_) {
        recentActivity = const [];
      }

      if (!mounted) return;
      setState(() {
        _snapshot = _ReportsSnapshot(
          students: students,
          sessions: sessions,
          schools: schools,
          recentActivity: recentActivity,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load reports: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_snapshot == null) {
      return Center(
        child: Padding(
          padding: context.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: context.spacingSm),
              Text(
                _loadError ?? 'No report data available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: context.spacingMd),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final metrics = _buildMetrics(_snapshot!, _selectedRange);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = context.spacingMd;
          final twoColumns = constraints.maxWidth >= 1040;
          final cardWidth =
              twoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(metrics),
                SizedBox(height: spacing),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildAttendanceMixCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildDailyMixCard(metrics),
                    ),
                    SizedBox(width: cardWidth, child: _buildTrendCard(metrics)),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSessionsFlowCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildWeekdayRhythmCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSchoolShareCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSessionLoadCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildHeatmapCard(metrics),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildRecentSessionsCard(metrics),
                    ),
                  ],
                ),
                if (_loadError != null) ...[
                  SizedBox(height: spacing),
                  _buildSoftWarning(_loadError!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  _ReportMetrics _buildMetrics(_ReportsSnapshot snapshot, _ReportRange range) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: range.days - 1));
    final days = List<DateTime>.generate(
      range.days,
      (index) => _dateOnly(start.add(Duration(days: index))),
    );

    final attendanceByDay = <DateTime, _DailyAttendancePoint>{
      for (final day in days) day: _DailyAttendancePoint(day),
    };

    for (final student in snapshot.students) {
      for (final record in student.attendanceHistory) {
        final day = _dateOnly(record.date);
        final bucket = attendanceByDay[day];
        if (bucket == null) continue;
        bucket.add(record.status);
      }
    }

    final sessionCountByDay = <DateTime, int>{for (final day in days) day: 0};
    final sessionsInRange = <Session>[];
    for (final session in snapshot.sessions) {
      final day = _dateOnly(session.date);
      if (day.isBefore(start) || day.isAfter(today)) continue;
      sessionsInRange.add(session);
      sessionCountByDay.update(day, (value) => value + 1, ifAbsent: () => 1);
    }

    final attendanceTimeline = [for (final day in days) attendanceByDay[day]!];
    final sessionTimeline = [
      for (final day in days)
        _DailySessionPoint(day, sessionCountByDay[day] ?? 0),
    ];

    final present = attendanceTimeline.fold<int>(
      0,
      (total, day) => total + day.present,
    );
    final late = attendanceTimeline.fold<int>(
      0,
      (total, day) => total + day.late,
    );
    final absent = attendanceTimeline.fold<int>(
      0,
      (total, day) => total + day.absent,
    );
    final totalAttendanceRecords = present + late + absent;

    final attendanceRate =
        totalAttendanceRecords == 0
            ? 0.0
            : ((present + late) / totalAttendanceRecords) * 100;
    final onTimeRate =
        totalAttendanceRecords == 0
            ? 0.0
            : (present / totalAttendanceRecords) * 100;

    final totalAssignments = snapshot.students.fold<int>(
      0,
      (sum, student) => sum + student.sessionIds.length,
    );

    final sessionLoads =
        snapshot.sessions.where((session) => session.id != null).map((session) {
          final count =
              snapshot.students.where((student) {
                return student.sessionIds.contains(session.id);
              }).length;
          return _SessionLoadPoint(session: session, count: count);
        }).toList();

    final hasStudentMappings = sessionLoads.any((entry) => entry.count > 0);
    final topSessionLoads =
        (hasStudentMappings
              ? sessionLoads.where((entry) => entry.count > 0).toList()
              : sessionLoads)
          ..sort((a, b) {
            final countDiff = b.count.compareTo(a.count);
            if (countDiff != 0) return countDiff;
            return b.session.date.compareTo(a.session.date);
          });

    final schoolNamesById = <String, String>{
      for (final school in snapshot.schools)
        if (school.id != null) school.id!: school.name,
    };
    final weekdayRhythm = <_WeekdayRhythmPoint>[
      _WeekdayRhythmPoint(1, 'Mon'),
      _WeekdayRhythmPoint(2, 'Tue'),
      _WeekdayRhythmPoint(3, 'Wed'),
      _WeekdayRhythmPoint(4, 'Thu'),
      _WeekdayRhythmPoint(5, 'Fri'),
      _WeekdayRhythmPoint(6, 'Sat'),
      _WeekdayRhythmPoint(7, 'Sun'),
    ];
    final weekdayById = <int, _WeekdayRhythmPoint>{
      for (final point in weekdayRhythm) point.weekday: point,
    };
    for (final point in attendanceTimeline) {
      weekdayById[point.date.weekday]?.addAttendance(point);
    }
    for (final point in sessionTimeline) {
      weekdayById[point.date.weekday]?.sessions += point.count;
    }
    final sessionCountBySchool = <String, int>{};
    for (final session in sessionsInRange) {
      final schoolId = session.schoolId.trim();
      final key = schoolId.isEmpty ? 'unassigned' : schoolId;
      sessionCountBySchool.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    final allSchoolFlows =
        sessionCountBySchool.entries
            .map(
              (entry) => _SchoolSessionPoint(
                label:
                    schoolNamesById[entry.key] ??
                    (entry.key == 'unassigned'
                        ? 'Unassigned school'
                        : 'School ${entry.key.substring(0, math.min(4, entry.key.length)).toUpperCase()}'),
                count: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final schoolShares =
        allSchoolFlows.length <= 5
            ? allSchoolFlows
            : [
              ...allSchoolFlows.take(4),
              _SchoolSessionPoint(
                label: 'Other schools',
                count: allSchoolFlows
                    .skip(4)
                    .fold<int>(0, (sum, item) => sum + item.count),
              ),
            ];
    final schoolSessionTotal = sessionCountBySchool.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    final activitySuccessRate =
        snapshot.recentActivity.isEmpty
            ? null
            : snapshot.recentActivity
                    .where((item) => item['success'] == true)
                    .length /
                snapshot.recentActivity.length *
                100;

    return _ReportMetrics(
      range: range,
      start: start,
      end: today,
      totalStudents: snapshot.students.length,
      present: present,
      late: late,
      absent: absent,
      totalAttendanceRecords: totalAttendanceRecords,
      attendanceRate: attendanceRate,
      onTimeRate: onTimeRate,
      attendanceTimeline: attendanceTimeline,
      sessionTimeline: sessionTimeline,
      sessionsInRange: sessionsInRange.length,
      sessionsToday:
          snapshot.sessions.where((session) {
            return _isSameDay(session.date, today);
          }).length,
      activeSessions:
          snapshot.sessions.where((session) => session.isActive).length,
      totalAssignments: totalAssignments,
      averageAssignmentsPerStudent:
          snapshot.students.isEmpty
              ? 0.0
              : totalAssignments / snapshot.students.length,
      averageSessionsPerDay:
          sessionsInRange.isEmpty ? 0.0 : sessionsInRange.length / range.days,
      weekdayRhythm: weekdayRhythm,
      schoolCount: math.max(1, sessionCountBySchool.length),
      topSessionLoads: topSessionLoads.take(5).toList(),
      schoolFlows: allSchoolFlows.take(4).toList(),
      schoolShares: schoolShares,
      schoolSessionTotal: schoolSessionTotal,
      recentSessions: snapshot.sessions.take(6).toList(),
      activitySuccessRate: activitySuccessRate,
      recentActivityCount: snapshot.recentActivity.length,
      hasSessionMappings: hasStudentMappings,
    );
  }

  Widget _buildHeroCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final pulsePoints =
        metrics.attendanceTimeline.length > 14
            ? metrics.attendanceTimeline.sublist(
              metrics.attendanceTimeline.length - 14,
            )
            : metrics.attendanceTimeline;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primaryContainer, scheme.secondary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -36,
            child: _GlowCircle(
              color: Colors.white.withOpacity(0.14),
              size: 160,
            ),
          ),
          Positioned(
            bottom: -56,
            left: -24,
            child: _GlowCircle(
              color: Colors.white.withOpacity(0.10),
              size: 148,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(context.isMobile ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Pulse',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Diagram-first reporting for sessions, attendance rhythm, and classroom energy.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimary.withOpacity(0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh report data',
                      onPressed: _loadData,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacingSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ReportRange.values.map(_buildRangeChip).toList(),
                ),
                SizedBox(height: context.spacingMd),
                Text(
                  '${metrics.attendanceRate.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'attendance strength across ${metrics.totalStudents} students and ${metrics.sessionsInRange} sessions in ${metrics.range.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.88),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('MMM d').format(metrics.start)} - ${DateFormat('MMM d, y').format(metrics.end)}'
                  '${metrics.recentActivityCount > 0 ? ' · ${metrics.recentActivityCount} recent device events' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withOpacity(0.76),
                  ),
                ),
                SizedBox(height: context.spacingMd),
                _buildHeroSparkline(pulsePoints),
                SizedBox(height: context.spacingMd),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildHeroStat(
                      icon: Icons.task_alt_rounded,
                      label: 'On time',
                      value: '${metrics.onTimeRate.toStringAsFixed(0)}%',
                    ),
                    _buildHeroStat(
                      icon: Icons.event_available_rounded,
                      label: 'Active sessions',
                      value: '${metrics.activeSessions}',
                    ),
                    _buildHeroStat(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance logs',
                      value: '${metrics.totalAttendanceRecords}',
                    ),
                    _buildHeroStat(
                      icon:
                          metrics.activitySuccessRate != null
                              ? Icons.fingerprint_rounded
                              : Icons.hub_rounded,
                      label:
                          metrics.activitySuccessRate != null
                              ? 'Biometric success'
                              : 'Session links',
                      value:
                          metrics.activitySuccessRate != null
                              ? '${metrics.activitySuccessRate!.toStringAsFixed(0)}%'
                              : '${metrics.totalAssignments}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMixCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final total = metrics.totalAttendanceRecords;
    final sections =
        total == 0
            ? [
              PieChartSectionData(
                value: 1,
                color: scheme.surfaceContainerHigh,
                radius: 28,
                showTitle: false,
              ),
            ]
            : [
              PieChartSectionData(
                value: metrics.present.toDouble(),
                color: scheme.primary,
                radius: 28,
                showTitle: false,
              ),
              PieChartSectionData(
                value: metrics.late.toDouble(),
                color: scheme.secondary,
                radius: 28,
                showTitle: false,
              ),
              PieChartSectionData(
                value: metrics.absent.toDouble(),
                color: scheme.error,
                radius: 28,
                showTitle: false,
              ),
            ];

    return _buildReportCard(
      title: 'Attendance Mix',
      subtitle: 'Present, late, and absent balance for the selected window.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 560;
          final chart = SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 66,
                    sectionsSpace: 3,
                    startDegreeOffset: -90,
                    sections: sections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${metrics.attendanceRate.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'attendance',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = Column(
            children: [
              _buildLegendTile(
                label: 'Present',
                count: metrics.present,
                total: total,
                color: scheme.primary,
              ),
              SizedBox(height: context.spacingSm),
              _buildLegendTile(
                label: 'Late',
                count: metrics.late,
                total: total,
                color: scheme.secondary,
              ),
              SizedBox(height: context.spacingSm),
              _buildLegendTile(
                label: 'Absent',
                count: metrics.absent,
                total: total,
                color: scheme.error,
              ),
            ],
          );

          if (vertical) {
            return Column(
              children: [chart, SizedBox(height: context.spacingSm), legend],
            );
          }

          return Row(
            children: [
              Expanded(child: chart),
              SizedBox(width: context.spacingSm),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDailyMixCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final points =
        metrics.attendanceTimeline.length > 10
            ? metrics.attendanceTimeline.sublist(
              metrics.attendanceTimeline.length - 10,
            )
            : metrics.attendanceTimeline;
    final maxCount = points.fold<int>(
      0,
      (maxValue, point) => math.max(maxValue, point.total),
    );
    final busiestDay =
        points.isEmpty
            ? null
            : points.reduce((a, b) => a.total >= b.total ? a : b);

    return _buildReportCard(
      title: 'Daily Mix',
      subtitle:
          'Stacked attendance bars showing how each day splits into present, late, and absent.',
      footer:
          busiestDay == null || busiestDay.total == 0
              ? 'No daily attendance breakdown is available for this range yet.'
              : '${DateFormat('EEE, MMM d').format(busiestDay.date)} carried the heaviest load with ${busiestDay.total} attendance logs.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildLineLegend(color: scheme.primary, label: 'Present'),
              _buildLineLegend(color: scheme.secondary, label: 'Late'),
              _buildLineLegend(color: scheme.error, label: 'Absent'),
            ],
          ),
          SizedBox(height: context.spacingSm),
          if (maxCount == 0)
            _buildEmptyChartPlaceholder(
              icon: Icons.stacked_bar_chart_rounded,
              text: 'Attendance bars will appear once daily records exist.',
            )
          else
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  maxY: math.max(4.0, maxCount.toDouble() + 2),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: scheme.outlineVariant.withOpacity(0.35),
                          strokeWidth: 1,
                        ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('E').format(points[index].date),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups:
                      points.asMap().entries.map((entry) {
                        final point = entry.value;
                        final presentY = point.present.toDouble();
                        final lateY = (point.present + point.late).toDouble();
                        final totalY = point.total.toDouble();
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: totalY,
                              width: 18,
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                              rodStackItems:
                                  totalY == 0
                                      ? const []
                                      : [
                                        BarChartRodStackItem(
                                          0,
                                          presentY,
                                          scheme.primary,
                                        ),
                                        BarChartRodStackItem(
                                          presentY,
                                          lateY,
                                          scheme.secondary,
                                        ),
                                        BarChartRodStackItem(
                                          lateY,
                                          totalY,
                                          scheme.error,
                                        ),
                                      ],
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final linePoints = metrics.attendanceTimeline;
    final titleInterval = math.max(1, linePoints.length ~/ 6);
    final bestDay =
        linePoints.isEmpty
            ? null
            : linePoints.reduce((a, b) {
              return a.attendanceRate >= b.attendanceRate ? a : b;
            });

    return _buildReportCard(
      title: 'Attendance Signals',
      subtitle:
          'Participation and punctuality moving across the selected range.',
      footer:
          bestDay == null || bestDay.total == 0
              ? 'No attendance activity has been captured yet in this range.'
              : '${DateFormat('EEE, MMM d').format(bestDay.date)} peaked at ${bestDay.attendanceRate.toStringAsFixed(0)}% attendance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildLineLegend(color: scheme.primary, label: 'Attendance'),
              SizedBox(width: context.spacingSm),
              _buildLineLegend(color: scheme.secondary, label: 'On time'),
            ],
          ),
          SizedBox(height: context.spacingSm),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: scheme.outlineVariant.withOpacity(0.35),
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: titleInterval.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= linePoints.length) {
                          return const SizedBox.shrink();
                        }
                        if (index % titleInterval != 0 &&
                            index != linePoints.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final label = DateFormat(
                          linePoints.length > 21 ? 'MMM d' : 'E',
                        ).format(linePoints[index].date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                        linePoints.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.attendanceRate,
                          );
                        }).toList(),
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withOpacity(0.16),
                    ),
                  ),
                  LineChartBarData(
                    spots:
                        linePoints.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.onTimeRate,
                          );
                        }).toList(),
                    isCurved: true,
                    color: scheme.secondary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    dashArray: const [6, 3],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsFlowCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final visibleTimeline =
        metrics.sessionTimeline.length > 14
            ? metrics.sessionTimeline.sublist(
              metrics.sessionTimeline.length - 14,
            )
            : metrics.sessionTimeline;
    final maxCount = visibleTimeline.fold<int>(
      0,
      (maxValue, point) => math.max(maxValue, point.count),
    );
    final peakDay =
        visibleTimeline.isEmpty
            ? null
            : visibleTimeline.reduce((a, b) => a.count >= b.count ? a : b);

    return _buildReportCard(
      title: 'Session Flow',
      subtitle:
          visibleTimeline.length == metrics.sessionTimeline.length
              ? 'How many sessions ran each day in the selected window.'
              : 'Latest 14 days inside the selected reporting window.',
      footer:
          peakDay == null || peakDay.count == 0
              ? 'No sessions have been created in this range yet.'
              : '${DateFormat('EEE, MMM d').format(peakDay.date)} carried the heaviest load with ${peakDay.count} sessions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMiniMetric(
                label: 'Sessions',
                value: '${metrics.sessionsInRange}',
              ),
              _buildMiniMetric(
                label: 'Today',
                value: '${metrics.sessionsToday}',
              ),
              _buildMiniMetric(
                label: 'Avg / day',
                value: metrics.averageSessionsPerDay.toStringAsFixed(1),
              ),
            ],
          ),
          SizedBox(height: context.spacingSm),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: math.max(4.0, maxCount.toDouble() + 1),
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: scheme.outlineVariant.withOpacity(0.35),
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= visibleTimeline.length) {
                          return const SizedBox.shrink();
                        }
                        final point = visibleTimeline[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat(
                              visibleTimeline.length > 10 ? 'd' : 'E',
                            ).format(point.date),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups:
                    visibleTimeline.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.count.toDouble(),
                            width: 16,
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [scheme.primary, scheme.secondary],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRhythmCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final points = metrics.weekdayRhythm;
    final attendanceDays = points.where((point) => point.volume > 0).toList();
    final sessionDays = points.where((point) => point.sessions > 0).toList();
    final bestDay =
        attendanceDays.isEmpty
            ? null
            : attendanceDays.reduce(
              (a, b) => a.attendanceRate >= b.attendanceRate ? a : b,
            );
    final busiestDay =
        sessionDays.isEmpty
            ? null
            : sessionDays.reduce((a, b) => a.sessions >= b.sessions ? a : b);

    return _buildReportCard(
      title: 'Weekday Rhythm',
      subtitle:
          'Attendance quality by weekday, pairing overall attendance against on-time performance.',
      footer:
          bestDay == null && busiestDay == null
              ? 'Weekday comparisons will appear after a few attendance records are collected.'
              : bestDay == null
              ? 'Session rhythm is visible, but attendance logs are still empty for this range.'
              : '${bestDay.label} leads at ${bestDay.attendanceRate.toStringAsFixed(0)}% attendance'
                  '${busiestDay == null || busiestDay.sessions == 0 ? '.' : ', while ${busiestDay.label} carries the most sessions.'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildLineLegend(color: scheme.primary, label: 'Attendance'),
              _buildLineLegend(color: scheme.secondary, label: 'On time'),
            ],
          ),
          SizedBox(height: context.spacingSm),
          if (attendanceDays.isEmpty)
            _buildEmptyChartPlaceholder(
              icon: Icons.bar_chart_rounded,
              text: 'No weekday rhythm is visible yet.',
            )
          else
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: 100,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: scheme.outlineVariant.withOpacity(0.35),
                          strokeWidth: 1,
                        ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              points[index].label,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups:
                      points.asMap().entries.map((entry) {
                        final point = entry.value;
                        return BarChartGroupData(
                          x: entry.key,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: point.attendanceRate,
                              width: 10,
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            BarChartRodData(
                              toY: point.onTimeRate,
                              width: 10,
                              color: scheme.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSchoolShareCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final shares = metrics.schoolShares;
    final total = metrics.schoolSessionTotal;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.error,
    ];
    final leadingSchool =
        shares.isEmpty
            ? null
            : shares.reduce((a, b) => a.count >= b.count ? a : b);

    return _buildReportCard(
      title: 'School Share',
      subtitle:
          'A visual split of session activity across schools inside the selected range.',
      footer:
          leadingSchool == null || total == 0
              ? 'School distribution will appear after sessions are created.'
              : '${leadingSchool.label} owns ${((leadingSchool.count / total) * 100).toStringAsFixed(0)}% of the visible session volume.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 560;
          final chart = SizedBox(
            height: 240,
            child:
                total == 0
                    ? _buildEmptyChartPlaceholder(
                      icon: Icons.pie_chart_outline_rounded,
                      text: 'No school session share to show yet.',
                    )
                    : Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 62,
                            sectionsSpace: 3,
                            startDegreeOffset: -90,
                            sections:
                                shares.asMap().entries.map((entry) {
                                  final share = entry.value;
                                  final percent = (share.count / total) * 100;
                                  return PieChartSectionData(
                                    value: share.count.toDouble(),
                                    color: palette[entry.key % palette.length],
                                    radius: 30,
                                    showTitle: percent >= 12,
                                    title: '${percent.toStringAsFixed(0)}%',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${metrics.schoolCount}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              metrics.schoolCount == 1 ? 'school' : 'schools',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
          );

          final legend = Column(
            children:
                shares.asMap().entries.map((entry) {
                  final share = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == shares.length - 1 ? 0 : 12,
                    ),
                    child: _buildLegendTile(
                      label: share.label,
                      count: share.count,
                      total: total,
                      color: palette[entry.key % palette.length],
                    ),
                  );
                }).toList(),
          );

          if (vertical) {
            return Column(
              children: [chart, SizedBox(height: context.spacingSm), legend],
            );
          }

          return Row(
            children: [
              Expanded(child: chart),
              SizedBox(width: context.spacingSm),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionLoadCard(_ReportMetrics metrics) {
    final scheme = Theme.of(context).colorScheme;
    final maxCount = metrics.topSessionLoads.fold<int>(
      0,
      (maxValue, item) => math.max(maxValue, item.count),
    );

    return _buildReportCard(
      title: 'Session Load',
      subtitle:
          metrics.hasSessionMappings
              ? 'Where students are concentrated right now.'
              : 'Sessions exist, but students are not linked to session IDs yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMiniMetric(
                label: 'Assignments',
                value: '${metrics.totalAssignments}',
              ),
              _buildMiniMetric(
                label: 'Per student',
                value: metrics.averageAssignmentsPerStudent.toStringAsFixed(1),
              ),
              _buildMiniMetric(
                label: 'Schools',
                value: '${metrics.schoolCount}',
              ),
            ],
          ),
          SizedBox(height: context.spacingSm),
          if (metrics.topSessionLoads.isEmpty)
            _buildEmptyChartPlaceholder(
              icon: Icons.event_busy_outlined,
              text: 'No sessions available to map yet.',
            )
          else
            Column(
              children:
                  metrics.topSessionLoads.map((entry) {
                    final progress =
                        maxCount == 0 ? 0.0 : entry.count / maxCount;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _sessionLabel(entry.session),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${entry.count} student${entry.count == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: scheme.surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                metrics.hasSessionMappings
                                    ? scheme.primary
                                    : scheme.secondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _sessionMeta(entry.session),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          if (metrics.schoolFlows.isNotEmpty) ...[
            Divider(height: 28, color: scheme.outlineVariant.withOpacity(0.45)),
            Text(
              'School reach',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: context.spacingSm),
            ...metrics.schoolFlows.map((entry) {
              final topSchoolCount = metrics.schoolFlows.first.count;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.count}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value:
                            topSchoolCount == 0
                                ? 0.0
                                : entry.count / topSchoolCount,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(_ReportMetrics metrics) {
    final points =
        metrics.attendanceTimeline.length > 14
            ? metrics.attendanceTimeline.sublist(
              metrics.attendanceTimeline.length - 14,
            )
            : metrics.attendanceTimeline;

    return _buildReportCard(
      title: 'Weekly Heatmap',
      subtitle: 'A quick read on which days felt healthy, late, or quiet.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 640
                  ? 7
                  : constraints.maxWidth >= 420
                  ? 4
                  : 2;
          final gap = 10.0;
          final tileWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children:
                points.map((point) {
                  return SizedBox(
                    width: tileWidth,
                    child: _buildHeatTile(point),
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRecentSessionsCard(_ReportMetrics metrics) {
    return _buildReportCard(
      title: 'Recent Session Runway',
      subtitle:
          'The freshest session windows and whether they are still active.',
      child:
          metrics.recentSessions.isEmpty
              ? _buildEmptyChartPlaceholder(
                icon: Icons.event_note_outlined,
                text: 'Create a session to start building reports.',
              )
              : Column(
                children:
                    metrics.recentSessions.map((session) {
                      final scheme = Theme.of(context).colorScheme;
                      final isToday = _isSameDay(session.date, DateTime.now());
                      final statusColor =
                          session.isActive
                              ? scheme.primary
                              : scheme.onSurfaceVariant;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.outlineVariant.withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  session.isActive
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.pause_circle_filled_rounded,
                                  color: statusColor,
                                ),
                              ),
                              SizedBox(width: context.spacingSm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _sessionLabel(session),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            session.isActive
                                                ? 'ACTIVE'
                                                : 'ENDED',
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _sessionMeta(session),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildTag(
                                          isToday
                                              ? 'Today'
                                              : DateFormat(
                                                'EEE, MMM d',
                                              ).format(session.date),
                                        ),
                                        if (session.startTime != null ||
                                            session.endTime != null)
                                          _buildTag(
                                            [
                                              session.startTime ?? '--',
                                              session.endTime ?? '--',
                                            ].join(' - '),
                                          ),
                                        if (session.teacherName != null &&
                                            session.teacherName!
                                                .trim()
                                                .isNotEmpty)
                                          _buildTag(session.teacherName!),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String subtitle,
    required Widget child,
    String? footer,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          SizedBox(height: context.spacingSm),
          child,
          if (footer != null) ...[
            SizedBox(height: context.spacingSm),
            Text(
              footer,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroSparkline(List<_DailyAttendancePoint> points) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            points.map((point) {
              final height =
                  point.total == 0
                      ? 10.0
                      : 10 + ((point.attendanceRate / 100) * 42);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            point.total == 0 ? 0.20 : 0.72,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('E').format(point.date).substring(0, 1),
                        style: TextStyle(
                          color: scheme.onPrimary.withOpacity(0.80),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildRangeChip(_ReportRange range) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedRange == range;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (_selectedRange == range) return;
        setState(() => _selectedRange = range);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? Colors.white.withOpacity(0.22)
                  : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(selected ? 0.34 : 0.20),
          ),
        ),
        child: Text(
          range.label,
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onPrimary.withOpacity(0.82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendTile({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final percentage = total == 0 ? 0.0 : (count / total) * 100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildMiniMetric({required String label, required String value}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatTile(_DailyAttendancePoint point) {
    final scheme = Theme.of(context).colorScheme;
    final intensity = (point.attendanceRate / 100).clamp(0.0, 1.0).toDouble();
    final tileColor =
        Color.lerp(
          scheme.surfaceContainerLow,
          scheme.primary.withOpacity(0.75),
          intensity,
        ) ??
        scheme.surfaceContainerLow;
    final textColor = intensity > 0.55 ? scheme.onPrimary : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEE').format(point.date),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM d').format(point.date),
            style: TextStyle(color: textColor.withOpacity(0.82), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            '${point.attendanceRate.toStringAsFixed(0)}%',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            point.total == 0
                ? 'No logs'
                : '${point.total} record${point.total == 1 ? '' : 's'}',
            style: TextStyle(color: textColor.withOpacity(0.82), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSoftWarning(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.secondary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartPlaceholder({
    required IconData icon,
    required String text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _sessionLabel(Session session) {
    if (session.className != null && session.className!.trim().isNotEmpty) {
      return session.className!;
    }
    if (session.teacherName != null && session.teacherName!.trim().isNotEmpty) {
      return session.teacherName!;
    }
    if (session.id != null && session.id!.isNotEmpty) {
      final end = math.min(6, session.id!.length);
      return 'Session ${session.id!.substring(0, end).toUpperCase()}';
    }
    return 'Session';
  }

  String _sessionMeta(Session session) {
    final parts = <String>[
      DateFormat('EEE, MMM d').format(session.date),
      if (session.teacherName != null && session.teacherName!.trim().isNotEmpty)
        'Teacher: ${session.teacherName}',
      if (session.startTime != null || session.endTime != null)
        '${session.startTime ?? '--'} - ${session.endTime ?? '--'}',
    ];
    return parts.join(' · ');
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

enum _ReportRange {
  sevenDays(7, '7 Days'),
  thirtyDays(30, '30 Days'),
  ninetyDays(90, '90 Days');

  const _ReportRange(this.days, this.label);

  final int days;
  final String label;
}

class _ReportsSnapshot {
  const _ReportsSnapshot({
    required this.students,
    required this.sessions,
    required this.schools,
    required this.recentActivity,
  });

  final List<Student> students;
  final List<Session> sessions;
  final List<School> schools;
  final List<Map<String, dynamic>> recentActivity;
}

class _ReportMetrics {
  const _ReportMetrics({
    required this.range,
    required this.start,
    required this.end,
    required this.totalStudents,
    required this.present,
    required this.late,
    required this.absent,
    required this.totalAttendanceRecords,
    required this.attendanceRate,
    required this.onTimeRate,
    required this.attendanceTimeline,
    required this.sessionTimeline,
    required this.sessionsInRange,
    required this.sessionsToday,
    required this.activeSessions,
    required this.totalAssignments,
    required this.averageAssignmentsPerStudent,
    required this.averageSessionsPerDay,
    required this.weekdayRhythm,
    required this.schoolCount,
    required this.topSessionLoads,
    required this.schoolFlows,
    required this.schoolShares,
    required this.schoolSessionTotal,
    required this.recentSessions,
    required this.activitySuccessRate,
    required this.recentActivityCount,
    required this.hasSessionMappings,
  });

  final _ReportRange range;
  final DateTime start;
  final DateTime end;
  final int totalStudents;
  final int present;
  final int late;
  final int absent;
  final int totalAttendanceRecords;
  final double attendanceRate;
  final double onTimeRate;
  final List<_DailyAttendancePoint> attendanceTimeline;
  final List<_DailySessionPoint> sessionTimeline;
  final int sessionsInRange;
  final int sessionsToday;
  final int activeSessions;
  final int totalAssignments;
  final double averageAssignmentsPerStudent;
  final double averageSessionsPerDay;
  final List<_WeekdayRhythmPoint> weekdayRhythm;
  final int schoolCount;
  final List<_SessionLoadPoint> topSessionLoads;
  final List<_SchoolSessionPoint> schoolFlows;
  final List<_SchoolSessionPoint> schoolShares;
  final int schoolSessionTotal;
  final List<Session> recentSessions;
  final double? activitySuccessRate;
  final int recentActivityCount;
  final bool hasSessionMappings;
}

class _DailyAttendancePoint {
  _DailyAttendancePoint(this.date);

  final DateTime date;
  int present = 0;
  int late = 0;
  int absent = 0;

  int get total => present + late + absent;

  double get attendanceRate {
    if (total == 0) return 0.0;
    return ((present + late) / total) * 100;
  }

  double get onTimeRate {
    if (total == 0) return 0.0;
    return (present / total) * 100;
  }

  void add(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        present++;
        break;
      case AttendanceStatus.late:
        late++;
        break;
      case AttendanceStatus.absent:
        absent++;
        break;
      case AttendanceStatus.unknown:
        break;
    }
  }
}

class _DailySessionPoint {
  const _DailySessionPoint(this.date, this.count);

  final DateTime date;
  final int count;
}

class _WeekdayRhythmPoint {
  _WeekdayRhythmPoint(this.weekday, this.label);

  final int weekday;
  final String label;
  int present = 0;
  int late = 0;
  int absent = 0;
  int sessions = 0;

  int get volume => present + late + absent;

  double get attendanceRate {
    if (volume == 0) return 0.0;
    return ((present + late) / volume) * 100;
  }

  double get onTimeRate {
    if (volume == 0) return 0.0;
    return (present / volume) * 100;
  }

  void addAttendance(_DailyAttendancePoint point) {
    present += point.present;
    late += point.late;
    absent += point.absent;
  }
}

class _SessionLoadPoint {
  const _SessionLoadPoint({required this.session, required this.count});

  final Session session;
  final int count;
}

class _SchoolSessionPoint {
  const _SchoolSessionPoint({required this.label, required this.count});

  final String label;
  final int count;
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
