import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/api_log.dart';
import 'package:intl/intl.dart';

class ApiLogsChart extends StatelessWidget {
  final List<ApiLog> logs;
  final bool showStatusCodes;
  final bool showResponseTimes;

  const ApiLogsChart({
    super.key, 
    required this.logs,
    this.showStatusCodes = true,
    this.showResponseTimes = false,
  });

  @override
  Widget build(BuildContext context) {
    // If we don't have logs, show placeholder
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey.shade700),
              const SizedBox(height: 16),
              Text(
                'No data to display',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    // Group by endpoints to color differently
    final endpoints = logs.map((log) => log.endpoint).toSet().toList();
    final endpointColors = <String, Color>{};
    
    // Assign colors to endpoints
    const colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
    ];
    
    for (int i = 0; i < endpoints.length; i++) {
      endpointColors[endpoints[i]] = colors[i % colors.length];
    }

    // Sort logs by timestamp
    final sortedLogs = List<ApiLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Response Status Over Time',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (showStatusCodes) _buildStatusCodeChart(sortedLogs, endpointColors, context),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Device Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildDeviceStatusChart(sortedLogs, context),
      ],
    );
  }

  Widget _buildStatusCodeChart(List<ApiLog> sortedLogs, Map<String, Color> endpointColors, BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 3 != 0 || value >= sortedLogs.length || value < 0) {
                    return const SizedBox();
                  }
                  final index = value.toInt();
                  if (index >= sortedLogs.length) return const SizedBox();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('HH:mm:ss').format(sortedLogs[index].timestamp),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // Status code ranges
                  int code = value.toInt();
                  Color textColor = Colors.grey;
                  
                  if (code >= 200 && code < 300) {
                    textColor = Colors.green;
                  } else if (code >= 300 && code < 400) {
                    textColor = Colors.orange;
                  } else if (code >= 400) {
                    textColor = Colors.red;
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      code.toString(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: _createStatusCodeLineBars(sortedLogs, endpointColors),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xff2C2C2C),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= sortedLogs.length) return null;
                  
                  final log = sortedLogs[index];
                  return LineTooltipItem(
                    '${log.endpoint}\n${log.statusCode}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  List<LineChartBarData> _createStatusCodeLineBars(List<ApiLog> sortedLogs, Map<String, Color> endpointColors) {
    // Group by endpoints to create separate lines
    final Map<String, List<ApiLog>> groupedByEndpoint = {};
    
    for (final log in sortedLogs) {
      if (!groupedByEndpoint.containsKey(log.endpoint)) {
        groupedByEndpoint[log.endpoint] = [];
      }
      groupedByEndpoint[log.endpoint]!.add(log);
    }
    
    return groupedByEndpoint.entries.map((entry) {
      final endpoint = entry.key;
      final endpointLogs = entry.value;
      
      return LineChartBarData(
        spots: List.generate(endpointLogs.length, (index) {
          return FlSpot(
            sortedLogs.indexOf(endpointLogs[index]).toDouble(),
            endpointLogs[index].statusCode.toDouble()
          );
        }),
        isCurved: true,
        color: endpointColors[endpoint] ?? Colors.blue,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: (endpointColors[endpoint] ?? Colors.blue).withOpacity(0.1),
        ),
      );
    }).toList();
  }

  Widget _buildDeviceStatusChart(List<ApiLog> sortedLogs, BuildContext context) {
    // Extract online status from payload if available
    final deviceStatusData = <DateTime, bool>{};
    
    for (final log in sortedLogs) {
      if (log.endpoint.contains('device-status') && log.payload.isNotEmpty) {
        bool isOnline = false;
        
        if (log.payload.contains('"is_online": true') || 
            log.payload.contains('"is_online":true')) {
          isOnline = true;
        }
        
        deviceStatusData[log.timestamp] = isOnline;
      }
    }
    
    final List<DateTime> timestamps = deviceStatusData.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    if (timestamps.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No device status data available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 3 != 0 || value >= timestamps.length || value < 0) {
                    return const SizedBox();
                  }
                  final index = value.toInt();
                  if (index >= timestamps.length) return const SizedBox();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('HH:mm').format(timestamps[index]),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      value == 1 ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: value == 1 ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          maxY: 1.1,
          minY: -0.1,
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(timestamps.length, (index) {
                final timestamp = timestamps[index];
                final isOnline = deviceStatusData[timestamp] ?? false;
                return FlSpot(index.toDouble(), isOnline ? 1 : 0);
              }),
              isCurved: false,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: const Color(0xff2C2C2C),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= timestamps.length) return null;
                  
                  final timestamp = timestamps[index];
                  final isOnline = deviceStatusData[timestamp] ?? false;
                  
                  return LineTooltipItem(
                    'Device: ${isOnline ? 'Online' : 'Offline'}\n${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}',
                    TextStyle(
                      color: isOnline ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
} 