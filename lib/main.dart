import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Attendance System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1E88E5), // School blue
          secondary: const Color(0xFFF5F5F5), // Light gray/white
          surface: const Color(0xFF2A2A2A),
          background: const Color(0xFF1A1A1A),
          onPrimary: Colors.white,
          onSecondary: const Color(0xFF1A1A1A),
          onSurface: const Color(0xFFF5F5F5),
          onBackground: const Color(0xFFF5F5F5),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardTheme: CardTheme(
          color: const Color(0xFF2A2A2A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E88E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFF5F5F5).withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E88E5)),
          ),
        ),
      ),
      initialRoute: '/parent-login',
      routes: {
        '/parent-login': (context) => const ParentLoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class Attendance {
  final DateTime date;
  final AttendanceStatus status;

  const Attendance({
    required this.date,
    required this.status,
  });
}

enum AttendanceStatus {
  present,
  late,
  absent,
}

class Worker {
  final String name;
  final String period;
  final String? registrationNumber;
  final String? gender;
  final String? birthdate;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final String? country;
  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final List<Attendance> attendanceHistory;

  const Worker({
    required this.name,
    required this.period,
    this.registrationNumber,
    this.gender,
    this.birthdate,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.country,
    this.province,
    this.district,
    this.sector,
    this.cell,
    this.attendanceHistory = const [],
  });

  // Helper method to validate period
  static bool isValidPeriod(String period) {
    return ['Morning', 'Afternoon'].contains(period);
  }

  // Helper method to get short form of period
  static String getShortPeriod(String period) {
    return period;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Worker> workers = []; // Initialize with empty list
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      
      if (!mounted) return;

      setState(() {
        workers = jsonData
            .where((data) => data['LastName']?.isNotEmpty == true)
            .map((data) => Worker(
                  name: [
                    data['LastName'] ?? '',
                    data['middleName'] ?? '',
                    data['Firstname'] ?? ''
                  ].where((s) => s.isNotEmpty).join(' '),
                  period: (data['Class']?.toString().toLowerCase() ?? '')
                          .contains('night') 
                      ? 'Afternoon'
                      : 'Morning',
                  registrationNumber: data['Registration_Number'],
                  gender: data['Gender'],
                  birthdate: data['Birthdate'],
                  fatherName: data['Father_Names'],
                  fatherPhone: data['Father_PhoneNumber'],
                  motherName: data['Mother_Names'],
                  motherPhone: data['Mother_PhoneNumber'],
                  country: data['Country'],
                  province: data['Province'],
                  district: data['District'],
                  sector: data['Sector'],
                  cell: data['Cell'],
                  attendanceHistory: [],
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editWorker(int index) {
    final worker = workers[index];
    showDialog(
      context: context,
      builder: (context) {
        String name = worker.name;
        String registrationNumber = worker.registrationNumber ?? '';
        String gender = worker.gender ?? '';
        String birthdate = worker.birthdate ?? '';
        String fatherName = worker.fatherName ?? '';
        String fatherPhone = worker.fatherPhone ?? '';
        String motherName = worker.motherName ?? '';
        String motherPhone = worker.motherPhone ?? '';
        String country = worker.country ?? '';
        String province = worker.province ?? '';
        String district = worker.district ?? '';
        String sector = worker.sector ?? '';
        String cell = worker.cell ?? '';
        
        // Simplify period to Morning/Afternoon
        String period = worker.period;

        return AlertDialog(
          title: const Text('Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  controller: TextEditingController(text: name),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Registration Number'),
                  controller: TextEditingController(text: registrationNumber),
                  onChanged: (value) => registrationNumber = value,
                ),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'Session'),
                  items: ['Morning', 'Afternoon'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) period = value;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: ['M', 'F'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'M' ? 'Male' : 'Female'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) gender = value;
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Birthdate (YYYY-MM-DD)'),
                  controller: TextEditingController(text: birthdate),
                  onChanged: (value) => birthdate = value,
                ),
                const Divider(),
                TextField(
                  decoration: const InputDecoration(labelText: 'Father\'s Name'),
                  controller: TextEditingController(text: fatherName),
                  onChanged: (value) => fatherName = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Father\'s Phone'),
                  controller: TextEditingController(text: fatherPhone),
                  onChanged: (value) => fatherPhone = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Mother\'s Name'),
                  controller: TextEditingController(text: motherName),
                  onChanged: (value) => motherName = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Mother\'s Phone'),
                  controller: TextEditingController(text: motherPhone),
                  onChanged: (value) => motherPhone = value,
                ),
                const Divider(),
                TextField(
                  decoration: const InputDecoration(labelText: 'Country'),
                  controller: TextEditingController(text: country),
                  onChanged: (value) => country = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Province'),
                  controller: TextEditingController(text: province),
                  onChanged: (value) => province = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'District'),
                  controller: TextEditingController(text: district),
                  onChanged: (value) => district = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Sector'),
                  controller: TextEditingController(text: sector),
                  onChanged: (value) => sector = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Cell'),
                  controller: TextEditingController(text: cell),
                  onChanged: (value) => cell = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  workers[index] = Worker(
                    name: name,
                    period: period,
                    registrationNumber: registrationNumber,
                    gender: gender,
                    birthdate: birthdate,
                    fatherName: fatherName,
                    fatherPhone: fatherPhone,
                    motherName: motherName,
                    motherPhone: motherPhone,
                    country: country,
                    province: province,
                    district: district,
                    sector: sector,
                    cell: cell,
                    attendanceHistory: worker.attendanceHistory,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteWorker(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                workers.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewAttendance(Worker worker) {
    // Generate some sample attendance data if empty
    final attendanceData = worker.attendanceHistory.isEmpty ? [
      Attendance(date: DateTime.now().subtract(const Duration(days: 6)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 5)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 4)), status: AttendanceStatus.late),
      Attendance(date: DateTime.now().subtract(const Duration(days: 3)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 2)), status: AttendanceStatus.absent),
      Attendance(date: DateTime.now().subtract(const Duration(days: 1)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now(), status: AttendanceStatus.present),
    ] : worker.attendanceHistory;

    // Calculate attendance statistics
    int present = attendanceData.where((a) => a.status == AttendanceStatus.present).length;
    int late = attendanceData.where((a) => a.status == AttendanceStatus.late).length;
    int absent = attendanceData.where((a) => a.status == AttendanceStatus.absent).length;
    int total = attendanceData.length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: worker.period == 'Afternoon'
                  ? const Color(0xFF1E88E5)  // School blue
                  : const Color(0xFFF5F5F5), // Light gray/white
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    worker.period == 'Afternoon'
                        ? Icons.wb_sunny
                        : Icons.brightness_5,
                    color: worker.period == 'Afternoon'
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFFF5F5F5),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${worker.name} Attendance',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Attendance Summary - Refined design
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(context, present, total, 'Present', Colors.green),
                    Container(
                      height: 30,
                      width: 1,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    _buildStatColumn(context, late, total, 'Late', Colors.orange),
                    Container(
                      height: 30,
                      width: 1,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    ),
                    _buildStatColumn(context, absent, total, 'Absent', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Weekly Chart - Refined design
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last 7 Days:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: attendanceData.take(7).map((attendance) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 60,
                              decoration: BoxDecoration(
                                color: switch (attendance.status) {
                                  AttendanceStatus.present => Colors.green.withOpacity(0.7),
                                  AttendanceStatus.late => Colors.orange.withOpacity(0.7),
                                  AttendanceStatus.absent => Colors.red.withOpacity(0.7),
                                },
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${attendance.date.day}/${attendance.date.month}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Attendance List - Refined design
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: attendanceData.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: switch (attendance.status) {
                              AttendanceStatus.present => Colors.green.withOpacity(0.1),
                              AttendanceStatus.late => Colors.orange.withOpacity(0.1),
                              AttendanceStatus.absent => Colors.red.withOpacity(0.1),
                            },
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            switch (attendance.status) {
                              AttendanceStatus.present => Icons.check_circle,
                              AttendanceStatus.late => Icons.access_time,
                              AttendanceStatus.absent => Icons.cancel,
                            },
                            color: switch (attendance.status) {
                              AttendanceStatus.present => Colors.green,
                              AttendanceStatus.late => Colors.orange,
                              AttendanceStatus.absent => Colors.red,
                            },
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${attendance.date.year}-${attendance.date.month.toString().padLeft(2, '0')}-${attendance.date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          switch (attendance.status) {
                            AttendanceStatus.present => 'Present',
                            AttendanceStatus.late => 'Late',
                            AttendanceStatus.absent => 'Absent',
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, int value, int total, String label, Color color) {
    double percentage = total > 0 ? (value / total * 100) : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.school,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'School Attendance System',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.background,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: worker.period == 'Afternoon'
                                ? const Color(0xFF1E88E5) // School blue for afternoon session
                                : const Color(0xFFF5F5F5), // Light gray/white for morning session
                            width: 4,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: worker.period == 'Afternoon'
                              ? const Color(0xFF1E88E5).withOpacity(0.2)
                              : const Color(0xFFF5F5F5).withOpacity(0.2),
                          radius: 26,
                          child: Text(
                            worker.name[0],
                            style: TextStyle(
                              color: worker.period == 'Afternoon'
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFFF5F5F5),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          worker.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              worker.period == 'Afternoon'
                                  ? Icons.wb_sunny
                                  : Icons.brightness_5,
                              color: worker.period == 'Afternoon'
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFFF5F5F5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              worker.period,
                              style: TextStyle(
                                color: worker.period == 'Afternoon'
                                    ? const Color(0xFF1E88E5)
                                    : const Color(0xFFF5F5F5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _viewAttendance(worker),
                              tooltip: 'View Attendance',
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editWorker(index),
                              tooltip: 'Edit Student',
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteWorker(index),
                              tooltip: 'Delete Student',
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _phoneController = TextEditingController();
  final _verificationController = TextEditingController();
  List<Worker> workers = [];
  Worker? matchedStudent;
  String? parentName;
  bool isLoading = false;
  bool showVerification = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      
      setState(() {
        workers = jsonData
            .where((data) => data['LastName']?.isNotEmpty == true)
            .map((data) => Worker(
                  name: [
                    data['LastName'] ?? '',
                    data['middleName'] ?? '',
                    data['Firstname'] ?? ''
                  ].where((s) => s.isNotEmpty).join(' '),
                  period: (data['Class']?.toString().toLowerCase() ?? '')
                          .contains('night') 
                      ? 'Afternoon'
                      : 'Morning',
                  registrationNumber: data['Registration_Number'],
                  gender: data['Gender'],
                  birthdate: data['Birthdate'],
                  fatherName: data['Father_Names'],
                  fatherPhone: data['Father_PhoneNumber'],
                  motherName: data['Mother_Names'],
                  motherPhone: data['Mother_PhoneNumber'],
                  country: data['Country'],
                  province: data['Province'],
                  district: data['District'],
                  sector: data['Sector'],
                  cell: data['Cell'],
                  attendanceHistory: [],
                ))
            .toList();
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load student data';
      });
    }
  }

  void _verifyPhoneNumber() {
    setState(() {
      isLoading = true;
      errorMessage = null;
      matchedStudent = null;
      parentName = null;
    });

    final phoneNumber = _phoneController.text.trim();
    
    // Search for matching parent phone number
    final matchedWorker = workers.firstWhere(
      (worker) => 
        worker.fatherPhone == phoneNumber || 
        worker.motherPhone == phoneNumber,
      orElse: () => Worker(name: '', period: ''),
    );

    setState(() {
      isLoading = false;
      if (matchedWorker.name.isNotEmpty) {
        matchedStudent = matchedWorker;
        parentName = matchedWorker.fatherPhone == phoneNumber
            ? matchedWorker.fatherName
            : matchedWorker.motherName;
        showVerification = true;
      } else {
        errorMessage = 'No student found with this parent phone number';
      }
    });
  }

  void _verifyCode() {
    final code = _verificationController.text.trim();
    // In a real app, you would verify this code against a backend
    // For demo purposes, we'll accept any 6-digit code
    if (code.length == 6 && RegExp(r'^\d+$').hasMatch(code)) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        errorMessage = 'Please enter a valid 6-digit code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.school,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Parent Login',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !showVerification,
                ),
                const SizedBox(height: 16),
                if (!showVerification) ElevatedButton(
                  onPressed: _verifyPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify Phone Number'),
                ),
                if (showVerification) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${parentName ?? "Parent"}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Student: ${matchedStudent?.name ?? ""}'),
                          Text('Class: ${matchedStudent?.period ?? ""} Session'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _verificationController,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _verifyCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Verify Code'),
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
