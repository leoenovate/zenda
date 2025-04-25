import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_log.dart';
import '../firebase_config.dart';
import '../utils/log_parser.dart';
import 'package:intl/intl.dart';

class ApiLogsScreen extends StatefulWidget {
  const ApiLogsScreen({super.key});

  @override
  State<ApiLogsScreen> createState() => _ApiLogsScreenState();
}

class _ApiLogsScreenState extends State<ApiLogsScreen> {
  List<ApiLog> logs = [];
  bool isLoading = true;
  String? selectedEndpoint;
  DateTime? selectedDate;
  String searchQuery = '';
  final TextEditingController _importController = TextEditingController();
  bool _isImporting = false;
  List<String> _importResults = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      setState(() {
        isLoading = true;
      });

      List<ApiLog> loadedLogs;
      try {
        if (selectedEndpoint != null) {
          loadedLogs = await FirebaseService.getApiLogsByEndpoint(selectedEndpoint!);
        } else {
          loadedLogs = await FirebaseService.getApiLogs();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading logs: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'DISMISS',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
        loadedLogs = []; // Use empty list if error occurs
      }
      
      // Apply date filter if needed
      if (selectedDate != null) {
        loadedLogs = loadedLogs.where((log) {
          return log.timestamp.year == selectedDate!.year &&
              log.timestamp.month == selectedDate!.month &&
              log.timestamp.day == selectedDate!.day;
        }).toList();
      }
      
      // Apply search filter if needed
      if (searchQuery.isNotEmpty) {
        loadedLogs = loadedLogs.where((log) {
          return log.endpoint.toLowerCase().contains(searchQuery.toLowerCase()) ||
              log.ipAddress.toLowerCase().contains(searchQuery.toLowerCase()) ||
              log.payload.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }

      setState(() {
        logs = loadedLogs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        logs = []; // Ensure logs is initialized even on error
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> _getUniqueEndpoints() {
    final endpoints = logs.map((log) => log.endpoint).toSet().toList();
    endpoints.sort();
    return endpoints;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Import API Logs', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste Vercel Function logs to import:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _importController,
                  maxLines: 10,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '14:53:20.122 127.0.0.1 - [25/Apr/2025 12:53:20] "POST /api/fingerprint HTTP/1.1" 200',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF212121),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_isImporting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_importResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Import Results:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212121),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 100,
                    width: double.infinity,
                    child: ListView.builder(
                      itemCount: _importResults.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _importResults[index],
                          style: TextStyle(
                            color: _importResults[index].contains('Error')
                                ? Colors.red
                                : Colors.green,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _importController.clear();
                _importResults.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isImporting
                  ? null
                  : () async {
                      if (_importController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please paste log text to import'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      setDialogState(() {
                        _isImporting = true;
                        _importResults.clear();
                      });
                      
                      try {
                        final results = await LogParser.importLogsToFirebase(_importController.text);
                        
                        setDialogState(() {
                          _importResults = results;
                          _isImporting = false;
                        });
                        
                        // Reload logs after successful import
                        _loadLogs();
                      } catch (e) {
                        setDialogState(() {
                          _importResults = ['Error during import: $e'];
                          _isImporting = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Logs'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _showImportDialog,
            tooltip: 'Import Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search in logs...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                  onChanged: (value) {
                    searchQuery = value;
                    _loadLogs();
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Endpoint filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: 'Endpoint',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                        ),
                        dropdownColor: const Color(0xFF2A2A2A),
                        style: const TextStyle(color: Colors.white),
                        value: selectedEndpoint,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All endpoints'),
                          ),
                          ..._getUniqueEndpoints().map(
                            (endpoint) => DropdownMenuItem<String>(
                              value: endpoint,
                              child: Text(endpoint),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedEndpoint = value;
                          });
                          _loadLogs();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Date picker
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: selectedDate != null 
                              ? Theme.of(context).colorScheme.primary 
                              : const Color(0xFF2A2A2A),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedDate != null
                              ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                              : 'Select Date',
                        ),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                    if (selectedDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            selectedDate = null;
                          });
                          _loadLogs();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Log list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No logs match your filters',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  selectedEndpoint = null;
                                  selectedDate = null;
                                  searchQuery = '';
                                });
                                _loadLogs();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reset Filters'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp);
                          
                          // Determine status color
                          Color statusColor;
                          if (log.statusCode >= 200 && log.statusCode < 300) {
                            statusColor = Colors.green;
                          } else if (log.statusCode >= 300 && log.statusCode < 400) {
                            statusColor = Colors.amber;
                          } else if (log.statusCode >= 400) {
                            statusColor = Colors.red;
                          } else {
                            statusColor = Colors.grey;
                          }
                          
                          return Card(
                            color: const Color(0xFF2A2A2A),
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      log.statusCode.toString(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      log.endpoint,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      log.ipAddress,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Method:',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            log.requestMethod,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.grey),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Device ID:',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            log.deviceId ?? 'N/A',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const Divider(color: Colors.grey),
                                      const Text(
                                        'Payload:',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF212121),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                log.payload.length > 500
                                                    ? '${log.payload.substring(0, 500)}...'
                                                    : log.payload,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.copy,
                                                color: Colors.grey,
                                                size: 18,
                                              ),
                                              onPressed: () => _copyToClipboard(log.payload),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (log.errorMessage != null) ...[
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Error:',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            log.errorMessage!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2A2A2A),
                title: const Text('Delete Old Logs', style: TextStyle(color: Colors.white)),
                content: const Text(
                  'Do you want to delete logs older than 30 days?',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      try {
                        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                        await FirebaseService.deleteOldApiLogs(thirtyDaysAgo);
                        
                        if (mounted) {
                          Navigator.of(context).pop();
                          _loadLogs();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Old logs deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting logs: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete_sweep, color: Colors.white),
        tooltip: 'Delete old logs',
      ),
    );
  }
} 