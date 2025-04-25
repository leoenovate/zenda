import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../models/worker.dart';
import 'package:intl/intl.dart';
import '../firebase_config.dart' as firebase_service;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Worker> workers = [];
  List<Worker> filteredWorkers = [];
  bool _isLoading = true;
  
  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  String? selectedPeriod;
  String? selectedGender;
  DateTime? selectedDate;
  String? selectedAttendanceStatus;
  
  // Animation controllers
  late AnimationController _controller;
  late Animation<double> _headerAnimation;
  late Animation<double> _searchAnimation;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    _searchController.addListener(_filterWorkers);
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _headerAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    
    _searchAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    
    _listAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    
    // Start animations after a short delay
    Timer(const Duration(milliseconds: 300), () {
      _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final List<Worker> loadedWorkers = await firebase_service.FirebaseService.getWorkers();
      
      if (!mounted) return;
      setState(() {
        workers = loadedWorkers;
        filteredWorkers = List.from(workers);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading workers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _filterWorkers() {
    setState(() {
      filteredWorkers = workers.where((worker) {
        // Search by name, registration number
        final query = _searchController.text.toLowerCase();
        final matchesSearch = query.isEmpty || 
            worker.name.toLowerCase().contains(query) || 
            (worker.registrationNumber?.toLowerCase().contains(query) ?? false);
        
        // Filter by period (class)
        final matchesPeriod = selectedPeriod == null || worker.period == selectedPeriod;
        
        // Filter by gender
        final matchesGender = selectedGender == null || worker.gender == selectedGender;
        
        // Filter by attendance date
        bool matchesDate = true;
        if (selectedDate != null && worker.attendanceHistory.isNotEmpty) {
          matchesDate = worker.attendanceHistory.any((attendance) => 
            attendance.date.year == selectedDate!.year && 
            attendance.date.month == selectedDate!.month && 
            attendance.date.day == selectedDate!.day);
        }
        
        // Filter by attendance status
        bool matchesStatus = true;
        if (selectedAttendanceStatus != null && worker.attendanceHistory.isNotEmpty) {
          AttendanceStatus status;
          switch (selectedAttendanceStatus) {
            case 'Present':
              status = AttendanceStatus.present;
              break;
            case 'Late':
              status = AttendanceStatus.late;
              break;
            case 'Absent':
              status = AttendanceStatus.absent;
              break;
            default:
              status = AttendanceStatus.present;
          }
          matchesStatus = worker.attendanceHistory.any((attendance) => 
            attendance.status == status);
        }
        
        return matchesSearch && matchesPeriod && matchesGender && matchesDate && matchesStatus;
      }).toList();
    });
  }
  
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      selectedPeriod = null;
      selectedGender = null;
      selectedDate = null;
      selectedAttendanceStatus = null;
      filteredWorkers = List.from(workers);
    });
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
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteWorker(int index) {
    final worker = workers[index];
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
            onPressed: () async {
              try {
                // Delete from Firebase
                if (worker.id == null) {
                  throw Exception('Worker ID not found');
                }
                await firebase_service.FirebaseService.deleteWorker(worker.id!);
                
                setState(() {
                  workers.removeAt(index);
                  _filterWorkers();
                });
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting student: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _viewAttendance(Worker worker) {
    final attendanceData = worker.attendanceHistory.isEmpty ? [
      Attendance(date: DateTime.now().subtract(const Duration(days: 6)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 5)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 4)), status: AttendanceStatus.late),
      Attendance(date: DateTime.now().subtract(const Duration(days: 3)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now().subtract(const Duration(days: 2)), status: AttendanceStatus.absent),
      Attendance(date: DateTime.now().subtract(const Duration(days: 1)), status: AttendanceStatus.present),
      Attendance(date: DateTime.now(), status: AttendanceStatus.present),
    ] : worker.attendanceHistory;

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
                  ? const Color(0xFF1E88E5)
                  : const Color(0xFFF5F5F5),
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

  void _addWorker() {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        String registrationNumber = '';
        String gender = 'M';
        String birthdate = '';
        String fatherName = '';
        String fatherPhone = '';
        String motherName = '';
        String motherPhone = '';
        String country = '';
        String province = '';
        String district = '';
        String sector = '';
        String cell = '';
        String period = 'Morning';

        return AlertDialog(
          title: const Text('Add New Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name *'),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Registration Number *'),
                  onChanged: (value) => registrationNumber = value,
                ),
                DropdownButtonFormField<String>(
                  value: period,
                  decoration: const InputDecoration(labelText: 'Session *'),
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
                  decoration: const InputDecoration(labelText: 'Gender *'),
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
                  onChanged: (value) => birthdate = value,
                ),
                const Divider(),
                TextField(
                  decoration: const InputDecoration(labelText: 'Father\'s Name'),
                  onChanged: (value) => fatherName = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Father\'s Phone'),
                  onChanged: (value) => fatherPhone = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Mother\'s Name'),
                  onChanged: (value) => motherName = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Mother\'s Phone'),
                  onChanged: (value) => motherPhone = value,
                ),
                const Divider(),
                TextField(
                  decoration: const InputDecoration(labelText: 'Country'),
                  onChanged: (value) => country = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Province'),
                  onChanged: (value) => province = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'District'),
                  onChanged: (value) => district = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Sector'),
                  onChanged: (value) => sector = value,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Cell'),
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
              onPressed: () async {
                if (name.isEmpty || registrationNumber.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name and Registration Number are required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final workerData = {
                  'name': name,
                  'period': period,
                  'registrationNumber': registrationNumber,
                  'gender': gender,
                  'birthdate': birthdate,
                  'fatherName': fatherName,
                  'fatherPhone': fatherPhone,
                  'motherName': motherName,
                  'motherPhone': motherPhone,
                  'country': country,
                  'province': province,
                  'district': district,
                  'sector': sector,
                  'cell': cell,
                  'attendanceHistory': [], // Empty array for new students
                  'createdAt': DateTime.now().toIso8601String(), // Add creation timestamp
                };

                try {
                  // Add to Firebase
                  final String workerId = await firebase_service.FirebaseService.addWorker(workerData);

                  final worker = Worker(
                    id: workerId,
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
                    attendanceHistory: [], // Required field for Worker constructor
                  );

                  setState(() {
                    workers.add(worker);
                    _filterWorkers();
                  });

                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding student: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Animated Header
                  FadeTransition(
                    opacity: _headerAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.2),
                        end: Offset.zero,
                      ).animate(_headerAnimation),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'School Attendance System',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                              onPressed: () {
                                Navigator.pushNamed(context, '/api-logs');
                              },
                              tooltip: 'API Logs',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Animated Search
                  FadeTransition(
                    opacity: _searchAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.2),
                        end: Offset.zero,
                      ).animate(_searchAnimation),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Search by name or registration number',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  builder: (context) => _buildFilterBottomSheet(context),
                                );
                              },
                              icon: const Icon(Icons.filter_list, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Animated Content
                  Expanded(
                    child: FadeTransition(
                      opacity: _listAnimation,
                      child: filteredWorkers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No students match your filters',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _resetFilters,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reset Filters'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredWorkers.length,
                            itemBuilder: (context, index) {
                              final worker = filteredWorkers[index];
                              
                              // Create a staggered animation for each list item
                              return AnimatedBuilder(
                                animation: _listAnimation,
                                builder: (context, child) {
                                  final itemAnimation = Tween<double>(
                                    begin: 0.0,
                                    end: 1.0,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _controller,
                                      curve: Interval(
                                        0.3 + (index * 0.05).clamp(0.0, 0.5),
                                        0.6 + (index * 0.05).clamp(0.0, 0.5),
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                  );
                                  
                                  return FadeTransition(
                                    opacity: itemAnimation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.2),
                                        end: Offset.zero,
                                      ).animate(itemAnimation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Stack(
                                        children: [
                                          if (worker.period == 'Afternoon')
                                            Positioned(
                                              left: 0,
                                              top: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 4,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ListTile(
                                            contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.grey.shade800,
                                              radius: 24,
                                              child: Text(
                                                worker.name[0].toUpperCase(),
                                                style: TextStyle(
                                                  color: worker.period == 'Afternoon' ? Colors.blue : Colors.grey,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              worker.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            subtitle: Row(
                                              children: [
                                                Icon(
                                                  Icons.brightness_5_rounded,
                                                  color: worker.period == 'Afternoon' ? Colors.blue : Colors.grey,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  worker.period,
                                                  style: TextStyle(
                                                    color: worker.period == 'Afternoon' ? Colors.blue : Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                if (worker.gender != null)
                                                  Icon(
                                                    worker.gender == 'M' ? Icons.male_rounded : Icons.female_rounded,
                                                    color: Colors.grey,
                                                    size: 14,
                                                  ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildActionButton(
                                                  icon: Icons.visibility_rounded,
                                                  color: const Color(0xFF2D3B55),
                                                  onTap: () => _viewAttendance(worker),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildActionButton(
                                                  icon: Icons.edit_rounded,
                                                  color: const Color(0xFF2D3B55),
                                                  onTap: () => _editWorker(workers.indexOf(worker)),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildActionButton(
                                                  icon: Icons.delete_rounded,
                                                  color: const Color(0xFF3D2D32),
                                                  iconColor: Colors.redAccent,
                                                  onTap: () => _deleteWorker(workers.indexOf(worker)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FadeTransition(
        opacity: _listAnimation,
        child: ScaleTransition(
          scale: _listAnimation,
          child: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: _addWorker,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterBottomSheet(BuildContext context) {
    String? tempPeriod = selectedPeriod;
    String? tempGender = selectedGender;
    DateTime? tempDate = selectedDate;
    String? tempAttendanceStatus = selectedAttendanceStatus;
    
    return StatefulBuilder(
      builder: (context, setModalState) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Students',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Filter options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Class',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Morning',
                          isSelected: tempPeriod == 'Morning',
                          onTap: () {
                            setModalState(() {
                              tempPeriod = tempPeriod == 'Morning' ? null : 'Morning';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Afternoon',
                          isSelected: tempPeriod == 'Afternoon',
                          onTap: () {
                            setModalState(() {
                              tempPeriod = tempPeriod == 'Afternoon' ? null : 'Afternoon';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Gender',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Male',
                          isSelected: tempGender == 'M',
                          onTap: () {
                            setModalState(() {
                              tempGender = tempGender == 'M' ? null : 'M';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Female',
                          isSelected: tempGender == 'F',
                          onTap: () {
                            setModalState(() {
                              tempGender = tempGender == 'F' ? null : 'F';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Attendance Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterOption(
                          label: 'Present',
                          isSelected: tempAttendanceStatus == 'Present',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Present' ? null : 'Present';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Late',
                          isSelected: tempAttendanceStatus == 'Late',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Late' ? null : 'Late';
                            });
                          },
                        ),
                        _buildFilterOption(
                          label: 'Absent',
                          isSelected: tempAttendanceStatus == 'Absent',
                          onTap: () {
                            setModalState(() {
                              tempAttendanceStatus = tempAttendanceStatus == 'Absent' ? null : 'Absent';
                            });
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Date',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: tempDate != null
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: tempDate != null
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempDate != null
                                        ? DateFormat('yyyy-MM-dd').format(tempDate!)
                                        : 'Select a date',
                                    style: TextStyle(
                                      color: tempDate != null
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: tempDate != null
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (tempDate != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setModalState(() {
                                tempDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Apply button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            tempPeriod = null;
                            tempGender = null;
                            tempDate = null;
                            tempAttendanceStatus = null;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedPeriod = tempPeriod;
                            selectedGender = tempGender;
                            selectedDate = tempDate;
                            selectedAttendanceStatus = tempAttendanceStatus;
                            _filterWorkers();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Apply', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
} 