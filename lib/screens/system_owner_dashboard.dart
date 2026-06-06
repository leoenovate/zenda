import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/school.dart';
import '../models/device.dart';
import '../models/user.dart' as app_user;
import '../models/student.dart';
import '../models/session.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/auth_storage_service.dart';
import '../services/role_constants.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/responsive_builder.dart';
import '../widgets/navigation/mobile_bottom_nav_shell.dart';
import '../widgets/navigation/mobile_nav_sheet.dart';
import '../widgets/theme/theme_switcher.dart';
import '../widgets/zenda_logo.dart';
import 'admin/teachers_screen.dart';
import 'admin/classes_screen.dart';
import 'admin/parents_screen.dart';
import 'reports_screen.dart';
import 'admin/sessions_screen.dart';
import 'admin/workers_screen.dart';
import 'admin/staff_time_off_screen.dart';
import 'admin/system_config_screen.dart';

class SystemOwnerDashboard extends StatefulWidget {
  const SystemOwnerDashboard({super.key});

  @override
  State<SystemOwnerDashboard> createState() => _SystemOwnerDashboardState();
}

class _SystemOwnerDashboardState extends State<SystemOwnerDashboard> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  bool _isLoading = true;

  List<School> schools = [];
  List<Device> devices = [];
  List<app_user.AppUser> users = [];
  List<Student> students = [];
  List<Map<String, dynamic>> recentActivity = [];

  // Schools view state
  String _searchQuery = '';
  _MobileSchoolDetail? _mobileSchoolDetail;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseService.getSchools(),
        FirebaseService.getDevices(),
        FirebaseService.getUsers(),
        FirebaseService.getStudents(),
        FirebaseService.getRecentActivity(limit: 4),
      ]);

      setState(() {
        schools = results[0] as List<School>;
        devices = results[1] as List<Device>;
        users = results[2] as List<app_user.AppUser>;
        students = results[3] as List<Student>;
        recentActivity = results[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final controller = context.watch<ThemeController>();
    // This dashboard was authored as a light-mode screen; we force a light
    // theme but let the primary hue follow the user's teal/orange choice.
    return Theme(
      data: AppTheme.light(primary: controller.primary),
      child:
          isMobile
              ? _buildMobileLayout()
              : Scaffold(
                body: Row(
                  children: [
                    _buildSidebar(isTablet: isTablet),
                    Expanded(child: _buildMainContent()),
                  ],
                ),
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
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      label: 'Schools',
    ),
    MobileNavDestination(
      icon: Icons.fingerprint_outlined,
      selectedIcon: Icons.fingerprint,
      label: 'Devices',
    ),
    MobileNavDestination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Reports',
    ),
    MobileNavDestination(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  int get _mobileNavIndex {
    switch (_selectedIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 9:
        return 3;
      default:
        return 4;
    }
  }

  String get _mobileSectionTitle {
    if (_mobileSchoolDetail != null) {
      return _mobileSchoolDetail!.school.name;
    }
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Schools';
      case 2:
        return 'Devices';
      case 3:
        return 'Teachers';
      case 4:
        return 'Classes';
      case 5:
        return 'Parents';
      case 6:
        return 'Sessions';
      case 7:
        return 'Workers';
      case 8:
        return 'Time off';
      case 9:
        return 'Reports';
      case 10:
        return 'System';
      default:
        return 'Zenda Admin';
    }
  }

  void _onMobileNavTap(int index) {
    if (index == 4) {
      _showMobileMoreSheet();
      return;
    }
    final sectionIndex = switch (index) {
      0 => 0,
      1 => 1,
      2 => 2,
      3 => 9,
      _ => _selectedIndex,
    };
    if (sectionIndex == _selectedIndex) return;
    setState(() {
      _selectedIndex = sectionIndex;
      _mobileSchoolDetail = null;
    });
  }

  void _showMobileMoreSheet() {
    showMobileNavSheet(
      context,
      title: 'More',
      items: [
        MobileNavSheetItem(
          icon: Icons.person_outline,
          label: 'Teachers',
          selected: _selectedIndex == 3,
          onTap:
              () => setState(() {
                _selectedIndex = 3;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.class_outlined,
          label: 'Classes',
          selected: _selectedIndex == 4,
          onTap:
              () => setState(() {
                _selectedIndex = 4;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.family_restroom,
          label: 'Parents',
          selected: _selectedIndex == 5,
          onTap:
              () => setState(() {
                _selectedIndex = 5;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.event_note_outlined,
          label: 'Sessions',
          selected: _selectedIndex == 6,
          onTap:
              () => setState(() {
                _selectedIndex = 6;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.engineering_outlined,
          label: 'Workers',
          selected: _selectedIndex == 7,
          onTap:
              () => setState(() {
                _selectedIndex = 7;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.event_busy_outlined,
          label: 'Time off',
          selected: _selectedIndex == 8,
          onTap:
              () => setState(() {
                _selectedIndex = 8;
                _mobileSchoolDetail = null;
              }),
        ),
        MobileNavSheetItem(
          icon: Icons.settings_outlined,
          label: 'System',
          selected: _selectedIndex == 10,
          onTap:
              () => setState(() {
                _selectedIndex = 10;
                _mobileSchoolDetail = null;
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
    final showingSchoolDetail = _mobileSchoolDetail != null;
    return MobileBottomNavShell(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading:
            showingSchoolDetail
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _mobileSchoolDetail = null),
                )
                : null,
        title: Text(
          _mobileSectionTitle,
          style: TextStyle(color: colorScheme.onSurface),
        ),
        automaticallyImplyLeading: showingSchoolDetail,
      ),
      body: _buildMainContent(),
      destinations: _mobileDestinations,
      selectedIndex: _mobileNavIndex,
      onDestinationSelected: _onMobileNavTap,
    );
  }

  Widget _buildSidebar({bool isTablet = false}) {
    // Auto-collapse sidebar on tablet, allow manual toggle on desktop
    final sidebarWidth =
        isTablet
            ? (_sidebarCollapsed ? 70.0 : 200.0)
            : (_sidebarCollapsed ? 70.0 : 240.0);

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
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
          // Logo and collapse button
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_sidebarCollapsed)
                  Row(
                    children: [
                      const ZendaLogo(
                        size: 32,
                        tone: ZendaLogoTone.onBrand,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Zenda Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(
                    _sidebarCollapsed
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                  },
                  tooltip: _sidebarCollapsed ? 'Expand' : 'Collapse',
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white30, height: 1),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.school, 'Schools', 1),
                _buildNavItem(Icons.fingerprint, 'Devices', 2),
                _buildNavItem(Icons.person, 'Teachers', 3),
                _buildNavItem(Icons.class_, 'Classes', 4),
                _buildNavItem(Icons.family_restroom, 'Parents', 5),
                _buildNavItem(Icons.event_note, 'Sessions', 6),
                _buildNavItem(Icons.engineering, 'Workers', 7),
                _buildNavItem(Icons.event_busy, 'Time off', 8),
                _buildNavItem(Icons.insights_rounded, 'Reports', 9),
                _buildNavItem(Icons.settings, 'System', 10),
              ],
            ),
          ),
          // User profile section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  radius: 16,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
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
                      children: const [
                        Text(
                          'System Owner',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Full Access',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const ThemeSwitcher(),
                  IconButton(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: _logout,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border:
            isSelected
                ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 18,
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
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

    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        if (_mobileSchoolDetail != null) {
          final detail = _mobileSchoolDetail!;
          return _SchoolDetailsPanel(
            embedded: true,
            onClose: () => setState(() => _mobileSchoolDetail = null),
            school: detail.school,
            schoolDevices: detail.schoolDevices,
            schoolAdmins: detail.schoolAdmins,
            schoolSessions: detail.schoolSessions,
            deviceCount: detail.deviceCount,
            activeDeviceCount: detail.activeDeviceCount,
            offlineDeviceCount: detail.offlineDeviceCount,
            initial: detail.initial,
            color: detail.color,
            onAddAdmin: () => _showAddAdminDialog(detail.school.id!),
            onEditAdmin: (admin) => _showEditAdminDialog(admin),
            onResetPassword: (admin) => _showResetPasswordDialog(admin),
            onDeactivateAdmin: (admin) => _showDeactivateAdminDialog(admin),
          );
        }
        return _buildSchoolsView();
      case 2:
        return _buildDevicesView();
      case 3:
        return TeachersScreen(schools: schools, onDataChanged: _loadData);
      case 4:
        return ClassesScreen(schools: schools, onDataChanged: _loadData);
      case 5:
        return ParentsScreen(schools: schools, onDataChanged: _loadData);
      case 6:
        return SessionsScreen(schools: schools, onDataChanged: _loadData);
      case 7:
        return WorkersScreen(schools: schools, onDataChanged: _loadData);
      case 8:
        return StaffTimeOffScreen(schools: schools, onDataChanged: _loadData);
      case 9:
        return const ReportsView();
      case 10:
        return const SystemConfigScreen();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;
    final adminUsers =
        users.where((u) => AuthRoles.isSchoolAdmin(u.role)).length;

    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(16)
            : context.isTablet
            ? const EdgeInsets.all(20)
            : const EdgeInsets.all(24);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar with welcome banner - Responsive
          Container(
            padding: EdgeInsets.symmetric(
              horizontal:
                  context.isMobile
                      ? 12
                      : context.isTablet
                      ? 14
                      : 16,
              vertical: context.isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, System Owner!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize:
                              context.isMobile
                                  ? 14
                                  : context.isTablet
                                  ? 15
                                  : 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: context.isMobile ? 1 : 2),
                      Text(
                        'System Owner - Full Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.isMobile ? 11 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.dark_mode,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {},
                    tooltip: 'Toggle theme',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {},
                        tooltip: 'Notifications',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Summary cards - Responsive grid
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              double aspectRatio;
              double spacing;

              if (context.isMobile) {
                crossAxisCount = 2;
                aspectRatio = 1.2;
                spacing = 12;
              } else if (context.isTablet) {
                crossAxisCount = 3;
                aspectRatio = 1.1;
                spacing = 12;
              } else {
                crossAxisCount = 6;
                aspectRatio = 1.0;
                spacing = 12;
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
                children: [
                  _buildSummaryCard(
                    Icons.business,
                    'Schools',
                    '${schools.length}',
                    Colors.blue,
                  ),
                  _buildSummaryCard(
                    Icons.school,
                    'Students',
                    '${students.length}',
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    Icons.person,
                    'Admins',
                    '$adminUsers',
                    Colors.purple,
                  ),
                  _buildSummaryCard(
                    Icons.fingerprint,
                    'Devices',
                    '${devices.length}',
                    Colors.orange,
                  ),
                  _buildSummaryCard(
                    Icons.check_circle,
                    'Active',
                    '$activeDevices',
                    Colors.green,
                  ),
                  _buildSummaryCard(
                    Icons.link_off,
                    'Offline',
                    '$offlineDevices',
                    Colors.red,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: context.isMobile ? 16 : 24),
          // Three column section - Responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (context.isMobile) {
                return Column(
                  children: [
                    _buildSchoolsSummaryCard(),
                    const SizedBox(height: 16),
                    _buildDeviceStatusCard(),
                    const SizedBox(height: 16),
                    _buildQuickActionsCard(),
                  ],
                );
              } else if (context.isTablet) {
                // Tablet: 2 columns (Schools Summary + Device Status, then Quick Actions)
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildSchoolsSummaryCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDeviceStatusCard()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionsCard(),
                  ],
                );
              } else {
                // Desktop: 3 columns
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildSchoolsSummaryCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDeviceStatusCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickActionsCard()),
                    ],
                  ),
                );
              }
            },
          ),
          SizedBox(height: context.isMobile ? 16 : 20),
          // Bottom two column section - Responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (context.isMobile) {
                return Column(
                  children: [
                    _buildRecentActivityCard(),
                    const SizedBox(height: 16),
                    _buildDevicesOverviewCard(),
                  ],
                );
              } else {
                // Tablet and Desktop: side by side
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 1, child: _buildRecentActivityCard()),
                      SizedBox(width: context.isTablet ? 12 : 16),
                      Expanded(flex: 1, child: _buildDevicesOverviewCard()),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(12)
            : context.isTablet
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);

    // Responsive font sizes
    final valueFontSize =
        context.isMobile
            ? 20.0
            : context.isTablet
            ? 22.0
            : 24.0;
    final labelFontSize = context.isMobile ? 11.0 : 12.0;
    final iconSize = context.isMobile ? 18.0 : 20.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(context.isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              Icon(
                Icons.show_chart,
                color: Theme.of(context).colorScheme.outline,
                size: 16,
              ),
            ],
          ),
          SizedBox(height: context.isMobile ? 8 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              SizedBox(height: context.isMobile ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolsSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Schools Summary',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child:
                students.isEmpty && users.isEmpty && devices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            color: Theme.of(context).colorScheme.outline,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No data available',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : PieChart(
                      PieChartData(
                        sections: [
                          if (students.isNotEmpty)
                            PieChartSectionData(
                              value: students.length.toDouble(),
                              color: Colors.blue,
                              title: '${students.length}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (users
                              .where((u) => AuthRoles.isSchoolAdmin(u.role))
                              .isNotEmpty)
                            PieChartSectionData(
                              value:
                                  users
                                      .where(
                                        (u) => AuthRoles.isSchoolAdmin(u.role),
                                      )
                                      .length
                                      .toDouble(),
                              color: Colors.purple,
                              title:
                                  '${users.where((u) => AuthRoles.isSchoolAdmin(u.role)).length}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (devices.isNotEmpty)
                            PieChartSectionData(
                              value: devices.length.toDouble(),
                              color: Colors.orange,
                              title: '${devices.length}',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                      ),
                    ),
          ),
          SizedBox(height: context.isMobile ? 12 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.blue, 'Students', students.length),
              _buildLegendItem(
                Colors.purple,
                'Admins',
                users.where((u) => AuthRoles.isSchoolAdmin(u.role)).length,
              ),
              _buildLegendItem(Colors.orange, 'Devices', devices.length),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${schools.length} Total Schools',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;
    final maintenanceDevices =
        devices.where((d) => d.status == 'maintenance').length;
    final total = devices.length;
    final onlinePercent = total > 0 ? (activeDevices / total * 100) : 0;

    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(12)
            : context.isTablet
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.fingerprint,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Device Status',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child:
                devices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pie_chart_outline,
                            color: Theme.of(context).colorScheme.outline,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No devices',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : PieChart(
                      PieChartData(
                        sections: [
                          if (activeDevices > 0)
                            PieChartSectionData(
                              value: activeDevices.toDouble(),
                              color: Colors.green,
                              title: '$activeDevices',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (offlineDevices > 0)
                            PieChartSectionData(
                              value: offlineDevices.toDouble(),
                              color: Colors.red,
                              title: '$offlineDevices',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (maintenanceDevices > 0)
                            PieChartSectionData(
                              value: maintenanceDevices.toDouble(),
                              color: Colors.orange,
                              title: '$maintenanceDevices',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${onlinePercent.toStringAsFixed(0)}% Online',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: context.isMobile ? 8 : 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusLegend(Colors.green, 'Active', activeDevices),
              const SizedBox(height: 4),
              _buildStatusLegend(Colors.red, 'Offline', offlineDevices),
              const SizedBox(height: 4),
              _buildStatusLegend(
                Colors.orange,
                'Maintenance',
                maintenanceDevices,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(12)
            : context.isTablet
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
            Icons.people,
            'Manage Users',
            Colors.blue,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.settings,
            'System Settings',
            Colors.green,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.bar_chart,
            'View Reports',
            Colors.orange,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.cloud_upload,
            'Backup Data',
            Colors.purple,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.swap_horiz,
            'Migrate period data',
            Colors.teal,
            _runPeriodsMigration,
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            Icons.assignment_ind_outlined,
            'Migrate worker roles',
            Colors.deepPurple,
            _runWorkerRolesMigration,
          ),
        ],
      ),
    );
  }

  Future<void> _runWorkerRolesMigration() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Migrate worker roles'),
            content: const Text(
              'Promote legacy free-form role labels on workers (e.g. "Nurse", '
              '"Administrator") into proper Role records and set every worker\'s '
              'roleId field. Safe to run more than once.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Run'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Running role migration...')),
    );
    try {
      final summary = await FirebaseService.migrateRoleStringsToRoleIds();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Created ${summary['rolesCreated']} role(s), '
            'migrated ${summary['workersMigrated']} worker(s), '
            'skipped ${summary['workersSkipped']}.',
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Role migration failed: $e')),
      );
    }
  }

  Future<void> _runPeriodsMigration() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Migrate period data'),
            content: const Text(
              'Seed default Sessions from each school\'s legacy morning/afternoon '
              'times and move students\' period values onto sessionIds. Safe to run '
              'more than once.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Run'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Running migration...')),
    );
    try {
      final summary = await FirebaseService.migrateSchoolPeriodsToSessions();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Migrated ${summary['schools']} schools, '
            'created ${summary['sessions']} sessions, '
            'updated ${summary['students']} students.',
          ),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Migration failed: $e')));
    }
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.outline,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(12)
            : context.isTablet
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentActivity
              .map((activity) => _buildActivityItem(activity))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final name = activity['studentName'] ?? 'Unknown';
    final id = activity['studentId'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    final color = colors[id.hashCode % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'ID: $id',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.2),
                  Colors.green.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesOverviewCard() {
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;

    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(12)
            : context.isTablet
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.laptop,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Devices Overview',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Manage',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDeviceSummaryCard(
                  Colors.blue,
                  Icons.laptop,
                  '${devices.length}',
                  'Total',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDeviceSummaryCard(
                  Colors.green,
                  Icons.check_circle,
                  '$activeDevices',
                  'Active',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDeviceSummaryCard(
                  Colors.red,
                  Icons.link_off,
                  '$offlineDevices',
                  'Offline',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...devices
              .take(2)
              .map((device) => _buildDeviceListItem(device))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildDeviceSummaryCard(
    Color color,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListItem(Device device) {
    final isActive = device.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fingerprint,
              color: Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceId,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (device.deviceName != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    device.deviceName!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? Colors.green : Colors.red).withOpacity(
                    0.5,
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isActive
                        ? [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.15),
                        ]
                        : [
                          Colors.red.withOpacity(0.2),
                          Colors.red.withOpacity(0.15),
                        ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isActive ? Colors.green : Colors.red).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              isActive ? 'Active' : 'Offline',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusLegend(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolsView() {
    // Filter schools based on search query
    final filteredSchools =
        _searchQuery.isEmpty
            ? schools
            : schools.where((school) {
              final query = _searchQuery.toLowerCase();
              return school.name.toLowerCase().contains(query) ||
                  (school.address?.toLowerCase().contains(query) ?? false) ||
                  (school.email?.toLowerCase().contains(query) ?? false) ||
                  (school.phone?.contains(query) ?? false);
            }).toList();

    // Calculate device counts per school
    final Map<String, int> deviceCounts = {};
    final Map<String, int> activeDeviceCounts = {};
    for (var device in devices) {
      if (device.schoolId != null) {
        deviceCounts[device.schoolId!] =
            (deviceCounts[device.schoolId!] ?? 0) + 1;
        if (device.status == 'active') {
          activeDeviceCounts[device.schoolId!] =
              (activeDeviceCounts[device.schoolId!] ?? 0) + 1;
        }
      }
    }

    // Responsive padding
    final padding =
        context.isMobile
            ? const EdgeInsets.all(16)
            : context.isTablet
            ? const EdgeInsets.all(20)
            : const EdgeInsets.all(24);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schools Management',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: context.isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _loadData(),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Manage Schools Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Schools',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create, view, and manage all schools in the system',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!context.isMobile) ...[
                      const SizedBox(width: 20),
                      _buildStatCard(
                        Icons.business,
                        '${schools.length}',
                        'Schools',
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        Icons.fingerprint,
                        '${devices.length}',
                        'Devices',
                        Colors.blue,
                      ),
                    ],
                  ],
                ),
              ),
              if (context.isMobile) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        Icons.business,
                        '${schools.length}',
                        'Schools',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        Icons.fingerprint,
                        '${devices.length}',
                        'Devices',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search schools by name, city, or country...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              onPressed:
                                  () => setState(() => _searchQuery = ''),
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Schools List
              if (filteredSchools.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No schools found'
                              : 'No schools match your search',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredSchools.map((school) {
                  final schoolDevices = deviceCounts[school.id ?? ''] ?? 0;
                  final activeDevices =
                      activeDeviceCounts[school.id ?? ''] ?? 0;

                  return _buildSchoolCard(school, schoolDevices, activeDevices);
                }).toList(),

              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),

        // Floating Action Button
        Positioned(
          bottom: context.isMobile ? 20 : 30,
          right: context.isMobile ? 20 : 30,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddSchoolDialog(),
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add School',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(
    School school,
    int deviceCount,
    int activeDeviceCount,
  ) {
    final initial = school.name.isNotEmpty ? school.name[0].toUpperCase() : '?';
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final color = colors[school.id.hashCode % colors.length];

    // Parse address for location display
    String location = school.address ?? 'No location';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // School Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (school.code != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    school.code!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (school.email != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          school.email!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deviceCount == 0
                          ? '0 devices'
                          : '$deviceCount device${deviceCount > 1 ? 's' : ''} â€¢ $activeDeviceCount active',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditSchoolDialog(school);
                  } else if (value == 'delete') {
                    _showDeleteSchoolDialog(school);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
              ),
              if (school.phone != null) ...[
                const SizedBox(height: 8),
                Text(
                  school.phone!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (school.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Updated: ${_formatDate(school.createdAt!)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed:
                    () => _showSchoolDetails(
                      school,
                      deviceCount,
                      activeDeviceCount,
                    ),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showAddSchoolDialog() {
    _showSchoolDialog();
  }

  void _showEditSchoolDialog(School school) {
    _showSchoolDialog(school: school);
  }

  void _showSchoolDialog({School? school}) {
    final nameController = TextEditingController(text: school?.name ?? '');
    final codeController = TextEditingController(text: school?.code ?? '');
    final addressController = TextEditingController(
      text: school?.address ?? '',
    );
    final phoneController = TextEditingController(text: school?.phone ?? '');
    final emailController = TextEditingController(text: school?.email ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              school == null ? 'Add School' : 'Edit School',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'School Name *',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'School Code',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Address',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('School name is required')),
                    );
                    return;
                  }

                  try {
                    final newSchool = School(
                      id: school?.id,
                      name: nameController.text.trim(),
                      code:
                          codeController.text.trim().isEmpty
                              ? null
                              : codeController.text.trim(),
                      address:
                          addressController.text.trim().isEmpty
                              ? null
                              : addressController.text.trim(),
                      phone:
                          phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                      email:
                          emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                      isActive: school?.isActive ?? true,
                      createdAt: school?.createdAt ?? DateTime.now(),
                    );

                    if (school == null) {
                      // Add new school
                      await FirebaseService.addSchool(newSchool);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('School added successfully'),
                        ),
                      );
                    } else {
                      // Update existing school
                      await FirebaseService.updateSchool(newSchool);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('School updated successfully'),
                        ),
                      );
                    }

                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(school == null ? 'Add' : 'Update'),
              ),
            ],
          ),
    );
  }

  void _showDeleteSchoolDialog(School school) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Delete School',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Are you sure you want to delete "${school.name}"? This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.deleteSchool(school.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('School deleted successfully'),
                      ),
                    );
                    Navigator.pop(context);
                    _loadData();
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

  void _showSchoolDetails(
    School school,
    int deviceCount,
    int activeDeviceCount,
  ) async {
    final schoolDevices =
        devices.where((d) => d.schoolId == school.id).toList();
    final offlineDeviceCount = deviceCount - activeDeviceCount;
    final schoolAdmins =
        users
            .where(
              (u) => u.schoolId == school.id && AuthRoles.isSchoolAdmin(u.role),
            )
            .toList();

    final initial = school.name.isNotEmpty ? school.name[0].toUpperCase() : '?';
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final color = colors[school.id.hashCode % colors.length];

    // Fetch sessions for this school
    List<Session> schoolSessions = [];
    if (school.id != null) {
      try {
        schoolSessions = await FirebaseService.getSchoolSessions(school.id!);
      } catch (e) {
        print('Error fetching sessions: $e');
        // Continue without sessions if fetch fails
      }
    }

    if (!mounted) return;
    if (context.isMobile) {
      setState(() {
        _mobileSchoolDetail = _MobileSchoolDetail(
          school: school,
          schoolDevices: schoolDevices,
          schoolAdmins: schoolAdmins,
          schoolSessions: schoolSessions,
          deviceCount: deviceCount,
          activeDeviceCount: activeDeviceCount,
          offlineDeviceCount: offlineDeviceCount,
          initial: initial,
          color: color,
        );
      });
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => _SchoolDetailsPanel(
              school: school,
              schoolDevices: schoolDevices,
              schoolAdmins: schoolAdmins,
              schoolSessions: schoolSessions,
              deviceCount: deviceCount,
              activeDeviceCount: activeDeviceCount,
              offlineDeviceCount: offlineDeviceCount,
              initial: initial,
              color: color,
              onAddAdmin: () => _showAddAdminDialog(school.id!),
              onEditAdmin: (admin) => _showEditAdminDialog(admin),
              onResetPassword: (admin) => _showResetPasswordDialog(admin),
              onDeactivateAdmin: (admin) => _showDeactivateAdminDialog(admin),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        opaque: false,
        barrierColor: Colors.black54,
      ),
    );
  }

  void _showAddAdminDialog(String schoolId) {
    _showAdminFormDialog(schoolId: schoolId);
  }

  void _showEditAdminDialog(app_user.AppUser admin) {
    _showAdminFormDialog(admin: admin, schoolId: admin.schoolId);
  }

  void _showAdminFormDialog({app_user.AppUser? admin, String? schoolId}) {
    final nameController = TextEditingController(text: admin?.name ?? '');
    final emailController = TextEditingController(text: admin?.email ?? '');
    final phoneController = TextEditingController(text: admin?.phone ?? '');
    final passwordController = TextEditingController();
    String role = admin?.role ?? AuthRoles.admin;
    bool isActive = admin?.isActive ?? true;
    bool isSaving = false;
    final isEdit = admin != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              InputDecoration field(String label, {bool required = false}) =>
                  InputDecoration(
                    labelText: required ? '$label *' : label,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  );

              return AlertDialog(
                backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                title: Text(
                  isEdit ? 'Edit Administrator' : 'Add Administrator',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Full Name', required: true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          enabled: !isEdit,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Email', required: true),
                        ),
                        if (!isEdit) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: field(
                              'Temporary Password',
                              required: true,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Phone'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: field('Role', required: true),
                          dropdownColor:
                              Theme.of(dialogCtx).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: AuthRoles.admin,
                              child: Text('School Admin'),
                            ),
                            DropdownMenuItem(
                              value: AuthRoles.teacher,
                              child: Text('Teacher'),
                            ),
                            DropdownMenuItem(
                              value: AuthRoles.staff,
                              child: Text('Staff'),
                            ),
                          ],
                          onChanged:
                              (v) => setStateDialog(
                                () => role = v ?? AuthRoles.admin,
                              ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isActive,
                            activeColor: Theme.of(context).colorScheme.primary,
                            title: Text(
                              'Active',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            onChanged:
                                (v) => setStateDialog(() => isActive = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              final name = nameController.text.trim();
                              final email = emailController.text.trim();
                              final phone = phoneController.text.trim();
                              final password = passwordController.text;

                              if (name.isEmpty || email.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Name and email are required',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (!isEdit && password.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password must be at least 6 characters',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setStateDialog(() => isSaving = true);
                              try {
                                if (isEdit) {
                                  final updated = app_user.AppUser(
                                    id: admin.id,
                                    email: admin.email,
                                    name: name,
                                    role: role,
                                    schoolId: schoolId ?? admin.schoolId,
                                    phone: phone.isEmpty ? null : phone,
                                    isActive: isActive,
                                    createdAt: admin.createdAt,
                                    lastLogin: admin.lastLogin,
                                  );
                                  await FirebaseService.updateAdmin(updated);
                                } else {
                                  await FirebaseService.addAdmin(
                                    email: email,
                                    password: password,
                                    role: role,
                                    name: name,
                                    schoolId: schoolId,
                                    phone: phone.isEmpty ? null : phone,
                                  );
                                }
                                if (!mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEdit
                                          ? 'Administrator updated'
                                          : 'Administrator created',
                                    ),
                                  ),
                                );
                                _loadData();
                              } catch (e) {
                                setStateDialog(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isSaving ? 'Saving...' : (isEdit ? 'Update' : 'Create'),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showResetPasswordDialog(app_user.AppUser admin) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Reset Password',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: SizedBox(
              width: 360,
              child: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Temporary Password *',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final password = passwordController.text;
                  if (password.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password must be at least 6 characters'),
                      ),
                    );
                    return;
                  }
                  try {
                    await FirebaseService.resetAdminPassword(
                      admin.id!,
                      password,
                    );
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset for ${admin.email}'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }

  void _showDeactivateAdminDialog(app_user.AppUser admin) {
    final willDeactivate = admin.isActive;
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              willDeactivate
                  ? 'Deactivate Administrator'
                  : 'Reactivate Administrator',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              willDeactivate
                  ? 'Are you sure you want to deactivate ${admin.name ?? admin.email}?'
                  : 'Reactivate ${admin.name ?? admin.email}?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseService.setAdminActive(
                      admin.id!,
                      !willDeactivate,
                    );
                    if (!mounted) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          willDeactivate
                              ? 'Administrator deactivated'
                              : 'Administrator reactivated',
                        ),
                      ),
                    );
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      willDeactivate
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(willDeactivate ? 'Deactivate' : 'Reactivate'),
              ),
            ],
          ),
    );
  }

  // --- Devices view ---

  String _deviceSearchQuery = '';
  String _deviceStatusFilter = 'all';
  String _deviceSchoolFilter = 'all';

  Widget _buildDevicesView() {
    final padding =
        context.isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(24);

    final filtered =
        devices.where((d) {
          if (_deviceStatusFilter != 'all' &&
              (d.status ?? 'offline') != _deviceStatusFilter) {
            return false;
          }
          if (_deviceSchoolFilter != 'all' &&
              d.schoolId != _deviceSchoolFilter) {
            return false;
          }
          if (_deviceSearchQuery.isNotEmpty) {
            final q = _deviceSearchQuery.toLowerCase();
            final name = (d.deviceName ?? '').toLowerCase();
            final id = d.deviceId.toLowerCase();
            final loc = (d.location ?? '').toLowerCase();
            if (!name.contains(q) && !id.contains(q) && !loc.contains(q)) {
              return false;
            }
          }
          return true;
        }).toList();

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage fingerprint scanners and other hardware',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDeviceFormDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Device'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
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
                  onChanged: (v) => setState(() => _deviceSearchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              _buildDeviceDropdown(
                value: _deviceStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                ],
                onChanged:
                    (v) => setState(() => _deviceStatusFilter = v ?? 'all'),
              ),
              const SizedBox(width: 12),
              _buildDeviceDropdown(
                value: _deviceSchoolFilter,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All schools'),
                  ),
                  ...schools.map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ),
                ],
                onChanged:
                    (v) => setState(() => _deviceSchoolFilter = v ?? 'all'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDeviceStatCard(
                  Colors.green,
                  Icons.check_circle,
                  '${devices.where((d) => d.status == 'active').length}',
                  'Active',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeviceStatCard(
                  Colors.red,
                  Icons.error_outline,
                  '${devices.where((d) => d.status == 'offline').length}',
                  'Offline',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeviceStatCard(
                  Colors.orange,
                  Icons.build_circle,
                  '${devices.where((d) => d.status == 'maintenance').length}',
                  'Maintenance',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeviceStatCard(
                  Theme.of(context).colorScheme.primary,
                  Icons.devices_other,
                  '${devices.length}',
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
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No devices match your filters',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder:
                    (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                itemBuilder: (_, i) => _buildDeviceListRow(filtered[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox.shrink(),
        dropdownColor: Theme.of(context).colorScheme.surface,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDeviceStatCard(
    Color color,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildDeviceListRow(Device device) {
    final schoolName =
        schools
            .firstWhere(
              (s) => s.id == device.schoolId,
              orElse: () => const School(name: 'Unassigned'),
            )
            .name;

    Color statusColor;
    switch (device.status) {
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
      schoolName,
      if (device.location != null && device.location!.trim().isNotEmpty)
        device.location!,
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
                    color: Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
                  (device.status ?? 'offline').toUpperCase(),
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
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _showDeviceFormDialog(device: device),
            tooltip: 'Edit',
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _showDeleteDeviceDialog(device),
            tooltip: 'Delete',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  void _showDeviceFormDialog({Device? device}) {
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
    String? schoolId = device?.schoolId;
    bool isSaving = false;
    final isEdit = device != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (dialogCtx, setStateDialog) {
              InputDecoration field(String label, {bool required = false}) =>
                  InputDecoration(
                    labelText: required ? '$label *' : label,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  );

              return AlertDialog(
                backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
                title: Text(
                  isEdit ? 'Edit Device' : 'Add Device',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: deviceIdController,
                          enabled: !isEdit,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Device ID', required: true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Device Name'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: deviceType,
                          decoration: field('Type'),
                          dropdownColor:
                              Theme.of(dialogCtx).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                        DropdownButtonFormField<String?>(
                          value: schoolId,
                          decoration: field('Assigned School'),
                          dropdownColor:
                              Theme.of(dialogCtx).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Unassigned'),
                            ),
                            ...schools.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setStateDialog(() => schoolId = v),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: locationController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          decoration: field('Location'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: field('Status'),
                          dropdownColor:
                              Theme.of(dialogCtx).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                                  schoolId: schoolId,
                                  isActive: status == 'active',
                                  lastSeen: device?.lastSeen,
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
                                _loadData();
                              } catch (e) {
                                setStateDialog(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
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

  void _showDeleteDeviceDialog(Device device) {
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(dialogCtx).colorScheme.surface,
            title: Text(
              'Delete Device',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Delete device "${device.deviceName ?? device.deviceId}"? This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                    _loadData();
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

class _MobileSchoolDetail {
  final School school;
  final List<Device> schoolDevices;
  final List<app_user.AppUser> schoolAdmins;
  final List<Session> schoolSessions;
  final int deviceCount;
  final int activeDeviceCount;
  final int offlineDeviceCount;
  final String initial;
  final Color color;

  const _MobileSchoolDetail({
    required this.school,
    required this.schoolDevices,
    required this.schoolAdmins,
    required this.schoolSessions,
    required this.deviceCount,
    required this.activeDeviceCount,
    required this.offlineDeviceCount,
    required this.initial,
    required this.color,
  });
}

class _SchoolDetailsPanel extends StatelessWidget {
  final School school;
  final List<Device> schoolDevices;
  final List<app_user.AppUser> schoolAdmins;
  final List<Session> schoolSessions;
  final int deviceCount;
  final int activeDeviceCount;
  final int offlineDeviceCount;
  final String initial;
  final Color color;
  final VoidCallback onAddAdmin;
  final Function(app_user.AppUser) onEditAdmin;
  final Function(app_user.AppUser) onResetPassword;
  final Function(app_user.AppUser) onDeactivateAdmin;
  final bool embedded;
  final VoidCallback? onClose;

  const _SchoolDetailsPanel({
    required this.school,
    required this.schoolDevices,
    required this.schoolAdmins,
    required this.schoolSessions,
    required this.deviceCount,
    required this.activeDeviceCount,
    required this.offlineDeviceCount,
    required this.initial,
    required this.color,
    required this.onAddAdmin,
    required this.onEditAdmin,
    required this.onResetPassword,
    required this.onDeactivateAdmin,
    this.embedded = false,
    this.onClose,
  });

  void _close(BuildContext context) {
    if (embedded) {
      onClose?.call();
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth =
        embedded
            ? null
            : (context.isMobile
                ? MediaQuery.of(context).size.width
                : (context.isTablet
                    ? MediaQuery.of(context).size.width * 0.6
                    : MediaQuery.of(context).size.width * 0.5));

    final panel = Container(
      width: panelWidth,
      height: embedded ? null : MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow:
            embedded
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(-5, 0),
                  ),
                ],
      ),
      child: _buildPanelBody(context),
    );

    if (embedded) {
      return SizedBox.expand(child: panel);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Backdrop - tap to close
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),
          panel,
        ],
      ),
    );
  }

  Widget _buildPanelBody(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (school.tagline != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        school.tagline!,
                        style: TextStyle(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!embedded)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _close(context),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                        // Description Section - Always show
                        _buildSectionTitle(context, 'Description'),
                        const SizedBox(height: 8),
                        Text(
                          school.description ?? 'No description provided',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Contact Information Section - Always show all fields
                        _buildSectionTitle(context, 'Contact Information'),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          Icons.location_on,
                          'Address',
                          school.address ?? 'No address provided',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.business,
                          'City',
                          school.city ?? 'No city provided',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.flag,
                          'Country',
                          school.country ?? 'No country provided',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.phone,
                          'Phone',
                          school.phone ?? 'No phone provided',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.email,
                          'Email',
                          school.email ?? 'No email provided',
                        ),
                        _buildInfoRow(
                          context,
                          Icons.language,
                          'Website',
                          school.website ?? 'No website provided',
                        ),
                        const SizedBox(height: 24),

                        // Attendance Sessions Section - link to admin screen
                        _buildSectionTitle(context, 'Attendance Sessions'),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          context,
                          Icons.event_note,
                          'Sessions',
                          'Manage from the Sessions tab',
                        ),
                        const SizedBox(height: 24),

                        // Assigned Devices Section - Always show
                        _buildSectionTitle(context, 'Assigned Devices'),
                        const SizedBox(height: 12),
                        // Summary bar - Always show
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _buildDeviceStat(
                                context,
                                Icons.laptop,
                                '$deviceCount',
                                'Total',
                                Colors.blue,
                              ),
                              const SizedBox(width: 16),
                              _buildDeviceStat(
                                context,
                                Icons.check_circle,
                                '$activeDeviceCount',
                                'Active',
                                Colors.green,
                              ),
                              const SizedBox(width: 16),
                              _buildDeviceStat(
                                context,
                                Icons.cloud_off,
                                '$offlineDeviceCount',
                                'Offline',
                                Colors.red,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Device list - Always show, even if empty
                        if (schoolDevices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No devices assigned',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ...schoolDevices.map(
                            (device) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          device.status == 'active'
                                              ? Colors.green
                                              : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      device.deviceName ?? device.deviceId,
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    device.status == 'active'
                                        ? 'â€¢ Active'
                                        : 'â€¢ Offline',
                                    style: TextStyle(
                                      color:
                                          device.status == 'active'
                                              ? Colors.green
                                              : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // School Sessions Section - Always show
                        _buildSectionTitle(context, 'School Sessions'),
                        const SizedBox(height: 12),
                        if (schoolSessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No sessions found',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ...schoolSessions
                              .take(10)
                              .map(
                                (session) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          session.isActive
                                              ? Colors.green
                                              : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                      width: session.isActive ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        session.isActive
                                            ? Icons.play_circle_filled
                                            : Icons.calendar_today,
                                        color:
                                            session.isActive
                                                ? Colors.green
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatDate(session.date),
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (session.className != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                session.className!,
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            if (session.startTime != null &&
                                                session.endTime != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${session.startTime} - ${session.endTime}',
                                                style: TextStyle(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (session.isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Active',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                        if (schoolSessions.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '... and ${schoolSessions.length - 10} more sessions',
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // School Administrators Section - Always show
                        _buildSectionTitle(context, 'School Administrators'),
                        const SizedBox(height: 12),
                        if (schoolAdmins.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No administrators assigned',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          ...schoolAdmins.map(
                            (admin) => _buildAdminCard(context, admin),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: onAddAdmin,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Another Admin'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (sessionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      // Format as "Mon, Jan 15, 2024"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          '$value ',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(BuildContext context, app_user.AppUser admin) {
    final initial =
        (admin.name?.isNotEmpty ?? false) ? admin.name![0].toUpperCase() : '?';
    final adminColor = Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: adminColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: adminColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            admin.name ?? 'Unknown',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                admin.isActive
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            admin.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: admin.isActive ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            admin.email,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (admin.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            admin.phone!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEditAdmin(admin),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onResetPassword(admin),
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: const Text('Reset Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onDeactivateAdmin(admin),
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Deactivate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
