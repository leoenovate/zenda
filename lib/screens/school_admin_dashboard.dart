import 'dart:async';

import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/message.dart';
import '../models/parent.dart' as app_parent;
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
import '../utils/responsive_builder.dart';
import '../widgets/theme/theme_switcher.dart';
import 'admin/admins_screen.dart';
import 'admin/device_enrollments_screen.dart';
import 'admin/parents_screen.dart';
import 'admin/sessions_screen.dart';
import 'admin/students_screen.dart';
import 'admin/teachers_screen.dart';
import 'admin/workers_screen.dart';
import 'chat_list_screen.dart';
import 'reports_screen.dart';

/// Sidebar-driven dashboard for `UserRole.schoolAdmin`. Provides Dashboard,
/// Devices, Sessions, Roles (expandable, dynamically populated from the
/// school's data) and Reports sections. All data fetches use the
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
  reports,
  rolesAdmins,
  rolesTeachers,
  rolesParents,
  rolesWorkers,
  rolesStudents,
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  _Section _selected = _Section.dashboard;
  bool _sidebarCollapsed = false;
  bool _rolesExpanded = true;
  bool _isLoading = true;

  School? _school;
  List<Student> _students = [];
  List<Teacher> _teachers = [];
  List<app_parent.Parent> _parents = [];
  List<Worker> _workers = [];
  List<app_user.AppUser> _admins = [];
  List<Device> _devices = [];
  List<Session> _sessions = [];
  List<Map<String, dynamic>> _recentActivity = [];

  String _deviceSearchQuery = '';
  String _deviceStatusFilter = 'all';

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
        FirebaseService.getParents(),
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
        _parents = results[3] as List<app_parent.Parent>;
        _workers = results[4] as List<Worker>;
        _admins =
            users
                .where(
                  (u) =>
                      (u.role ?? '').toLowerCase() == 'admin' ||
                      (u.role ?? '').toLowerCase() == 'school_admin',
                )
                .toList();
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

  Widget _buildMobileLayout() {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: _buildMobileDrawer(),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          _school?.name ?? 'School Admin',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          const ThemeSwitcher(onAppBar: false),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChat,
            tooltip: 'Chat',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildMainContent(),
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
                _buildRolesNavItem(),
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
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorScheme.onPrimary.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Z',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.onPrimary.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
            radius: 16,
            child: Text(
              (AuthService.currentSession?.email ?? 'A')[0].toUpperCase(),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (!_sidebarCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Admin',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AuthService.currentSession?.email ?? '',
                    style: TextStyle(
                      color: colorScheme.onPrimary.withOpacity(0.75),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const ThemeSwitcher(),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: colorScheme.onPrimary.withOpacity(0.85),
                size: 18,
              ),
              onPressed: _logout,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Logout',
            ),
          ],
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

  /// Children populated dynamically from the loaded dataset; categories with
  /// zero records are hidden.
  List<_RoleEntry> _roleEntries() {
    return [
      _RoleEntry(
        Icons.admin_panel_settings,
        'Admins',
        _admins.length,
        _Section.rolesAdmins,
      ),
      _RoleEntry(
        Icons.person,
        'Teachers',
        _teachers.length,
        _Section.rolesTeachers,
      ),
      _RoleEntry(
        Icons.family_restroom,
        'Parents',
        _parents.length,
        _Section.rolesParents,
      ),
      _RoleEntry(
        Icons.engineering,
        'Workers',
        _workers.length,
        _Section.rolesWorkers,
      ),
      _RoleEntry(
        Icons.school,
        'Students',
        _students.length,
        _Section.rolesStudents,
      ),
    ];
  }

  Widget _buildRolesNavItem() {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = _roleEntries();
    final visible = entries.where((e) => e.count > 0).toList();
    final isAnyChildSelected = entries.any((e) => e.section == _selected);

    if (_sidebarCollapsed) {
      return PopupMenuButton<_Section>(
        tooltip: 'Roles',
        position: PopupMenuPosition.over,
        offset: const Offset(70, 0),
        onSelected: (s) => setState(() => _selected = s),
        itemBuilder:
            (_) => [
              for (final e in entries)
                PopupMenuItem<_Section>(
                  value: e.section,
                  child: Row(
                    children: [
                      Icon(
                        e.icon,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(e.label),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.count}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color:
                isAnyChildSelected
                    ? colorScheme.onPrimary.withOpacity(0.2)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                isAnyChildSelected
                    ? Border.all(color: colorScheme.onPrimary.withOpacity(0.3))
                    : null,
          ),
          child: Icon(
            Icons.groups,
            color:
                isAnyChildSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onPrimary.withOpacity(0.75),
            size: 18,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:
                isAnyChildSelected && !_rolesExpanded
                    ? colorScheme.onPrimary.withOpacity(0.2)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                isAnyChildSelected && !_rolesExpanded
                    ? Border.all(color: colorScheme.onPrimary.withOpacity(0.3))
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _rolesExpanded = !_rolesExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.groups,
                      color: colorScheme.onPrimary.withOpacity(
                        isAnyChildSelected ? 1.0 : 0.75,
                      ),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Roles',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withOpacity(
                            isAnyChildSelected ? 1.0 : 0.85,
                          ),
                          fontWeight:
                              isAnyChildSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      _rolesExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.onPrimary.withOpacity(0.75),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_rolesExpanded)
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 4, 16, 8),
              child: Text(
                'No records yet',
                style: TextStyle(
                  color: colorScheme.onPrimary.withOpacity(0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final e in visible)
              _buildNavItem(
                e.icon,
                e.label,
                e.section,
                indent: 1,
                badge: e.count,
              ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Mobile drawer
  // ------------------------------------------------------------------

  Widget _buildMobileDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = _roleEntries();
    return Drawer(
      backgroundColor: colorScheme.primary,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school,
                      color: colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _school?.name ?? 'School Admin',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.onPrimary.withOpacity(0.25)),
            Expanded(
              child: ListView(
                children: [
                  _drawerTile(Icons.dashboard, 'Dashboard', _Section.dashboard),
                  _drawerTile(Icons.fingerprint, 'Devices', _Section.devices),
                  _drawerTile(Icons.event_note, 'Sessions', _Section.sessions),
                  ExpansionTile(
                    iconColor: colorScheme.onPrimary,
                    collapsedIconColor: colorScheme.onPrimary.withOpacity(0.85),
                    leading: Icon(
                      Icons.groups,
                      color: colorScheme.onPrimary.withOpacity(0.85),
                    ),
                    title: Text(
                      'Roles',
                      style: TextStyle(color: colorScheme.onPrimary),
                    ),
                    initiallyExpanded:
                        _rolesExpanded ||
                        entries.any((e) => e.section == _selected),
                    onExpansionChanged:
                        (v) => setState(() => _rolesExpanded = v),
                    children: [
                      for (final e in entries)
                        if (e.count > 0)
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              56,
                              0,
                              16,
                              0,
                            ),
                            leading: Icon(
                              e.icon,
                              color: colorScheme.onPrimary.withOpacity(0.75),
                              size: 20,
                            ),
                            title: Text(
                              e.label,
                              style: TextStyle(color: colorScheme.onPrimary),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.onPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${e.count}',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            selected: _selected == e.section,
                            onTap: () {
                              setState(() => _selected = e.section);
                              Navigator.pop(context);
                            },
                          ),
                    ],
                  ),
                  _drawerTile(
                    Icons.insights_rounded,
                    'Reports',
                    _Section.reports,
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.onPrimary.withOpacity(0.25)),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: colorScheme.onPrimary.withOpacity(0.85),
              ),
              title: Text(
                'Logout',
                style: TextStyle(color: colorScheme.onPrimary),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, _Section section) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.onPrimary.withOpacity(0.85)),
      title: Text(label, style: TextStyle(color: colorScheme.onPrimary)),
      selected: _selected == section,
      onTap: () {
        setState(() => _selected = section);
        Navigator.pop(context);
      },
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
        );
      case _Section.sessions:
        return SessionsScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.reports:
        return const ReportsView();
      case _Section.rolesAdmins:
        return AdminsScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.rolesTeachers:
        return TeachersScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.rolesParents:
        return ParentsScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.rolesWorkers:
        return WorkersScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
      case _Section.rolesStudents:
        return StudentsScreen(
          schools: schools,
          onDataChanged: _loadData,
          showSchoolFilter: false,
        );
    }
  }
}

/// One row in the dynamic Roles submenu.
class _RoleEntry {
  final IconData icon;
  final String label;
  final int count;
  final _Section section;

  const _RoleEntry(this.icon, this.label, this.count, this.section);
}

// ----------------------------------------------------------------------
// Dashboard view
// ----------------------------------------------------------------------

class _DashboardView extends StatelessWidget {
  final School? school;
  final List<Student> students;
  final List<Teacher> teachers;
  final List<app_parent.Parent> parents;
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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _DeviceStatusCard(
                            active: activeDevices,
                            offline: offlineDevices,
                            total: devices.length,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _RecentActivityCard(activity: recentActivity),
                        ),
                      ],
                    ),
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
            mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
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
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minScrollContentHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
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
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showFormDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Device'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name, ID, or location...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: widget.statusFilter,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All statuses'),
                          ),
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
                        onChanged: (v) =>
                            widget.onStatusFilterChanged(v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        Colors.green,
                        Icons.check_circle,
                        '$active',
                        'Active',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        Colors.red,
                        Icons.error_outline,
                        '$offline',
                        'Offline',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        Colors.orange,
                        Icons.build_circle,
                        '$maintenance',
                        'Maintenance',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        colorScheme.primary,
                        Icons.devices_other,
                        '${widget.devices.length}',
                        'Total',
                      ),
                    ),
                  ],
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.fingerprint, color: statusColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasName ? device.deviceName! : device.deviceId,
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
                  subtitleParts.join(' · '),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
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
          ),
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
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDelete(device),
          ),
        ],
      ),
    );
  }

  void _openEnrollments(Device device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceEnrollmentsScreen(
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
