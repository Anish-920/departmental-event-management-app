import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/services/firestore_service.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/models/timetable_model.dart';

class QRScannerScreen extends StatefulWidget {
  // Removed expectedEventId! We are now using a Universal Scanner design.
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawPayload = barcodes.first.rawValue;
    if (rawPayload == null) return;
    
    setState(() => _isProcessing = true);
    final userId = context.read<UserModel?>()?.uid;
    final firestore = context.read<FirestoreService>();
    
    if (userId != null) {
      try {
        // Decode the JSON payload
        Map<String, dynamic> payloadData;
        try {
          payloadData = jsonDecode(rawPayload);
        } catch (e) {
          throw Exception('Invalid QR Format. Please scan an Official Event QR.');
        }

        final String scannedEventId = payloadData['eventId'];
        final int timestampRaw = payloadData['timestamp'];
        
        // Anti-Screenshot validation (5 seconds max age)
        final qrGeneratedTime = DateTime.fromMillisecondsSinceEpoch(timestampRaw);
        if (DateTime.now().difference(qrGeneratedTime).inSeconds > 5) {
          throw Exception('QR Code Expired. Please scan the live QR code directly.');
        }

        // 1. Verify it's a real event
        final eventDoc = await FirebaseFirestore.instance.collection('events').doc(scannedEventId).get();
        if (!eventDoc.exists) {
          throw Exception('Event does not exist.');
        }

        // 2. RSVP Verification check
        final rsvpDoc = await FirebaseFirestore.instance
            .collection('events')
            .doc(scannedEventId)
            .collection('rsvps')
            .doc(userId)
            .get();

        if (!rsvpDoc.exists) {
          throw Exception('You have not requested to join this event.');
        }
        
        final rsvpStatus = (rsvpDoc.data() as Map<String, dynamic>)['status'];
        if (rsvpStatus != 'approved') {
          throw Exception('Your RSVP is still pending approval. You cannot enter yet.');
        }

        // 3. Determine Entry or Exit based on existing Attendance Document
        final attendanceDocRef = FirebaseFirestore.instance.collection('events').doc(scannedEventId).collection('attendance').doc(userId);
        final attendanceDoc = await attendanceDocRef.get();
        
        String scanMode = 'entry'; // Default to entry
        
        if (attendanceDoc.exists) {
           final attendanceData = attendanceDoc.data() as Map<String, dynamic>;
           // If they have an entry time but NO exit time, mark as exit
           if (attendanceData.containsKey('entryTime') && attendanceData['entryTime'] != null) {
              if (!attendanceData.containsKey('exitTime') || attendanceData['exitTime'] == null) {
                scanMode = 'exit';
              } else {
                throw Exception('You have already entered and exited this event.');
              }
           }
        }

        // 4. TIMETABLE LOGIC: Find active teacher based on current time (with minute precision)
        final now = DateTime.now();
        final nowTotalMinutes = now.hour * 60 + now.minute;
        String? activeTeacherId;

        final timetablesSnapshot = await FirebaseFirestore.instance
            .collection('timetables')
            .where('dayOfWeek', isEqualTo: now.weekday)
            .get();

        for (var doc in timetablesSnapshot.docs) {
          final t = TimetableModel.fromMap(doc.id, doc.data());
          final startTotal = t.startHour * 60 + t.startMinute;
          final endTotal = t.endHour * 60 + t.endMinute;
          if (nowTotalMinutes >= startTotal && nowTotalMinutes < endTotal) {
            activeTeacherId = t.teacherId;
            break;
          }
        }

        // 5. Mark Attendance (passing the teacher ID for Live Routing)
        final userModel = context.read<UserModel?>();
        final studentDetails = {
          'name': userModel?.name ?? 'Unknown',
          'email': userModel?.email ?? 'Unknown',
          'contactNo': userModel?.contactNo ?? 'Unknown',
          ...userModel?.roleData ?? {},
        };

        if (activeTeacherId != null) {
          // A timetable slot matched — notify only that teacher
          await firestore.markAttendance(
            scannedEventId, userId, scanMode,
            notifiedTeacherId: activeTeacherId,
            studentDetails: studentDetails,
          );
        } else {
          // No timetable slot matched — write to ALL teachers as fallback
          // so no check-in is ever silently lost
          final teachersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'teacher')
              .get();

          if (teachersSnapshot.docs.isEmpty) {
            // No teachers at all — still record attendance on the event
            await firestore.markAttendance(
              scannedEventId, userId, scanMode,
              studentDetails: studentDetails,
            );
          } else {
            for (final teacherDoc in teachersSnapshot.docs) {
              await firestore.markAttendance(
                scannedEventId, userId, scanMode,
                notifiedTeacherId: teacherDoc.id,
                studentDetails: studentDetails,
              );
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(scanMode == 'entry' ? Icons.login : Icons.logout, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Successfully Marked ${scanMode.toUpperCase()}!'),
                ],
              ),
              backgroundColor: scanMode == 'entry' ? Colors.green.shade600 : Colors.blue.shade600,
              behavior: SnackBarBehavior.floating,
            )
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Universal Scanner'), 
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), blurRadius: 40, spreadRadius: 5),
                ],
              ),
              child: Container(),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text(
                  'Scan any Event QR Code',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Align QR code within the frame to Automark Entry/Exit',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
