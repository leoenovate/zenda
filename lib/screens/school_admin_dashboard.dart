import 'dart:async';

import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/message.dart';
import '../models/school.dart';
import '../models/session.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../models/user.dart' as app_user;
import '../models/worker.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../services/device_heartbeat_service.dart';
import '../services/firebase_service.dart';
import '../services/role_constants.dart';
import '../utils/responsive_builder.dart';
import '../widgets/navigation/mobile_bottom_nav_shell.dart';
import '../widgets/navigation/mobile_nav_sheet.dart';
import '../widgets/theme/theme_switcher.dart';
import '../widgets/zenda_logo.dart';
import 'admin/all_people_screen.dart';
import 'admin/device_enrollments_screen.dart';
import 'admin/sessions_screen.dart';
import 'admin/staff_time_off_screen.dart';
import 'chat_list_screen.dart';
import 'reports_screen.dart';

/// Sidebar-driven dashboard for `UserRole.schoolAdmin`. Provides Dashboard,
/// Devices, Sessions, People, Time off and Reports sections. All data fetches use the
/// school-scoped `FirebaseService` helpers, so the admin only ever sees
/// records for their own school.
class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

/// Top-level navigation indices used by the sidebar/drawer.
enum _Section {
  dashboard,
  devices,
  sessions,
  timeOff,
  people,
  reports,
  chat,
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  _Section _selected = _Section.dashboard;
  bool _sidebarCollapsed = false;
  bool _isLoading = true;

  School? _school;
  List<Student> _students = [];
  List<Teacher> _teachers = [];
  List<app_user.AppUser> _parents = [];
  List<Worker> _workers = [];
  List<app_user.AppUser> _users = [];
  List<Device> _devices = [];
  List<Session> _sessions = [];
  List<Map<String, dynamic>> _recentActivity = [];

  String _deviceSearchQuery = '';
  String _deviceStatusFilter = 'all';
  Device? _mobileEnrollmentDevice;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? get _schoolId => AuthService.currentSession?.schoolId;
  List<School> get _schoolsList => _school == null ? const [] : [_school!];

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getSchools(),
        FirebaseService.getStudents(),
        FirebaseService.getTeachers(),
        FirebaseService.getGuardians(),
        FirebaseService.getWorkers(),
        FirebaseService.getUsers(),
        FirebaseService.getDevices(),
        FirebaseService.getSessions(),
        FirebaseService.getRecentActivity(limit: 10),
      ]);

      final schools = results[0] as List<School>;
      final id = _schoolId;
      School? matched;
      if (id != null && id.isNotEmpty) {
        for (final s in schools) {
          if (s.id == id) {
            matched = s;
            break;
          }
        }
      }
      matched ??= schools.isNotEmpty ? schools.first : null;

      final users = results[5] as List<app_user.AppUser>;

      if (!mounted) return;
      setState(() {
        _school = matched;
        _students = results[1] as List<Student>;
        _teachers = results[2] as List<Teacher>;
        _parents = results[3] as List<app_user.AppUser>;
        _workers = results[4] as List<Worker>;
        _users = users;
        _devices = results[6] as List<Device>;
        _sessions = results[7] as List<Session>;
        _recentActivity = results[8] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await AuthService.signOut();
    } catch (_) {}
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _openChat() {
    if (context.isMobile) {
      setState(() {
        _selected = _Section.chat;
        _mobileEnrollmentDevice = null;
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatListScreen(
              students: _students,
              userType: MessageSender.school,
              userName: _school?.name ?? 'School Admin',
            ),
      ),
    );
  }

  void _openMobileEnrollments(Device device) {
    setState(() => _mobileEnrollmentDevice = device);
  }

  void _closeMobileEnrollments() {
    setState(() => _mobileEnrollmentDevice = null);
  }

  String get _mobileEnrollmentTitle {
    final device = _mobileEnrollmentDevice;
    if (device == null) return 'Devices';
    final name = device.deviceName?.trim();
    return (name != null && name.isNotEmpty) ? name : device.deviceId;
  }

  int get _totalPeopleCount {
    final adminLike =
        _users.where((u) => AuthRoles.isAdminLike(u.role)).length;
    return _students.length +
        _teachers.length +
        _workers.length +
        _parents.length +
        adminLike;
  }

  // ------------------------------------------------------------------
  // Layout
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _buildMobileLayout();
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(isTablet: context.isTablet),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  static const _mobileDestinations = [
    MobileNavDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    MobileNavDestination(
      icon: Icons.fingerprint_outlined,
      selectedIcon: Icons.fingerprint,
      label: 'Devices',
    ),
    MobileNavDestination(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: 'Sessions',
    ),
    MobileNavDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'People',
    ),
    MobileNavDestination(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  int get _mobileNavIndex {
    switch (_selected) {
      case _Section.dashboard:
        return 0;
      case _Section.devices:
        return 1;
      case _Section.sessions:
        return 2;
      case _Section.people:
        return 3;
      case _Section.timeOff:
      case _Section.reports:
      case _Section.chat:
        return 4;
    }
  }

  String get _mobileSectionTitle {
    switch (_selected) {
      case _Section.dashboard:
        return 'Dashboard';
      case _Section.devices:
        return 'Devices';
      case _Section.sessions:
        return 'Sessions';
      case _Section.people:
        return 'People';
      case _Section.timeOff:
        return 'Time off';
      case _Section.reports:
        return 'Reports';
      case _Section.chat:
        return 'Messages';
    }
  }

  void _onMobileNavTap(int index) {
    if (index == 4) {
      _showMobileMoreSheet();
      return;
    }
    final section = switch (index) {
      0 => _Section.dashboard,
      1 => _Section.devices,
      2 => _Section.sessions,
      3 => _Section.people,
      _ => _selected,
    };
    if (section == _selected) return;
    setState(() {
      _selected = section;
      _mobileEnrollmentDevice = null;
    });
  }

  void _showMobileMoreSheet() {
    showMobileNavSheet(
      context,
      title: 'More',
      items: [
        MobileNavSheetItem(
          icon: Icons.event_busy_outlined,
          label: 'Time off',
          selected: _selected == _Section.timeOff,
          onTap:
              () => setState(() {
                _selected = _Section.timeOff;
                _mobileEnrollmentDevice = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.insights_outlined,
          label: 'Reports',
          selected: _selected == _Section.reports,
          onTap:
              () => setState(() {
                _selected = _Section.reports;
                _mobileEnrollmentDevice = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.chat_bubble_outline,
          label: 'Messages',
          selected: _selected == _Section.chat,
          onTap:
              () => setState(() {
                _selected = _Section.chat;
                _mobileEnrollmentDevice = null;
              }),
        ),
      ],
      footerWidgets: [
        const Divider(),
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

  Widget _buildMobileLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    final showingEnrollments = _mobileEnrollmentDevice != null;
    return MobileBottomNavShell(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading:
            showingEnrollments
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _closeMobileEnrollments,
                )
                : null,
        title: Text(
          showingEnrollments ? _mobileEnrollmentTitle : _mobileSectionTitle,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        automaticallyImplyLeading: showingEnrollments,
      ),
      body: _buildMainContent(),
      destinations: _mobileDestinations,
      selectedIndex: _mobileNavIndex,
      onDestinationSelected: _onMobileNavTap,
    );
  }

  // ------------------------------------------------------------------
  // Sidebar (desktop / tablet)
  // ------------------------------------------------------------------

  Widget _buildSidebar({bool isTablet = false}) {
    final width =
        isTablet
            ? (_sidebarCollapsed ? 70.0 : 200.0)
            : (_sidebarCollapsed ? 70.0 : 240.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Divider(color: colorScheme.onPrimary.withOpacity(0.25), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', _Section.dashboard),
                _buildNavItem(Icons.fingerprint, 'Devices', _Section.devices),
                _buildNavItem(Icons.event_note, 'Sessions', _Section.sessions),
                _buildNavItem(Icons.event_busy, 'Time off', _Section.timeOff),
                _buildNavItem(
                  Icons.groups,
                  'People',
                  _Section.people,
                  badge: _totalPeopleCount,
                ),
                _buildNavItem(
                  Icons.insights_rounded,
                  'Reports',
                  _Section.reports,
                ),
              ],
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_sidebarCollapsed)
            Expanded(
              child: Row(
                children: [
                  const ZendaLogo(
                    size: 32,
                    tone: ZendaLogoTone.onBrand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _school?.name ?? 'School Admin',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(
              _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
              color: colorScheme.onPrimary.withOpacity(0.85),
              size: 20,
            ),
            onPressed: () {
              setState(() => _sidebarCollapsed = !_sidebarCollapsed);
            },
            tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = (AuthService.currentSession?.email ?? 'A')[0].toUpperCase();
    final email = AuthService.currentSession?.email ?? '';

    final avatar = CircleAvatar(
      backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
      radius: _sidebarCollapsed ? 14 : 15,
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: _sidebarCollapsed ? 12 : 13,
        ),
      ),
    );

    final logoutButton = IconButton(
      tooltip: 'Logout',
      onPressed: _logout,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        Icons.logout,
        color: colorScheme.onPrimary.withOpacity(0.85),
        size: 18,
      ),
    );

    final themeControls = const ThemeSwitcher(onAppBar: true, iconOnly: true);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarCollapsed ? 8 : 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.onPrimary.withOpacity(0.3)),
        ),
      ),
      child:
          _sidebarCollapsed
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(height: 6),
                  themeControls,
                  logoutButton,
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      avatar,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'School Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onPrimary.withOpacity(0.75),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [themeControls, logoutButton],
                  ),
                ],
              ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    _Section section, {
    int indent = 0,
    int? badge,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selected == section;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            isSelected
                ? colorScheme.onPrimary.withOpacity(0.2)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border:
            isSelected
                ? Border.all(color: colorScheme.onPrimary.withOpacity(0.3))
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selected = section),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10 + indent * 16.0, 8, 10, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimary.withOpacity(0.75),
                  size: 18,
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onPrimary.withOpacity(0.75),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) _buildBadge(badge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Main content router
  // ------------------------------------------------------------------

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final schools = _schoolsList;
    switch (_selected) {
      case _Section.dashboard:
        return _DashboardView(
          school: _school,
          students: _students,
          teachers: _teachers,
          parents: _parents,
          workers: _workers,
          devices: _devices,
          sessions: _sessions,
          recentActivity: _recentActivity,
          onChat: _openChat,
        );
      case _Section.devices:
        if (context.isMobile && _mobileEnrollmentDevice != null) {
          return DeviceEnrollmentsScreen(
            embedded: true,
            device: _mobileEnrollmentDevice!,
            school: _school,
            teachers: _teachers,
            workers: _workers,
          );
        }
        return _DevicesView(
          devices: _devices,
          school: _school,
          teachers: _teachers,
          workers: _workers,
          searchQuery: _deviceSearchQuery,
          statusFilter: _deviceStatusFilter,
          onSearchChanged: (v) => setState(() => _deviceSearchQuery = v),
          onStatusFilterChanged: (v) => setState(() => _deviceStatusFilter = v),
          onChanged: _loadData,
          onOpenEnrollmentsInShell:
              context.isMobile ? _openMobileEnrollments : null,
        );
      case _Section.sessions:
        return SessionsScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.timeOff:
        return StaffTimeOffScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.people:
        return AllPeopleScreen(
          schools: schools,
          onDataChanged: _loadData,
        );
      case _Section.reports:
        return const ReportsView();
      case _Section.chat:
        return ChatListScreen(
          embedded: true,
          students: _students,
          userType: MessageSender.school,
          userName: _school?.name ?? 'School Admin',
        );
    }
  }
}

// ----------------------------------------------------------------------
// Dashboard view
// ----------------------------------------------------------------------

class _DashboardView extends StatelessWidget {
  final School? school;
  final List<Student> students;
  final List<Teacher> teachers;
  final List<app_user.AppUser> parents;
  final List<Worker> workers;
  final List<Device> devices;
  final List<Session> sessions;
  final List<Map<String, dynamic>> recentActivity;
  final VoidCallback onChat;

  const _DashboardView({
    required this.school,
    required this.students,
    required this.teachers,
    required this.parents,
    required this.workers,
    required this.devices,
    required this.sessions,
    required this.recentActivity,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final padding =
        context.isMobile
            ? const EdgeInsets.all(16)
            : context.isTablet
            ? const EdgeInsets.all(20)
            : const EdgeInsets.all(24);
    final activeSessions = sessions.where((s) => s.isActive).length;
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        final minScrollContentHeight =
            viewportConstraints.maxHeight.isFinite
                ? viewportConstraints.maxHeight
                : 0.0;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minScrollContentHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWelcomeBanner(context, activeSessions, onChat),
                const SizedBox(height: 16),
                _buildSummaryGrid(
                  context,
                  activeSessions: activeSessions,
                  activeDevices: activeDevices,
                  offlineDevices: offlineDevices,
                ),
                SizedBox(height: context.isMobile ? 16 : 20),
                if (context.isMobile)
                  Column(
                    children: [
                      _DeviceStatusCard(
                        active: activeDevices,
                        offline: offlineDevices,
                        total: devices.length,
                      ),
                      const SizedBox(height: 16),
                      _RecentActivityCard(activity: recentActivity),
                    ],
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(5),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _DeviceStatusCard(
                              active: activeDevices,
                              offline: offlineDevices,
                              total: devices.length,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _RecentActivityCard(
                              activity: recentActivity,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(
    BuildContext context,
    int activeSessions,
    VoidCallback onChat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.isMobile ? 14 : 18,
        vertical: context.isMobile ? 14 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.school_rounded,
              color: colorScheme.onPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school?.name ?? 'Welcome back',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: context.isMobile ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeSessions active session${activeSessions == 1 ? '' : 's'} '
                  '· ${students.length} student${students.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onPrimary.withOpacity(0.9),
                    fontSize: context.isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: colorScheme.onPrimary,
                size: 18,
              ),
              tooltip: 'Open chat',
              onPressed: onChat,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(
    BuildContext context, {
    required int activeSessions,
    required int activeDevices,
    required int offlineDevices,
  }) {
    final cards = [
      _SummaryCardData(
        Icons.school,
        'Students',
        '${students.length}',
        Colors.blue,
      ),
      _SummaryCardData(
        Icons.person,
        'Teachers',
        '${teachers.length}',
        Colors.purple,
      ),
      _SummaryCardData(
        Icons.family_restroom,
        'Parents',
        '${parents.length}',
        Colors.teal,
      ),
      _SummaryCardData(
        Icons.engineering,
        'Workers',
        '${workers.length}',
        Colors.brown,
      ),
      _SummaryCardData(
        Icons.fingerprint,
        'Devices',
        '${devices.length}',
        Colors.orange,
      ),
      _SummaryCardData(
        Icons.event_note,
        'Active Sessions',
        '$activeSessions',
        Colors.green,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double aspectRatio;
        if (context.isMobile) {
          crossAxisCount = 2;
          aspectRatio = 1.25;
        } else if (context.isTablet) {
          crossAxisCount = 3;
          aspectRatio = 1.25;
        } else {
          final w = constraints.maxWidth;
          // Fewer, wider tiles on typical laptop widths so stats don’t look
          // like tiny islands in a wide gutter.
          if (w < 880) {
            crossAxisCount = 3;
            aspectRatio = 1.42;
          } else if (w < 1180) {
            crossAxisCount = 4;
            aspectRatio = 1.38;
          } else {
            crossAxisCount = 6;
            aspectRatio = 1.38;
          }
        }
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [for (final c in cards) _SummaryCard(data: c)],
        );
      },
    );
  }
}

class _SummaryCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _SummaryCardData(this.icon, this.label, this.value, this.accent);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding =
        context.isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(14);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.accent, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: context.isMobile ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final int active;
  final int offline;
  final int total;
  const _DeviceStatusCard({
    required this.active,
    required this.offline,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maintenance = (total - active - offline).clamp(0, total);
    final pct = total == 0 ? 0 : (active / total * 100);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight =
            constraints.maxHeight < double.infinity &&
            constraints.maxHeight > 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize:
                hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Device Status',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          color: colorScheme.outline,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No devices yet',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 10,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${pct.toStringAsFixed(0)}% online',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _statRow(context, Colors.green, 'Active', active),
              _statRow(context, Colors.red, 'Offline', offline),
              _statRow(context, Colors.orange, 'Maintenance', maintenance),
              if (hasBoundedHeight) const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget _statRow(BuildContext context, Color color, String label, int value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  const _RecentActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      color: colorScheme.outline,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < activity.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: colorScheme.outlineVariant),
                  _buildActivityRow(context, activity[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, Map<String, dynamic> a) {
    final colorScheme = Theme.of(context).colorScheme;
    final success = (a['success'] ?? false) == true;
    final color = success ? Colors.green : Colors.red;
    final name = (a['studentName'] ?? a['studentId'] ?? '—').toString();
    final type = (a['type'] ?? 'authentication').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              success ? 'OK' : 'FAIL',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Devices view
// ----------------------------------------------------------------------

class _DevicesView extends StatefulWidget {
  final List<Device> devices;
  final School? school;
  final List<Teacher> teachers;
  final List<Worker> workers;
  final String searchQuery;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onChanged;
  final ValueChanged<Device>? onOpenEnrollmentsInShell;

  const _DevicesView({
    required this.devices,
    required this.school,
    required this.teachers,
    required this.workers,
    required this.searchQuery,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onChanged,
    this.onOpenEnrollmentsInShell,
  });

  @override
  State<_DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<_DevicesView> {
  Timer? _heartbeatTimer;
  Timer? _heartbeatUiTimer;
  Map<String, DeviceHeartbeat> _heartbeats = const {};

  @override
  void initState() {
    super.initState();
    _refreshHeartbeats();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshHeartbeats(),
    );
    _heartbeatUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatUiTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshHeartbeats() async {
    try {
      final heartbeats = await DeviceHeartbeatService.fetchHeartbeats(
        widget.devices,
      );
      if (!mounted) return;
      setState(() {
        _heartbeats = heartbeats;
      });
    } catch (e) {
      if (!mounted) return;
      // Rebuild so existing heartbeat timestamps can age out to offline.
      setState(() {});
    }
  }

  DeviceHeartbeat? _heartbeatFor(Device device) {
    return _heartbeats[device.deviceId];
  }

  String _effectiveStatus(Device device) {
    if (device.status == 'maintenance') return 'maintenance';

    final heartbeat = _heartbeatFor(device);
    if (heartbeat == null || !heartbeat.hasSignal) return 'offline';

    return heartbeat.isOnlineNow() ? 'active' : 'offline';
  }

  Duration? _timeUntilOffline(DeviceHeartbeat? heartbeat) {
    final lastSeen = heartbeat?.lastSeen;
    if (lastSeen == null) return null;
    final age = DateTime.now().difference(lastSeen.toLocal());
    final remaining = DeviceHeartbeatService.freshnessWindow - age;
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  String _formatDuration(Duration value) {
    final seconds = value.inSeconds;
    if (seconds <= 0) return 'now';
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes == 0) return '${remainder}s';
    return '${minutes}m ${remainder.toString().padLeft(2, '0')}s';
  }

  String _formatRelativeTime(DateTime? value) {
    if (value == null) return 'never';
    final age = DateTime.now().difference(value.toLocal());
    if (age.isNegative || age.inSeconds < 10) return 'just now';
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final padding =
        context.isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(24);

    final filtered =
        widget.devices.where((d) {
          final status = _effectiveStatus(d);
          if (widget.statusFilter != 'all' && status != widget.statusFilter) {
            return false;
          }
          if (widget.searchQuery.isNotEmpty) {
            final q = widget.searchQuery.toLowerCase();
            final name = (d.deviceName ?? '').toLowerCase();
            final id = d.deviceId.toLowerCase();
            final loc = (d.location ?? '').toLowerCase();
            if (!name.contains(q) && !id.contains(q) && !loc.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

    final active =
        widget.devices.where((d) => _effectiveStatus(d) == 'active').length;
    final offline =
        widget.devices.where((d) => _effectiveStatus(d) == 'offline').length;
    final maintenance =
        widget.devices
            .where((d) => _effectiveStatus(d) == 'maintenance')
            .length;

    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        final minScrollContentHeight =
            viewportConstraints.maxHeight.isFinite
                ? viewportConstraints.maxHeight
                : 0.0;
        final isMobile = viewportConstraints.maxWidth < ScreenSize.mobile;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minScrollContentHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(colorScheme, isMobile),
                const SizedBox(height: 20),
                _buildFilters(colorScheme, isMobile),
                const SizedBox(height: 20),
                _buildStatsGrid(
                  colorScheme: colorScheme,
                  isMobile: isMobile,
                  active: active,
                  offline: offline,
                  maintenance: maintenance,
                ),
                const SizedBox(height: 20),
                if (filtered.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 48,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No devices match your filters',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                      itemBuilder: (_, i) => _buildRow(filtered[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isMobile) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devices',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fingerprint scanners and attendance terminals for ${widget.school?.name ?? 'your school'}',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );

    final addButton = ElevatedButton.icon(
      onPressed: () => _showFormDialog(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add Device'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [titleBlock, const SizedBox(height: 14), addButton],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 16),
        addButton,
      ],
    );
  }

  Widget _buildFilters(ColorScheme colorScheme, bool isMobile) {
    final search = TextField(
      decoration: const InputDecoration(
        hintText: 'Search by name, ID, or location...',
        prefixIcon: Icon(Icons.search),
      ),
      onChanged: widget.onSearchChanged,
    );
    final dropdown = _statusDropdown(colorScheme, isExpanded: isMobile);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [search, const SizedBox(height: 12), dropdown],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: dropdown,
        ),
      ],
    );
  }

  Widget _statusDropdown(ColorScheme colorScheme, {required bool isExpanded}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: widget.statusFilter,
        isExpanded: isExpanded,
        underline: const SizedBox.shrink(),
        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All statuses')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'offline', child: Text('Offline')),
          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
        ],
        onChanged: (v) => widget.onStatusFilterChanged(v ?? 'all'),
      ),
    );
  }

  Widget _buildStatsGrid({
    required ColorScheme colorScheme,
    required bool isMobile,
    required int active,
    required int offline,
    required int maintenance,
  }) {
    final cards = [
      _statCard(Colors.green, Icons.check_circle, '$active', 'Active'),
      _statCard(Colors.red, Icons.error_outline, '$offline', 'Offline'),
      _statCard(
        Colors.orange,
        Icons.build_circle,
        '$maintenance',
        'Maintenance',
      ),
      _statCard(
        colorScheme.primary,
        Icons.devices_other,
        '${widget.devices.length}',
        'Total',
      ),
    ];

    if (!isMobile) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - 12) / 2).clamp(0.0, 220.0);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  Widget _statCard(Color color, IconData icon, String value, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Device device) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;
    final heartbeat = _heartbeatFor(device);
    final status = _effectiveStatus(device);
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        break;
      case 'maintenance':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.red;
    }
    final hasName = (device.deviceName ?? '').trim().isNotEmpty;
    final subtitleParts = <String>[
      device.deviceId,
      if (device.location != null && device.location!.trim().isNotEmpty)
        device.location!,
      if (heartbeat?.lastSeen != null)
        'Last heartbeat ${_formatRelativeTime(heartbeat!.lastSeen)}',
      if (heartbeat?.lastSeen != null)
        status == 'active'
            ? 'Offline in ${_formatDuration(_timeUntilOffline(heartbeat)!)}'
            : 'Heartbeat expired',
      if ((heartbeat?.ip ?? '').isNotEmpty && heartbeat!.ip != 'Unknown')
        'IP ${heartbeat.ip}',
      if (heartbeat?.rssi != null) 'RSSI ${heartbeat!.rssi} dBm',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child:
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _deviceIcon(statusColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _deviceText(
                          colorScheme,
                          title: hasName ? device.deviceName! : device.deviceId,
                          subtitle: subtitleParts.join(' · '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusPill(statusColor, status),
                      TextButton.icon(
                        onPressed: () => _openEnrollments(device),
                        icon: const Icon(Icons.fingerprint, size: 16),
                        label: const Text('Enrollments'),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit device',
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _showFormDialog(device: device),
                      ),
                      IconButton(
                        tooltip: 'Delete device',
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () => _confirmDelete(device),
                      ),
                    ],
                  ),
                ],
              )
              : Row(
                children: [
                  _deviceIcon(statusColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _deviceText(
                      colorScheme,
                      title: hasName ? device.deviceName! : device.deviceId,
                      subtitle: subtitleParts.join(' · '),
                    ),
                  ),
                  _statusPill(statusColor, status),
                  TextButton.icon(
                    onPressed: () => _openEnrollments(device),
                    icon: const Icon(Icons.fingerprint, size: 16),
                    label: const Text('Manage enrollments'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _showFormDialog(device: device),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => _confirmDelete(device),
                  ),
                ],
              ),
    );
  }

  Widget _deviceIcon(Color statusColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.fingerprint, color: statusColor, size: 20),
    );
  }

  Widget _deviceText(
    ColorScheme colorScheme, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _statusPill(Color statusColor, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _openEnrollments(Device device) {
    if (widget.onOpenEnrollmentsInShell != null) {
      widget.onOpenEnrollmentsInShell!(device);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DeviceEnrollmentsScreen(
              device: device,
              school: widget.school,
              teachers: widget.teachers,
              workers: widget.workers,
            ),
      ),
    );
  }

  void _showFormDialog({Device? device}) {
    final deviceIdController = TextEditingController(
      text: device?.deviceId ?? '',
    );
    final nameController = TextEditingController(
      text: device?.deviceName ?? '',
    );
    final locationController = TextEditingController(
      text: device?.location ?? '',
    );
    String deviceType = device?.deviceType ?? 'fingerprint_scanner';
    String status = device?.status ?? 'offline';
    bool isSaving = false;
    final isEdit = device != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              InputDecoration field(String label, {bool required = false}) =>
                  InputDecoration(labelText: required ? '$label *' : label);

              return AlertDialog(
                title: Text(isEdit ? 'Edit Device' : 'Add Device'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: deviceIdController,
                          enabled: !isEdit,
                          decoration: field('Device ID', required: true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: field('Device Name'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: deviceType,
                          decoration: field('Type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'fingerprint_scanner',
                              child: Text('Fingerprint Scanner'),
                            ),
                            DropdownMenuItem(
                              value: 'attendance_terminal',
                              child: Text('Attendance Terminal'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged:
                              (v) => setStateDialog(
                                () => deviceType = v ?? 'fingerprint_scanner',
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: locationController,
                          decoration: field('Location'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: field('Status'),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'offline',
                              child: Text('Offline'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                          ],
                          onChanged:
                              (v) =>
                                  setStateDialog(() => status = v ?? 'offline'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              if (deviceIdController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device ID is required'),
                                  ),
                                );
                                return;
                              }
                              setStateDialog(() => isSaving = true);
                              try {
                                final updated = Device(
                                  id: device?.id,
                                  deviceId: deviceIdController.text.trim(),
                                  deviceName:
                                      nameController.text.trim().isEmpty
                                          ? null
                                          : nameController.text.trim(),
                                  deviceType: deviceType,
                                  schoolId:
                                      widget.school?.id ?? device?.schoolId,
                                  isActive: status == 'active',
                                  lastSeen: device?.lastSeen,
                                  isOnline: device?.isOnline,
                                  ip: device?.ip,
                                  rssi: device?.rssi,
                                  location:
                                      locationController.text.trim().isEmpty
                                          ? null
                                          : locationController.text.trim(),
                                  status: status,
                                );
                                if (isEdit) {
                                  await FirebaseService.updateDevice(updated);
                                } else {
                                  await FirebaseService.addDevice(updated);
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Device updated'
                                          : 'Device added',
                                    ),
                                  ),
                                );
                                widget.onChanged();
                              } catch (e) {
                                setStateDialog(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                    child: Text(
                      isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Add'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _confirmDelete(Device device) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Delete Device'),
            content: Text(
              'Delete device "${device.deviceName ?? device.deviceId}"? '
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.deleteDevice(device.id!);
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device deleted')),
                    );
                    widget.onChanged();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
