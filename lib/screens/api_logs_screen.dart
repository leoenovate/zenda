import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/responsive_builder.dart';

class ApiLog {
  final String id;
  final String studentId;
  final String? studentName;
  final bool success;
  final DateTime timestamp;
  final String? deviceId;
  final String? errorMessage;
  final String type; // 'fingerprint', 'authentication', etc.

  ApiLog({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.success,
    required this.timestamp,
    this.deviceId,
    this.errorMessage,
    this.type = 'authentication',
  });

  factory ApiLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApiLog(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'],
      success: data['success'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      deviceId: data['deviceId'],
      errorMessage: data['errorMessage'],
      type: data['type'] ?? 'authentication',
    );
  }
}

class ApiLogsScreen extends StatefulWidget {
  const ApiLogsScreen({super.key});

  @override
  State<ApiLogsScreen> createState() => _ApiLogsScreenState();
}

class _ApiLogsScreenState extends State<ApiLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all'; // 'all', 'success', 'failed'
  String _selectedType = 'all'; // 'all', 'fingerprint', 'authentication'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('API Logs'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(context.spacingMd),
            color: const Color(0xFF2A2A2A),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      labelStyle: const TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'success', child: Text('Success')),
                      DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value ?? 'all';
                      });
                    },
                  ),
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      labelStyle: const TextStyle(color: Colors.white),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                          value: 'fingerprint', child: Text('Fingerprint')),
                      DropdownMenuItem(
                          value: 'authentication', child: Text('Authentication')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value ?? 'all';
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Logs list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        SizedBox(height: context.spacingMd),
                        Text(
                          'Error loading logs: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }

                final logs = snapshot.data?.docs
                        .map((doc) => ApiLog.fromFirestore(doc))
                        .toList() ??
                    [];

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined,
                            size: 64, color: Colors.grey.shade600),
                        SizedBox(height: context.spacingMd),
                        Text(
                          'No API logs found',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(context.spacingMd),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogItem(log, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getLogsStream() {
    Query query = _firestore
        .collection('api_logs')
        .orderBy('timestamp', descending: true)
        .limit(100);

    if (_selectedFilter != 'all') {
      query = query.where('success',
          isEqualTo: _selectedFilter == 'success');
    }

    if (_selectedType != 'all') {
      query = query.where('type', isEqualTo: _selectedType);
    }

    return query.snapshots();
  }

  Widget _buildLogItem(ApiLog log, BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: EdgeInsets.only(bottom: context.spacingSm),
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: log.success
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.success ? Icons.check_circle : Icons.error,
                    color: log.success ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                SizedBox(width: context.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.studentName ?? 'Unknown Student',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: context.spacingXs),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTypeColor(log.type).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.type.toUpperCase(),
                              style: TextStyle(
                                color: _getTypeColor(log.type),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: context.spacingSm),
                          Text(
                            DateFormat('MMM d, yyyy HH:mm:ss')
                                .format(log.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (log.errorMessage != null) ...[
              SizedBox(height: context.spacingSm),
              Container(
                padding: EdgeInsets.all(context.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 16),
                    SizedBox(width: context.spacingSm),
                    Expanded(
                      child: Text(
                        log.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (log.deviceId != null) ...[
              SizedBox(height: context.spacingXs),
              Text(
                'Device: ${log.deviceId}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fingerprint':
        return Colors.blue;
      case 'authentication':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}





