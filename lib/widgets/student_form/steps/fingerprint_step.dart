import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

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
    print('[Fingerprint] Disposing and cleaning up resources');
    _fingerprintSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    print('[Fingerprint] Starting timeout timer: ${timeoutDuration.inSeconds} seconds');
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
        print('[Fingerprint] Progress: ${(_timeoutProgress * 100).toStringAsFixed(1)}% remaining (${(_timeoutProgress * timeoutDuration.inSeconds).round()}s)');
      }
      
      if (currentTick >= totalTicks) {
        print('[Fingerprint] Timeout timer completed');
        timer.cancel();
      }
    });
  }

  Future<void> _startFingerprintScan() async {
    print('[Fingerprint] Starting scan process');
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _timeoutProgress = 1.0;
    });
    
    _startTimeoutTimer();
    
    print('[Fingerprint] Showing scanning dialog');
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

    print('[Fingerprint] Starting Firestore listener');
    final timestamp = DateTime.now();
    print('[Fingerprint] Reference timestamp: ${timestamp.toIso8601String()}');
    
    _fingerprintSubscription = FirebaseFirestore.instance
        .collection('fingerprints')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            print('[Fingerprint] Received document: ${doc.id}');
            
            if (data['timestamp'] != null) {
              final fingerprintTimestamp = (data['timestamp'] as Timestamp).toDate();
              print('[Fingerprint] Document timestamp: ${fingerprintTimestamp.toIso8601String()}');
              
              if (fingerprintTimestamp.isAfter(timestamp)) {
                print('[Fingerprint] New fingerprint detected!');
                _fingerprintSubscription?.cancel();
                _timeoutTimer?.cancel();
                
                print('[Fingerprint] Fingerprint base64: ${data}');
                widget.onChanged('fingerprintData', data['fingerprint_sample']);
                widget.onChanged('fingerprintTimestamp', fingerprintTimestamp.toIso8601String());
                
                print('[Fingerprint] Capture successful');
                Navigator.pop(context);
                setState(() {
                  _isScanning = false;
                  _errorMessage = null;
                });
              } else {
                print('[Fingerprint] Old document, continuing to wait...');
              }
            } else {
              print('[Fingerprint] Warning: Document missing timestamp field');
            }
          } else {
            print('[Fingerprint] No documents found in snapshot');
          }
        }, onError: (error) {
          print('[Fingerprint] Error in Firestore listener: $error');
          _timeoutTimer?.cancel();
          setState(() {
            _errorMessage = 'Error connecting to fingerprint scanner';
            _isScanning = false;
          });
          Navigator.pop(context);
        });

    print('[Fingerprint] Starting timeout countdown');
    await Future.delayed(timeoutDuration);
    if (_isScanning) {
      print('[Fingerprint] Scan timed out after ${timeoutDuration.inSeconds} seconds');
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
                print('[Fingerprint] Fingerprint scan button clicked');
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
                    color: Colors.blue,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isScanning 
                        ? 'Scanning...' 
                        : widget.formData['fingerprintData'] != null
                          ? 'Fingerprint captured'
                          : 'Click to scan fingerprint',
                      style: TextStyle(
                        color: _isScanning 
                          ? Colors.blue
                          : widget.formData['fingerprintData'] != null
                            ? Colors.green
                            : Colors.grey[800],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
              print('[Fingerprint] Scan Again button clicked');
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