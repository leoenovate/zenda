import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/message.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import '../utils/responsive_builder.dart';
import '../widgets/navigation/mobile_bottom_nav_shell.dart';
import '../widgets/navigation/mobile_nav_sheet.dart';
import '../widgets/theme/theme_switcher.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String phoneNumber;
  final List<Student> students;

  const ParentDashboardScreen({
    super.key,
    required this.phoneNumber,
    required this.students,
  });

  @override
  State<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  Student? _selectedStudent;
  bool _isLoading = true;
  int _parentTabIndex = 0;

  static const _mobileDestinations = [
    MobileNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    MobileNavDestination(
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
      label: 'Attendance',
    ),
    MobileNavDestination(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: 'Chat',
    ),
    MobileNavDestination(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentsData();
  }

  Future<void> _loadStudentsData() async {
    try {
      final List<Student> updatedStudents =
          await FirebaseService.getStudentsByParentPhone(
        widget.phoneNumber,
      );

      setState(() {
        if (updatedStudents.isNotEmpty) {
          _selectedStudent = updatedStudents.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Student get _activeStudent => _selectedStudent ?? widget.students.first;

  String get _parentUserName =>
      _activeStudent.fatherName ??
      _activeStudent.motherName ??
      'Parent';

  void _onParentNavTap(int index) {
    if (index == 3) {
      _showParentMoreSheet();
      return;
    }
    if (index == _parentTabIndex) return;
    setState(() => _parentTabIndex = index);
  }

  void _showParentMoreSheet() {
    showMobileNavSheet(
      context,
      title: 'More',
      items: const [],
      footerWidgets: [
        const ListTile(
          title: Text('Theme'),
          leading: Icon(Icons.palette_outlined),
          trailing: ThemeSwitcher(onAppBar: false),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: _logout,
        ),
      ],
    );
  }

  String get _mobileSectionTitle {
    switch (_parentTabIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Attendance';
      case 2:
        return 'Messages';
      default:
        return 'Parent Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.students.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Parent Portal'),
          actions: const [ThemeSwitcher()],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline,
                  size: 64, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No students found',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _logout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      );
    }

    if (context.isMobile) {
      return MobileBottomNavShell(
        appBar: AppBar(
          title: Text(_mobileSectionTitle),
          automaticallyImplyLeading: false,
        ),
        body: _buildMobileTabBody(context),
        destinations: _mobileDestinations,
        selectedIndex: _parentTabIndex,
        onDestinationSelected: _onParentNavTap,
      );
    }

    return _buildDesktopLayout(context);
  }

  Widget _buildMobileTabBody(BuildContext context) {
    switch (_parentTabIndex) {
      case 1:
        return _buildAttendanceTab(context);
      case 2:
        return ChatListScreen(
          embedded: true,
          students: widget.students,
          userType: MessageSender.parent,
          userName: _parentUserName,
        );
      case 0:
      default:
        return _buildHomeTab(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final student = _activeStudent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Portal'),
        actions: [
          const ThemeSwitcher(),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              if (student.id != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      student: student,
                      userType: MessageSender.parent,
                      userName: _parentUserName,
                    ),
                  ),
                );
              }
            },
            tooltip: 'Chat with School',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.students.length > 1) _buildChildSelector(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(context.spacingMd),
                children: [
                  _buildProfileCard(context, student),
                  SizedBox(height: context.spacingMd),
                  ..._buildAttendanceSection(context, student),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.spacingMd),
      color: colorScheme.surfaceContainer,
      child: DropdownButtonFormField<Student>(
        value: _activeStudent,
        decoration: const InputDecoration(
          labelText: 'Select Child',
        ),
        items: widget.students.map((s) {
          return DropdownMenuItem<Student>(
            value: s,
            child: Text(s.name),
          );
        }).toList(),
        onChanged: (Student? newStudent) {
          setState(() {
            _selectedStudent = newStudent;
          });
        },
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    final student = _activeStudent;
    return SafeArea(
      child: Column(
        children: [
          if (widget.students.length > 1) _buildChildSelector(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(context.spacingMd),
              children: [
                _buildProfileCard(context, student),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(BuildContext context) {
    final student = _activeStudent;
    return SafeArea(
      child: Column(
        children: [
          if (widget.students.length > 1) _buildChildSelector(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(context.spacingMd),
              children: _buildAttendanceSection(context, student),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 30,
              child: Text(
                student.name[0].toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: context.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.spacingXs),
                  Row(
                    children: [
                      Icon(
                        Icons.class_,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: context.spacingXs),
                      Text(
                        student.sessionIds.isEmpty
                            ? 'No session'
                            : '${student.sessionIds.length} session${student.sessionIds.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      if (student.registrationNumber != null) ...[
                        SizedBox(width: context.spacingMd),
                        Icon(
                          Icons.badge,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: context.spacingXs),
                        Text(
                          student.registrationNumber!,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAttendanceSection(BuildContext context, Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    final attendanceData =
        student.attendanceHistory.isEmpty
            ? <Attendance>[]
            : student.attendanceHistory;

    final present =
        attendanceData
            .where((a) => a.status == AttendanceStatus.present)
            .length;
    final late =
        attendanceData.where((a) => a.status == AttendanceStatus.late).length;
    final absent =
        attendanceData.where((a) => a.status == AttendanceStatus.absent).length;
    final total = attendanceData.length;
    final presentPercentage = total > 0 ? (present / total * 100) : 0.0;

    return [
      Card(
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Statistics',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Present',
                      present,
                      total,
                      Colors.green,
                      context,
                    ),
                  ),
                  SizedBox(width: context.spacingSm),
                  Expanded(
                    child: _buildStatCard(
                      'Late',
                      late,
                      total,
                      Colors.orange,
                      context,
                    ),
                  ),
                  SizedBox(width: context.spacingSm),
                  Expanded(
                    child: _buildStatCard(
                      'Absent',
                      absent,
                      total,
                      Colors.red,
                      context,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacingMd),
              Container(
                padding: EdgeInsets.all(context.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Attendance Rate',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                    Text(
                      '${presentPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: context.spacingMd),
      Card(
        child: Padding(
          padding: EdgeInsets.all(context.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Attendance',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.spacingMd),
              attendanceData.isEmpty
                  ? Padding(
                    padding: EdgeInsets.all(context.spacingMd),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: context.spacingSm),
                          Text(
                            'No attendance records yet',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount:
                        attendanceData.length > 7 ? 7 : attendanceData.length,
                    itemBuilder: (context, index) {
                      final attendance = attendanceData[index];
                      return _buildAttendanceItem(attendance, context);
                    },
                  ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildStatCard(
    String label,
    int count,
    int total,
    Color color,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Container(
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          SizedBox(height: context.spacingXs),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(Attendance attendance, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (attendance.status) {
      case AttendanceStatus.present:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Present';
        break;
      case AttendanceStatus.late:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Late';
        break;
      case AttendanceStatus.absent:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Absent';
        break;
      case AttendanceStatus.excused:
        statusColor = Colors.blue;
        statusIcon = Icons.event_busy;
        statusText = 'Excused';
        break;
      default:
        statusColor = colorScheme.onSurfaceVariant;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(bottom: context.spacingSm),
      padding: EdgeInsets.all(context.spacingSm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          SizedBox(width: context.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(attendance.date),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.spacingXs),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
