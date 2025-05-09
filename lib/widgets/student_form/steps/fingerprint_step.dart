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

  @override
  void dispose() {
    _fingerprintSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startFingerprintScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    
    // Show fingerprint scanning dialog
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
    final timestamp = DateTime.now();
    _fingerprintSubscription = FirebaseFirestore.instance
        .collection('fingerprints')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            
            // Check if this is a new fingerprint (after we started scanning)
            if (data['timestamp'] != null) {
              final fingerprintTimestamp = (data['timestamp'] as Timestamp).toDate();
              if (fingerprintTimestamp.isAfter(timestamp)) {
                // We found a new fingerprint
                _fingerprintSubscription?.cancel();
                widget.onChanged('fingerprintData', data['fingerprint_sample']);
                widget.onChanged('fingerprintTimestamp', fingerprintTimestamp.toIso8601String());
                Navigator.pop(context); // Close scanning dialog
                setState(() {
                  _isScanning = false;
                  _errorMessage = null;
                });
              }
            }
          }
        }, onError: (error) {
          setState(() {
            _errorMessage = 'Error connecting to fingerprint scanner';
            _isScanning = false;
          });
          Navigator.pop(context);
        });

    // Timeout after 2 minutes
    await Future.delayed(const Duration(seconds: 120));
    if (_isScanning) {
      _fingerprintSubscription?.cancel();
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
              onTap: _isScanning ? null : _startFingerprintScan,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isScanning) ...[
                      const SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Scanning...',
                        style: TextStyle(
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
                      if (widget.formData['fingerprintTimestamp'] != null)
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
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.formData['fingerprintData'] != null)
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _startFingerprintScan,
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