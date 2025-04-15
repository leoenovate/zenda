import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/worker.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Worker> workers = [];
  List<Worker> filteredWorkers = [];
  bool _isLoading = true;
  
  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  String? selectedPeriod;
  String? selectedGender;
  DateTime? selectedDate;
  String? selectedAttendanceStatus;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
    _searchController.addListener(_filterWorkers);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                  period: (data['Class']?.toString().toLowerCase() ?? '').contains('night')
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
        filteredWorkers = List.from(workers);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
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
          : Column(
              children: [
                _buildSearchAndFilterBar(context),
                Expanded(
                  child: Container(
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
                    child: filteredWorkers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No students match your filters',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Reset Filters', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredWorkers.length,
                          itemBuilder: (context, index) {
                            final worker = filteredWorkers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: worker.period == 'Afternoon'
                                          ? const Color(0xFF1E88E5)
                                          : const Color(0xFFF5F5F5),
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
                                        size: 16,
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
                                      const SizedBox(width: 12),
                                      if (worker.gender != null)
                                        Icon(
                                          worker.gender == 'M' ? Icons.male : Icons.female,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          size: 16,
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
                                        onPressed: () => _editWorker(workers.indexOf(worker)),
                                        tooltip: 'Edit Student',
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteWorker(workers.indexOf(worker)),
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
                ),
              ],
            ),
    );
  }
  
  Widget _buildSearchAndFilterBar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or registration number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterWorkers();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => _buildFilterBottomSheet(context),
                  );
                },
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: (selectedPeriod != null || selectedGender != null || 
                              selectedDate != null || selectedAttendanceStatus != null)
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                  backgroundColor: (selectedPeriod != null || selectedGender != null || 
                                    selectedDate != null || selectedAttendanceStatus != null)
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                ),
              ),
            ],
          ),
          if (selectedPeriod != null || selectedGender != null || 
              selectedDate != null || selectedAttendanceStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (selectedPeriod != null)
                      _buildFilterChip(
                        label: 'Class: $selectedPeriod',
                        onRemove: () {
                          setState(() {
                            selectedPeriod = null;
                            _filterWorkers();
                          });
                        },
                      ),
                    if (selectedGender != null)
                      _buildFilterChip(
                        label: 'Gender: ${selectedGender == 'M' ? 'Male' : 'Female'}',
                        onRemove: () {
                          setState(() {
                            selectedGender = null;
                            _filterWorkers();
                          });
                        },
                      ),
                    if (selectedDate != null)
                      _buildFilterChip(
                        label: 'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}',
                        onRemove: () {
                          setState(() {
                            selectedDate = null;
                            _filterWorkers();
                          });
                        },
                      ),
                    if (selectedAttendanceStatus != null)
                      _buildFilterChip(
                        label: 'Status: $selectedAttendanceStatus',
                        onRemove: () {
                          setState(() {
                            selectedAttendanceStatus = null;
                            _filterWorkers();
                          });
                        },
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
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