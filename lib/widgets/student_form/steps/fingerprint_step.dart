import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:developer' as developer;

class FingerprintStep extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onChanged;

  const FingerprintStep({
    Key? key,
    required this.formData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<FingerprintStep> createState() => _FingerprintStepState();
}

class _FingerprintStepState extends State<FingerprintStep> {
  StreamSubscription<QuerySnapshot>? _fingerprintSubscription;
  bool _isScanning = false;
  String? _errorMessage;
  Timer? _timeoutTimer;
  double _timeoutProgress = 1.0;
  static const timeoutDuration = Duration(seconds: 120);
  static const timeoutTickInterval = Duration(milliseconds: 100);

  @override
  void dispose() {
    developer.log('Disposing FingerprintStep, cleaning up resources');
    _fingerprintSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    developer.log('Starting timeout timer: ${timeoutDuration.inSeconds} seconds');
    final totalTicks = timeoutDuration.inMilliseconds ~/ timeoutTickInterval.inMilliseconds;
    int currentTick = 0;
    
    _timeoutTimer = Timer.periodic(timeoutTickInterval, (timer) {
      if (!mounted) return;
      currentTick++;
      setState(() {
        _timeoutProgress = 1.0 - (currentTick / totalTicks);
      });
      
      // Log every 10 seconds
      if (currentTick % 100 == 0) {
        developer.log('Timeout progress: ${(_timeoutProgress * 100).toStringAsFixed(1)}% remaining (${(_timeoutProgress * timeoutDuration.inSeconds).round()} seconds)');
      }
      
      if (currentTick >= totalTicks) {
        developer.log('Timeout timer completed');
        timer.cancel();
      }
    });
  }

  Future<void> _startFingerprintScan() async {
    developer.log('Starting fingerprint scan process');
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _timeoutProgress = 1.0;
    });
    
    _startTimeoutTimer();
    
    // Show fingerprint scanning dialog
    developer.log('Showing fingerprint scanning dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Fingerprint Scanner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 72,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Put your finger on the sensor',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );

    // Start listening for new fingerprint documents
    developer.log('Starting Firestore listener for fingerprint collection');
    final timestamp = DateTime.now();
    developer.log('Reference timestamp: ${timestamp.toIso8601String()}');
    
    _fingerprintSubscription = FirebaseFirestore.instance
        .collection('fingerprints')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            developer.log('Received fingerprint document: ${doc.id}');
            
            // Check if this is a new fingerprint (after we started scanning)
            if (data['timestamp'] != null) {
              final fingerprintTimestamp = (data['timestamp'] as Timestamp).toDate();
              developer.log('Fingerprint timestamp: ${fingerprintTimestamp.toIso8601String()}');
              
              if (fingerprintTimestamp.isAfter(timestamp)) {
                developer.log('New fingerprint detected! Processing...');
                // We found a new fingerprint
                _fingerprintSubscription?.cancel();
                _timeoutTimer?.cancel();
                
                developer.log('Sample data length: ${data['fingerprint_sample'].toString().length} characters');
                widget.onChanged('fingerprintData', data['fingerprint_sample']);
                widget.onChanged('fingerprintTimestamp', fingerprintTimestamp.toIso8601String());
                
                developer.log('Fingerprint capture successful, closing dialog');
                Navigator.pop(context); // Close scanning dialog
                setState(() {
                  _isScanning = false;
                  _errorMessage = null;
                });
              } else {
                developer.log('Received old fingerprint document, continuing to wait...');
              }
            } else {
              developer.log('Warning: Fingerprint document missing timestamp field');
            }
          } else {
            developer.log('No fingerprint documents found in snapshot');
          }
        }, onError: (error) {
          developer.log('Error in Firestore listener: $error', error: error, stackTrace: StackTrace.current);
          _timeoutTimer?.cancel();
          setState(() {
            _errorMessage = 'Error connecting to fingerprint scanner';
            _isScanning = false;
          });
          Navigator.pop(context);
        });

    // Timeout after 2 minutes
    developer.log('Starting timeout countdown');
    await Future.delayed(timeoutDuration);
    if (_isScanning) {
      developer.log('Scan timed out after ${timeoutDuration.inSeconds} seconds');
      _fingerprintSubscription?.cancel();
      _timeoutTimer?.cancel();
      Navigator.pop(context);
      setState(() {
        _isScanning = false;
        _errorMessage = 'Fingerprint scan timed out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isScanning ? null : () {
                developer.log('Fingerprint scan button clicked');
                _startFingerprintScan();
              },
              borderRadius: BorderRadius.circular(120),
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isScanning 
                      ? Colors.blue 
                      : widget.formData['fingerprintData'] != null
                        ? Colors.green
                        : Colors.blue,
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isScanning)
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: _timeoutProgress,
                          strokeWidth: 2,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanning) ...[
                          const Icon(
                            Icons.fingerprint,
                            size: 64,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scanning... ${(_timeoutProgress * 120).round()}s',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else if (widget.formData['fingerprintData'] != null) ...[
                          const Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fingerprint captured',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.formData['fingerprintTimestamp'] != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateTime.parse(widget.formData['fingerprintTimestamp'])
                                    .toLocal()
                                    .toString()
                                    .split('.')[0],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fingerprint Data:',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.formData['fingerprintData'].toString(),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          const Icon(
                            Icons.fingerprint,
                            size: 64,
                            color: Colors.black54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Click to scan fingerprint',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.formData['fingerprintData'] != null)
          OutlinedButton.icon(
            onPressed: _isScanning ? null : () {
              developer.log('Scan Again button clicked');
              _startFingerprintScan();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
      ],
    );
  }
} 