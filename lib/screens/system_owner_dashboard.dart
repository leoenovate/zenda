import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/school.dart';
import '../models/device.dart';
import '../models/user.dart' as app_user;
import '../models/student.dart';
import '../models/session.dart';
import '../services/firebase_service.dart';
import '../services/auth_storage_service.dart';
import '../utils/responsive_builder.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await AuthStorageService.clearStoredLogin();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    
    if (isMobile) {
      return _buildMobileLayout();
    }
    
    // Tablet and Desktop layout
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          _buildSidebar(isTablet: isTablet),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildMobileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Zenda Admin', style: TextStyle(color: Color(0xFF2C2C2C))),
        iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFF666666)), 
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF666666)), 
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildSidebar({bool isTablet = false}) {
    // Auto-collapse sidebar on tablet, allow manual toggle on desktop
    final sidebarWidth = isTablet 
        ? (_sidebarCollapsed ? 70.0 : 200.0)
        : (_sidebarCollapsed ? 70.0 : 240.0);
    
    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: const Color(0xFF1A5F5F),
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
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Z',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                    _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
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
              ],
            ),
          ),
          // User profile section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  radius: 16,
                  child: const Text(
                    'S',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Full Access',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
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

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A5F5F),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Zenda Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.3)),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.white70),
            title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.white70),
            title: const Text('Schools', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint, color: Colors.white70),
            title: const Text('Devices', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: _logout,
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
        border: isSelected
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
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A5F5F)),
        ),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildSchoolsView();
      case 2:
        return _buildDevicesView();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;
    final adminUsers = users.where((u) => u.role == 'admin').length;
    
    // Responsive padding
    final padding = context.isMobile 
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
              horizontal: context.isMobile ? 12 : context.isTablet ? 14 : 16,
              vertical: context.isMobile ? 12 : 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A5F5F),
                  const Color(0xFF2A8A8A),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A5F5F).withOpacity(0.2),
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
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
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
                          fontSize: context.isMobile ? 14 : context.isTablet ? 15 : 16,
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
                    icon: const Icon(Icons.dark_mode, color: Colors.white, size: 18),
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
                        icon: const Icon(Icons.notifications, color: Colors.white, size: 18),
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
                  _buildSummaryCard(Icons.business, 'Schools', '${schools.length}', Colors.blue),
                  _buildSummaryCard(Icons.school, 'Students', '${students.length}', Colors.green),
                  _buildSummaryCard(Icons.person, 'Admins', '$adminUsers', Colors.purple),
                  _buildSummaryCard(Icons.fingerprint, 'Devices', '${devices.length}', Colors.orange),
                  _buildSummaryCard(Icons.check_circle, 'Active', '$activeDevices', Colors.green),
                  _buildSummaryCard(Icons.link_off, 'Offline', '$offlineDevices', Colors.red),
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

  Widget _buildSummaryCard(IconData icon, String label, String value, Color color) {
    // Responsive padding
    final padding = context.isMobile 
        ? const EdgeInsets.all(12)
        : context.isTablet 
            ? const EdgeInsets.all(14)
            : const EdgeInsets.all(16);
    
    // Responsive font sizes
    final valueFontSize = context.isMobile ? 20.0 : context.isTablet ? 22.0 : 24.0;
    final labelFontSize = context.isMobile ? 11.0 : 12.0;
    final iconSize = context.isMobile ? 18.0 : 20.0;
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
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
                color: const Color(0xFF999999),
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
                  color: const Color(0xFF2C2C2C),
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
                  color: const Color(0xFF666666),
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
          color: const Color(0xFFE0E0E0),
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
              const Icon(Icons.business, color: Color(0xFF1A5F5F), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Schools Summary',
                style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: students.isEmpty && users.isEmpty && devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline, color: const Color(0xFF999999), size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No data available',
                          style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
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
                        if (users.where((u) => u.role == 'admin').isNotEmpty)
                          PieChartSectionData(
                            value: users.where((u) => u.role == 'admin').length.toDouble(),
                            color: Colors.purple,
                            title: '${users.where((u) => u.role == 'admin').length}',
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
              _buildLegendItem(Colors.purple, 'Admins', users.where((u) => u.role == 'admin').length),
              _buildLegendItem(Colors.orange, 'Devices', devices.length),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${schools.length} Total Schools',
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    final activeDevices = devices.where((d) => d.status == 'active').length;
    final offlineDevices = devices.where((d) => d.status == 'offline').length;
    final maintenanceDevices = devices.where((d) => d.status == 'maintenance').length;
    final total = devices.length;
    final onlinePercent = total > 0 ? (activeDevices / total * 100) : 0;

    // Responsive padding
    final padding = context.isMobile 
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
          color: const Color(0xFFE0E0E0),
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
              const Icon(Icons.fingerprint, color: Color(0xFF1A5F5F), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Device Status',
                style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline, color: const Color(0xFF999999), size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No devices',
                          style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
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
              style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
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
              _buildStatusLegend(Colors.orange, 'Maintenance', maintenanceDevices),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    // Responsive padding
    final padding = context.isMobile 
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
          color: const Color(0xFFE0E0E0),
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
              const Icon(Icons.bolt, color: Color(0xFF1A5F5F), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Quick Actions',
                style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(Icons.people, 'Manage Users', Colors.blue, () {}),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.settings, 'System Settings', Colors.green, () {}),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.bar_chart, 'View Reports', Colors.orange, () {}),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.cloud_upload, 'Backup Data', Colors.purple, () {}),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
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
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFF999999),
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
    final padding = context.isMobile 
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
          color: const Color(0xFFE0E0E0),
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
                  const Icon(Icons.access_time, color: Color(0xFF1A5F5F), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Activity',
                    style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All', style: TextStyle(color: Color(0xFF1A5F5F))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentActivity.map((activity) => _buildActivityItem(activity)).toList(),
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
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
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'ID: $id',
                  style: const TextStyle(
                    color: Color(0xFF666666),
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
    final padding = context.isMobile 
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
          color: const Color(0xFFE0E0E0),
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
                  const Icon(Icons.laptop, color: Color(0xFF1A5F5F), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Devices Overview',
                    style: TextStyle(color: Color(0xFF2C2C2C), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Manage', style: TextStyle(color: Color(0xFF1A5F5F))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDeviceSummaryCard(Colors.blue, Icons.laptop, '${devices.length}', 'Total'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDeviceSummaryCard(Colors.green, Icons.check_circle, '$activeDevices', 'Active'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDeviceSummaryCard(Colors.red, Icons.link_off, '$offlineDevices', 'Offline'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...devices.take(2).map((device) => _buildDeviceListItem(device)).toList(),
        ],
      ),
    );
  }

  Widget _buildDeviceSummaryCard(Color color, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
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
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 11, height: 1.2),
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
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
            child: const Icon(Icons.fingerprint, color: Colors.orange, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceId,
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (device.deviceName != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    device.deviceName!,
                    style: const TextStyle(
                      color: Color(0xFF666666),
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
                  color: (isActive ? Colors.green : Colors.red).withOpacity(0.5),
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
                colors: isActive
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($count)', style: const TextStyle(color: Color(0xFF666666), fontSize: 10)),
      ],
    );
  }

  Widget _buildStatusLegend(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label ($count)', style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSchoolsView() {
    // Filter schools based on search query
    final filteredSchools = _searchQuery.isEmpty
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
        deviceCounts[device.schoolId!] = (deviceCounts[device.schoolId!] ?? 0) + 1;
        if (device.status == 'active') {
          activeDeviceCounts[device.schoolId!] = (activeDeviceCounts[device.schoolId!] ?? 0) + 1;
        }
      }
    }

    // Responsive padding
    final padding = context.isMobile 
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
                      color: const Color(0xFF2C2C2C),
                      fontSize: context.isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF666666)),
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
                  color: const Color(0xFF1A5F5F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1A5F5F),
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
                      _buildStatCard(Icons.business, '${schools.length}', 'Schools', Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard(Icons.fingerprint, '${devices.length}', 'Devices', Colors.blue),
                    ],
                  ],
                ),
              ),
              if (context.isMobile) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatCard(Icons.business, '${schools.length}', 'Schools', Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(Icons.fingerprint, '${devices.length}', 'Devices', Colors.blue)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Color(0xFF2C2C2C)),
                  decoration: InputDecoration(
                    hintText: 'Search schools by name, city, or country...',
                    hintStyle: const TextStyle(color: Color(0xFF999999)),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF666666)),
                            onPressed: () => setState(() => _searchQuery = ''),
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
                          color: const Color(0xFF999999),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No schools found'
                              : 'No schools match your search',
                          style: const TextStyle(
                            color: Color(0xFF666666),
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
                  final activeDevices = activeDeviceCounts[school.id ?? ''] ?? 0;
                  
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
            backgroundColor: const Color(0xFF1A5F5F),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add School',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
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
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(School school, int deviceCount, int activeDeviceCount) {
    final initial = school.name.isNotEmpty ? school.name[0].toUpperCase() : '?';
    final colors = [Colors.teal, Colors.blue, Colors.green, Colors.orange, Colors.purple];
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
          color: const Color(0xFFE0E0E0),
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
                  style: const TextStyle(
                    color: Color(0xFF2C2C2C),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (school.code != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    school.code!,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF666666)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: Color(0xFF666666),
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
                      const Icon(Icons.email, size: 16, color: Color(0xFF666666)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          school.email!,
                          style: const TextStyle(
                            color: Color(0xFF666666),
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
                    const Icon(Icons.fingerprint, size: 16, color: Color(0xFF666666)),
                    const SizedBox(width: 4),
                    Text(
                      deviceCount == 0
                          ? '0 devices'
                          : '$deviceCount device${deviceCount > 1 ? 's' : ''} • $activeDeviceCount active',
                      style: const TextStyle(
                        color: Color(0xFF666666),
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
                icon: const Icon(Icons.more_vert, color: Color(0xFF666666)),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditSchoolDialog(school);
                  } else if (value == 'delete') {
                    _showDeleteSchoolDialog(school);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Color(0xFF666666), size: 18),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: Color(0xFF2C2C2C))),
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
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ],
              if (school.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Updated: ${_formatDate(school.createdAt!)}',
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showSchoolDetails(school, deviceCount, activeDeviceCount),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A5F5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final addressController = TextEditingController(text: school?.address ?? '');
    final phoneController = TextEditingController(text: school?.phone ?? '');
    final emailController = TextEditingController(text: school?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          school == null ? 'Add School' : 'Edit School',
          style: const TextStyle(color: Color(0xFF2C2C2C)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                decoration: InputDecoration(
                  labelText: 'School Name *',
                  labelStyle: const TextStyle(color: Color(0xFF666666)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                decoration: InputDecoration(
                  labelText: 'School Code',
                  labelStyle: const TextStyle(color: Color(0xFF666666)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                decoration: InputDecoration(
                  labelText: 'Address',
                  labelStyle: const TextStyle(color: Color(0xFF666666)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: const TextStyle(color: Color(0xFF666666)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFF666666)),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1A5F5F), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
                  code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  isActive: school?.isActive ?? true,
                  createdAt: school?.createdAt ?? DateTime.now(),
                );

                if (school == null) {
                  // Add new school
                  await FirebaseService.addSchool(newSchool);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('School added successfully')),
                  );
                } else {
                  // Update existing school
                  await FirebaseService.updateSchool(newSchool);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('School updated successfully')),
                  );
                }

                Navigator.pop(context);
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5F5F),
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete School', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: Text(
          'Are you sure you want to delete "${school.name}"? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseService.deleteSchool(school.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School deleted successfully')),
                );
                Navigator.pop(context);
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
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

  void _showSchoolDetails(School school, int deviceCount, int activeDeviceCount) async {
    final schoolDevices = devices.where((d) => d.schoolId == school.id).toList();
    final offlineDeviceCount = deviceCount - activeDeviceCount;
    final schoolAdmins = users.where((u) => u.schoolId == school.id && u.role == 'admin').toList();
    
    final initial = school.name.isNotEmpty ? school.name[0].toUpperCase() : '?';
    final colors = [Colors.teal, Colors.blue, Colors.green, Colors.orange, Colors.purple];
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
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _SchoolDetailsPanel(
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

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

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
    // TODO: Implement add admin dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add admin functionality coming soon')),
    );
  }

  void _showEditAdminDialog(app_user.AppUser admin) {
    // TODO: Implement edit admin dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit admin functionality coming soon')),
    );
  }

  void _showResetPasswordDialog(app_user.AppUser admin) {
    // TODO: Implement reset password dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset password functionality coming soon')),
    );
  }

  void _showDeactivateAdminDialog(app_user.AppUser admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Deactivate Administrator', style: TextStyle(color: Color(0xFF2C2C2C))),
        content: Text(
          'Are you sure you want to deactivate ${admin.name ?? admin.email}?',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // TODO: Implement deactivate admin
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deactivate functionality coming soon')),
                );
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesView() {
    return const Center(child: Text('Devices View - Coming Soon', style: TextStyle(color: Color(0xFF2C2C2C))));
  }
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
  });

  @override
  Widget build(BuildContext context) {
    final panelWidth = context.isMobile 
        ? MediaQuery.of(context).size.width 
        : (context.isTablet 
            ? MediaQuery.of(context).size.width * 0.6 
            : MediaQuery.of(context).size.width * 0.5);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Backdrop - tap to close
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Right panel
          Container(
            width: panelWidth,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFFE0E0E0)),
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
                              style: const TextStyle(
                                color: Color(0xFF2C2C2C),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (school.tagline != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                school.tagline!,
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF666666)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Description Section - Always show
                      _buildSectionTitle('Description'),
                      const SizedBox(height: 8),
                      Text(
                        school.description ?? 'No description provided',
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      
                      // Contact Information Section - Always show all fields
                      _buildSectionTitle('Contact Information'),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.location_on, 'Address', school.address ?? 'No address provided'),
                      _buildInfoRow(Icons.business, 'City', school.city ?? 'No city provided'),
                      _buildInfoRow(Icons.flag, 'Country', school.country ?? 'No country provided'),
                      _buildInfoRow(Icons.phone, 'Phone', school.phone ?? 'No phone provided'),
                      _buildInfoRow(Icons.email, 'Email', school.email ?? 'No email provided'),
                      _buildInfoRow(Icons.language, 'Website', school.website ?? 'No website provided'),
                      const SizedBox(height: 24),
                      
                      // Attendance Settings Section - Always show if times exist
                      if (school.morningStart != null || school.afternoonStart != null) ...[
                        _buildSectionTitle('Attendance Settings'),
                        const SizedBox(height: 12),
                        if (school.morningStart != null && school.morningEnd != null)
                          _buildAttendanceTime(
                            Icons.wb_sunny,
                            'Morning',
                            '${school.morningStart} - ${school.morningEnd}',
                            school.morningLateTime,
                          )
                        else
                          _buildInfoRow(Icons.wb_sunny, 'Morning', 'Not configured'),
                        if (school.afternoonStart != null && school.afternoonEnd != null)
                          _buildAttendanceTime(
                            Icons.nightlight_round,
                            'Afternoon',
                            '${school.afternoonStart} - ${school.afternoonEnd}',
                            school.afternoonLateTime,
                          )
                        else if (school.morningStart != null)
                          _buildInfoRow(Icons.nightlight_round, 'Afternoon', 'Not configured'),
                        const SizedBox(height: 24),
                      ],
                      
                      // Assigned Devices Section - Always show
                      _buildSectionTitle('Assigned Devices'),
                      const SizedBox(height: 12),
                      // Summary bar - Always show
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _buildDeviceStat(Icons.laptop, '$deviceCount', 'Total', Colors.blue),
                            const SizedBox(width: 16),
                            _buildDeviceStat(Icons.check_circle, '$activeDeviceCount', 'Active', Colors.green),
                            const SizedBox(width: 16),
                            _buildDeviceStat(Icons.cloud_off, '$offlineDeviceCount', 'Offline', Colors.red),
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
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ...schoolDevices.map((device) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: device.status == 'active' ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      device.deviceName ?? device.deviceId,
                                      style: const TextStyle(color: Color(0xFF2C2C2C), fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    device.status == 'active' ? '• Active' : '• Offline',
                                    style: TextStyle(
                                      color: device.status == 'active' ? Colors.green : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      const SizedBox(height: 24),
                      
                      // School Sessions Section - Always show
                      _buildSectionTitle('School Sessions'),
                      const SizedBox(height: 12),
                      if (schoolSessions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No sessions found',
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ...schoolSessions.take(10).map((session) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: session.isActive ? Colors.green : const Color(0xFFE0E0E0),
                                  width: session.isActive ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    session.isActive ? Icons.play_circle_filled : Icons.calendar_today,
                                    color: session.isActive ? Colors.green : const Color(0xFF666666),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDate(session.date),
                                          style: const TextStyle(
                                            color: Color(0xFF2C2C2C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (session.period != null || session.className != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (session.period != null) session.period,
                                              if (session.className != null) session.className,
                                            ].join(' • '),
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if (session.startTime != null && session.endTime != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '${session.startTime} - ${session.endTime}',
                                            style: const TextStyle(
                                              color: Color(0xFF666666),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (session.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
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
                            )),
                      if (schoolSessions.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '... and ${schoolSessions.length - 10} more sessions',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      // School Administrators Section - Always show
                      _buildSectionTitle('School Administrators'),
                      const SizedBox(height: 12),
                      if (schoolAdmins.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No administrators assigned',
                              style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ...schoolAdmins.map((admin) => _buildAdminCard(admin)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: onAddAdmin,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Another Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5F5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF2C2C2C),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF666666)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF2C2C2C), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTime(IconData icon, String period, String timeRange, String? lateTime) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF666666)),
          const SizedBox(width: 8),
          Text(
            '$period: ',
            style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
          ),
          Text(
            lateTime != null ? '$timeRange (Late: $lateTime)' : timeRange,
            style: const TextStyle(color: Color(0xFF2C2C2C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStat(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          '$value ',
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAdminCard(app_user.AppUser admin) {
    final initial = (admin.name?.isNotEmpty ?? false) ? admin.name![0].toUpperCase() : '?';
    final adminColor = Colors.purple;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
                            style: const TextStyle(
                              color: Color(0xFF2C2C2C),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: admin.isActive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
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
                        const Icon(Icons.email, size: 14, color: Color(0xFF666666)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            admin.email,
                            style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (admin.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Color(0xFF666666)),
                          const SizedBox(width: 4),
                          Text(
                            admin.phone!,
                            style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
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
                    foregroundColor: const Color(0xFF666666),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
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
                    foregroundColor: const Color(0xFF666666),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
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

