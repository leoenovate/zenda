import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/attendance.dart';
import '../../utils/responsive_builder.dart';
import 'package:intl/intl.dart';

class AttendanceDashboard extends StatefulWidget {
  final List<Student> students;

  const AttendanceDashboard({
    Key? key,
    required this.students,
  }) : super(key: key);

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  // Selected date (default to today)
  DateTime _selectedDate = DateTime.now();
  
  // Selected view mode
  ViewMode _viewMode = ViewMode.day;
  
  // Date range for range view
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  void _selectPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _selectNextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }
  
  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleViewMode() {
    setState(() {
      if (_viewMode == ViewMode.day) {
        _viewMode = ViewMode.range;
      } else {
        _viewMode = ViewMode.day;
      }
    });
  }
  
  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format selected date
    final String selectedDateFormatted = _viewMode == ViewMode.day
        ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)
        : '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}';
    
    // Collect attendance data for the selected date or range
    final Map<String, Map<String, int>> attendanceCounts = {
      'Morning': {'present': 0, 'absent': 0, 'late': 0, 'total': 0},
      'Afternoon': {'present': 0, 'absent': 0, 'late': 0, 'total': 0},
    };
    
    // Count students by period (for total)
    for (final student in widget.students) {
      attendanceCounts[student.period]!['total'] = 
          (attendanceCounts[student.period]!['total'] ?? 0) + 1;
    }
    
    // Count attendance by class period for selected date or range
    for (final student in widget.students) {
      final filteredAttendance = student.attendanceHistory.where((a) {
        if (_viewMode == ViewMode.day) {
          return a.date.day == _selectedDate.day && 
                 a.date.month == _selectedDate.month && 
                 a.date.year == _selectedDate.year;
        } else {
          return a.date.isAfter(_startDate.subtract(const Duration(days: 1))) && 
                 a.date.isBefore(_endDate.add(const Duration(days: 1)));
        }
      }).toList();
      
      if (filteredAttendance.isNotEmpty) {
        for (final attendance in filteredAttendance) {
          switch (attendance.status) {
            case AttendanceStatus.present:
              attendanceCounts[student.period]!['present'] = 
                  (attendanceCounts[student.period]!['present'] ?? 0) + 1;
              break;
            case AttendanceStatus.absent:
              attendanceCounts[student.period]!['absent'] = 
                  (attendanceCounts[student.period]!['absent'] ?? 0) + 1;
              break;
            case AttendanceStatus.late:
              attendanceCounts[student.period]!['late'] = 
                  (attendanceCounts[student.period]!['late'] ?? 0) + 1;
              break;
            case AttendanceStatus.unknown:
              // Skip unknown attendance records
              break;
          }
        }
      }
    }
    
    // Get total counts
    final int totalPresent = attendanceCounts['Morning']!['present']! + 
                            attendanceCounts['Afternoon']!['present']!;
    final int totalAbsent = attendanceCounts['Morning']!['absent']! + 
                           attendanceCounts['Afternoon']!['absent']!;
    final int totalLate = attendanceCounts['Morning']!['late']! + 
                         attendanceCounts['Afternoon']!['late']!;
    final int totalRecorded = totalPresent + totalAbsent + totalLate;
    
    // Total students enrolled
    final int totalStudents = attendanceCounts['Morning']!['total']! + 
                             attendanceCounts['Afternoon']!['total']!;
    
    // Missing attendance records for single day view
    final int missingRecords = _viewMode == ViewMode.day ? totalStudents - totalRecorded : 0;
    
    final bool isToday = _viewMode == ViewMode.day && 
        _selectedDate.day == DateTime.now().day && 
        _selectedDate.month == DateTime.now().month && 
        _selectedDate.year == DateTime.now().year;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header with controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with date mode toggle
                InkWell(
                  onTap: _toggleViewMode,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        Text(
                          _viewMode == ViewMode.day ? 'Daily Attendance' : 'Date Range',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: context.isMobile ? 16 : 18,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: context.isMobile ? 18 : 20,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Date navigation controls
                Row(
                  children: [
                    // View calendar button
                    IconButton(
                      icon: Icon(
                        _viewMode == ViewMode.day ? Icons.calendar_today : Icons.date_range,
                        size: context.isMobile ? 18 : 20,
                      ),
                      onPressed: _viewMode == ViewMode.day ? _selectDate : _selectDateRange,
                      tooltip: _viewMode == ViewMode.day ? 'Select date' : 'Select date range',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: context.isMobile ? 32 : 40,
                        minHeight: context.isMobile ? 32 : 40,
                      ),
                    ),
                    if (_viewMode == ViewMode.day) ...[
                      // Previous day button
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _selectPreviousDay,
                        tooltip: 'Previous day',
                        visualDensity: VisualDensity.compact,
                        iconSize: context.isMobile ? 20 : 24,
                        padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: context.isMobile ? 32 : 40,
                          minHeight: context.isMobile ? 32 : 40,
                        ),
                      ),
                      // Next day button (disabled for future dates)
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _selectedDate.isBefore(DateTime.now()) ? _selectNextDay : null,
                        tooltip: 'Next day',
                        visualDensity: VisualDensity.compact,
                        iconSize: context.isMobile ? 20 : 24,
                        padding: EdgeInsets.all(context.isMobile ? 4 : 8),
                        constraints: BoxConstraints(
                          minWidth: context.isMobile ? 32 : 40,
                          minHeight: context.isMobile ? 32 : 40,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            // Selected date display
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingXs),
              child: Row(
                children: [
                  Text(
                    selectedDateFormatted,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: context.isMobile ? 12 : 14,
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: context.isMobile ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: context.spacingSm),
            
            // Missing attendance indicator (for single day view only)
            if (_viewMode == ViewMode.day && missingRecords > 0)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: context.spacingSm),
                padding: EdgeInsets.all(context.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: context.isMobile ? 18 : 20,
                    ),
                    SizedBox(width: context.spacingSm),
                    Expanded(
                      child: Text(
                        'Missing attendance records for $missingRecords student${missingRecords == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: context.isMobile ? 12 : 14,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Attendance overview with responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine layout based on available width
                final bool useVerticalLayout = constraints.maxWidth < 600;
                
                // For very small screens
                if (constraints.maxWidth < 380) {
                  return Column(
                    children: [
                      _buildAttendanceIndicator(
                        'Present',
                        totalPresent,
                        totalStudents,
                        Colors.green,
                        context,
                      ),
                      SizedBox(height: context.spacingXs),
                      _buildAttendanceIndicator(
                        'Absent',
                        totalAbsent,
                        totalStudents,
                        Colors.red,
                        context,
                      ),
                      SizedBox(height: context.spacingXs),
                      _buildAttendanceIndicator(
                        'Late',
                        totalLate,
                        totalStudents,
                        Colors.orange,
                        context,
                      ),
                    ],
                  );
                }
                
                if (useVerticalLayout) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttendanceIndicator(
                              'Present',
                              totalPresent,
                              totalStudents,
                              Colors.green,
                              context,
                            ),
                          ),
                          SizedBox(width: context.spacingSm),
                          Expanded(
                            child: _buildAttendanceIndicator(
                              'Absent',
                              totalAbsent,
                              totalStudents,
                              Colors.red,
                              context,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.spacingSm),
                      _buildAttendanceIndicator(
                        'Late',
                        totalLate,
                        totalStudents,
                        Colors.orange,
                        context,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildAttendanceIndicator(
                          'Present',
                          totalPresent,
                          totalStudents,
                          Colors.green,
                          context,
                        ),
                      ),
                      SizedBox(width: context.spacingSm),
                      Expanded(
                        child: _buildAttendanceIndicator(
                          'Absent',
                          totalAbsent,
                          totalStudents,
                          Colors.red,
                          context,
                        ),
                      ),
                      SizedBox(width: context.spacingSm),
                      Expanded(
                        child: _buildAttendanceIndicator(
                          'Late',
                          totalLate,
                          totalStudents,
                          Colors.orange,
                          context,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            
            SizedBox(height: context.spacingMd),
            
            // Class breakdown with responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final bool useVerticalLayout = constraints.maxWidth < 500;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.isMobile ? 14 : 16,
                      ),
                    ),
                    SizedBox(height: context.spacingSm),
                    if (useVerticalLayout)
                      Column(
                        children: [
                          _buildClassBreakdown('Morning', attendanceCounts['Morning']!, context),
                          SizedBox(height: context.spacingSm),
                          _buildClassBreakdown('Afternoon', attendanceCounts['Afternoon']!, context),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildClassBreakdown('Morning', attendanceCounts['Morning']!, context),
                          ),
                          SizedBox(width: context.spacingMd),
                          Expanded(
                            child: _buildClassBreakdown('Afternoon', attendanceCounts['Afternoon']!, context),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceIndicator(
    String label, 
    int count, 
    int total,
    Color color,
    BuildContext context,
  ) {
    final double percentage = total > 0 ? count / total * 100 : 0;
    
    return Container(
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: context.isMobile ? 12 : 14,
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: context.isMobile ? 6 : 8,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            '$count students',
            style: TextStyle(
              fontSize: context.isMobile ? 10 : 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassBreakdown(String className, Map<String, int> counts, BuildContext context) {
    final total = counts['total']!;
    final present = counts['present']!;
    final absent = counts['absent']!;
    final late = counts['late']!;
    final recorded = present + absent + late;
    final missing = _viewMode == ViewMode.day ? total - recorded : 0;
    
    return Container(
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                className,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: context.isMobile ? 12 : 14,
                  color: className == 'Morning' 
                      ? Colors.amber.shade800 
                      : Colors.blue,
                ),
              ),
              Text(
                'Total: $total',
                style: TextStyle(
                  fontSize: context.isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacingXs),
          // Status indicators
          Row(
            children: [
              _buildStatusIndicator('Present', present, total, Colors.green, context),
              SizedBox(width: context.spacingXs),
              _buildStatusIndicator('Absent', absent, total, Colors.red, context),
              SizedBox(width: context.spacingXs),
              _buildStatusIndicator('Late', late, total, Colors.orange, context),
            ],
          ),
          // Missing indicators
          if (_viewMode == ViewMode.day && missing > 0) ...[
            SizedBox(height: context.spacingXs),
            Row(
              children: [
                Icon(
                  Icons.schedule, 
                  size: context.isMobile ? 10 : 12,
                  color: Colors.grey,
                ),
                SizedBox(width: 4),
                Text(
                  '$missing pending',
                  style: TextStyle(
                    fontSize: context.isMobile ? 10 : 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, int total, Color color, BuildContext context) {
    final percentage = total > 0 ? count / total * 100 : 0;
    
    return Expanded(
      child: Tooltip(
        message: '$label: $count students (${percentage.toStringAsFixed(1)}%)',
        child: Container(
          height: context.isMobile ? 24 : 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (percentage > 20)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.spacingXs),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.isMobile ? 10 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ViewMode {
  day,
  range,
}

// Data classes for charts
class PeriodData {
  final String period;
  final int count;
  final Color color;

  PeriodData(this.period, this.count, this.color);
}

class AttendanceData {
  final String status;
  final int count;
  final int total;
  final Color color;

  AttendanceData(this.status, this.count, this.total, this.color);
} 