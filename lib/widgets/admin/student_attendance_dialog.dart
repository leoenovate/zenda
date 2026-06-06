import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance.dart';
import '../../models/student.dart';

/// Shows the per-student attendance history dialog used by admin screens.
Future<void> showStudentAttendanceDialog(
  BuildContext context,
  Student student,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final attendance = student.attendanceHistory;
  final present =
      attendance.where((a) => a.status == AttendanceStatus.present).length;
  final late =
      attendance.where((a) => a.status == AttendanceStatus.late).length;
  final absent =
      attendance.where((a) => a.status == AttendanceStatus.absent).length;
  final total = attendance.length;

  return showDialog(
    context: context,
    builder: (dialogCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${student.name} – Attendance',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No attendance records yet',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn(
                      context,
                      present,
                      total,
                      'Present',
                      Colors.green,
                    ),
                    _statColumn(
                      context,
                      late,
                      total,
                      'Late',
                      Colors.orange,
                    ),
                    _statColumn(
                      context,
                      absent,
                      total,
                      'Absent',
                      Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: ListView.separated(
                    itemCount: attendance.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    itemBuilder: (_, i) {
                      final a = attendance[i];
                      final color = switch (a.status) {
                        AttendanceStatus.present => Colors.green,
                        AttendanceStatus.late => Colors.orange,
                        AttendanceStatus.absent => Colors.red,
                        _ => colorScheme.outline,
                      };
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          switch (a.status) {
                            AttendanceStatus.present => Icons.check_circle,
                            AttendanceStatus.late => Icons.access_time,
                            AttendanceStatus.absent => Icons.cancel,
                            _ => Icons.help_outline,
                          },
                          color: color,
                        ),
                        title: Text(
                          DateFormat('yyyy-MM-dd').format(a.date),
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          switch (a.status) {
                            AttendanceStatus.present => 'Present',
                            AttendanceStatus.late => 'Late',
                            AttendanceStatus.absent => 'Absent',
                            _ => 'Unknown',
                          },
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _statColumn(
  BuildContext context,
  int value,
  int total,
  String label,
  Color color,
) {
  final pct = total == 0 ? 0 : (value / total * 100);
  final colorScheme = Theme.of(context).colorScheme;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${pct.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        '$label · $value',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ],
  );
}
