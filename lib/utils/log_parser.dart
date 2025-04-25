import '../models/api_log.dart';
import '../firebase_config.dart';

class LogParser {
  // Parse Vercel function logs
  static List<ApiLog> parseVercelLogs(String logText) {
    final List<ApiLog> logs = [];
    final RegExp logEntryRegex = RegExp(
      r'(\d{2}:\d{2}:\d{2}\.\d{3})\s+([0-9.]+)\s+-\s+\[([^\]]+)\]\s+"([^"]+)"\s+(\d+)',
      multiLine: true,
    );
    
    final RegExp endpointRegex = RegExp(r'ENDPOINT:\s+([^\n]+)');
    final RegExp payloadRegex = RegExp(r'INFO\s+-\s+\{\s+"([^"]+)":\s+"([^"]+)"');
    
    final matches = logEntryRegex.allMatches(logText);
    
    for (final match in matches) {
      final timestamp = match.group(1)!;
      final ipAddress = match.group(2)!;
      final dateTime = match.group(3)!;
      final requestFull = match.group(4)!;
      final statusCode = int.parse(match.group(5)!);
      
      // Extract method and endpoint
      final requestParts = requestFull.split(' ');
      final method = requestParts[0];
      final endpoint = requestParts.length > 1 ? requestParts[1] : '';
      
      // Try to find endpoint description
      String fullEndpoint = endpoint;
      final endpointMatch = endpointRegex.firstMatch(logText.substring(match.start));
      if (endpointMatch != null) {
        fullEndpoint = endpointMatch.group(1) ?? endpoint;
      }
      
      // Try to extract payload
      String payload = '';
      final payloadMatch = payloadRegex.firstMatch(logText.substring(match.start));
      if (payloadMatch != null) {
        final key = payloadMatch.group(1);
        final value = payloadMatch.group(2);
        payload = '{ "$key": "$value" }';
      }
      
      // Parse timestamp
      final DateTime parsedTimestamp = DateTime.parse(
        '${dateTime.split(' ')[0].replaceAll('/', '-')}T$timestamp'
      );
      
      logs.add(ApiLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: parsedTimestamp,
        ipAddress: ipAddress,
        requestMethod: method,
        endpoint: fullEndpoint,
        statusCode: statusCode,
        payload: payload,
      ));
    }
    
    return logs;
  }
  
  // Import logs from raw log text
  static Future<List<String>> importLogsToFirebase(String logText) async {
    final logs = parseVercelLogs(logText);
    final List<String> results = [];
    
    for (final log in logs) {
      try {
        final id = await FirebaseService.addApiLog(log);
        results.add('Imported log ID: $id');
      } catch (e) {
        results.add('Error importing log: $e');
      }
    }
    
    return results;
  }
} 