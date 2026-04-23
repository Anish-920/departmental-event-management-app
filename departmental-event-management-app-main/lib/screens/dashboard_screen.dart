import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/services/auth_service.dart';

import 'admin_dashboard.dart';
import 'organizer_dashboard.dart';
import 'participant_dashboard.dart';

import 'teacher_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!user.isApproved) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.admin_panel_settings, size: 80, color: Colors.orange),
                ),
                const SizedBox(height: 32),
                const Text('Pending Approval', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
                const SizedBox(height: 16),
                Text(
                  'Your ${user.role} account has been registered but must be approved by an Administrator before you can access your dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 48),
                TextButton.icon(
                  onPressed: () => context.read<AuthService>().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget body;
    if (user.role == 'admin') {
      body = const AdminDashboard();
    } else if (user.role == 'organizer') {
      body = const OrganizerDashboard();
    } else if (user.role == 'teacher') {
      body = const TeacherDashboard();
    } else {
      body = const ParticipantDashboard();
    }

    return body;
  }
}
