import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'dart:async';
import 'dart:convert';

class QRGeneratorScreen extends StatefulWidget {
  final String eventId;
  const QRGeneratorScreen({super.key, required this.eventId});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  late Timer _timer;
  late String _qrPayload;

  @override
  void initState() {
    super.initState();
    _generatePayload();
    // Refresh the payload every 5 seconds for security against screenshots
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _generatePayload();
    });
  }

  void _generatePayload() {
    final payload = {
      'eventId': widget.eventId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    setState(() {
      _qrPayload = jsonEncode(payload);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Secure Check-In QR')),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FA),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Show this Secure QR to students',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0E1424)),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'This QR code refreshes every 5 seconds to prevent screenshots and unauthorized access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
                child: QrImageView(
                  data: _qrPayload,
                  version: QrVersions.auto,
                  size: 280.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black), // Requested pure black
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
