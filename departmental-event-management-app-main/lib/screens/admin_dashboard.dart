import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/services/firestore_service.dart';
import 'package:event_management/services/auth_service.dart';
import 'package:event_management/screens/admin_timetable_screen.dart';
import 'package:event_management/models/user_model.dart';
import 'package:provider/provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildUsersTab(context);
        break;
      case 1:
        body = _buildApprovalsTab(context);
        break;
      case 2:
        body = const AdminTimetableScreenWrapper(); // Embed the native Screen here
        break;
      case 3:
      default:
        body = _buildProfileTab(context);
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFC62828),
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            _buildNavItem(Icons.people, 'Users', 0),
            _buildNavItem(Icons.domain_verification, 'Approvals', 1),
            _buildNavItem(Icons.calendar_month, 'Timetable', 2),
            _buildNavItem(Icons.person_outline_rounded, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC62828).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: isSelected ? const Color(0xFFC62828) : Colors.grey.shade400),
      ),
      label: label,
    );
  }

  Widget _buildUsersTab(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 24, top: 24, bottom: 8),
          child: Text('User Management', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFF0E1424))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final users = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(24.0),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final data = user.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'participant';
                  final isApproved = data['isApproved'] ?? false;

                  if (!isApproved) return const SizedBox.shrink(); // Hide unapproved users from core directory

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(backgroundColor: const Color(0xFFC62828).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFFC62828))),
                      title: Text(data['email'] ?? 'No Email', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
                      subtitle: Text('Role: ${role.toUpperCase()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: const Color(0xFF0A1128), borderRadius: BorderRadius.circular(8)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: role,
                                dropdownColor: const Color(0xFF0A1128),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                items: const [DropdownMenuItem(value: 'participant', child: Text('Participant')), DropdownMenuItem(value: 'organizer', child: Text('Organizer')), DropdownMenuItem(value: 'teacher', child: Text('Teacher')), DropdownMenuItem(value: 'admin', child: Text('Admin'))],
                                onChanged: (newRole) { if (newRole != null) firestore.promoteUser(user.id, newRole); },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text('Delete User', style: TextStyle(color: Color(0xFF0E1424), fontWeight: FontWeight.bold)),
                                    content: Text('Are you sure you want to permanently delete ${data['email']} and all of their data?', style: TextStyle(color: Colors.grey.shade700)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          try {
                                            await firestore.deleteUser(user.id);
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User completely deleted.')));
                                          } catch (e) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                                          }
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 24, top: 24, bottom: 8),
          child: Text('Approvals Management', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFF0E1424))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allUsers = snapshot.data!.docs;
              final pendingUsers = allUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isApproved'] == false;
              }).toList();

              if (pendingUsers.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending approvals',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24.0),
                itemCount: pendingUsers.length,
                itemBuilder: (context, index) {
                  final user = pendingUsers[index];
                  final data = user.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'Unknown';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(backgroundColor: const Color(0xFFC62828).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFFC62828))),
                      title: Text(data['email'] ?? 'No Email', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
                      subtitle: Text('Role: ${role.toUpperCase()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                try {
                                  await firestore.approveUser(user.id);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User approved successfully.')));
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text('Reject User', style: TextStyle(color: Color(0xFF0E1424), fontWeight: FontWeight.bold)),
                                    content: Text('Are you sure you want to reject registration for ${data['email']}?', style: TextStyle(color: Colors.grey.shade700)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          try {
                                            await firestore.deleteUser(user.id);
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User rejected.')));
                                          } catch (e) {
                                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
                                          }
                                        },
                                        child: const Text('Reject', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(BuildContext context) {
    final user    = context.read<UserModel?>();
    final name    = user?.name ?? '';
    final initials = name.trim().isEmpty ? '?'
        : name.trim().split(' ').take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();

    Widget infoTile(IconData icon, String label, String value, Color color) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? 'Not specified' : value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
          ])),
        ]),
      );
    }

    Widget statTile(IconData icon, String label, Widget valueWidget, Color color) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            valueWidget,
          ])),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(children: [
        CircleAvatar(radius: 40, backgroundColor: const Color(0xFF0E1424),
            child: Text(initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        Text(name.isEmpty ? 'Administrator' : name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text((user?.role ?? 'ADMIN').toUpperCase(),
              style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
        ),
        const SizedBox(height: 24),

        infoTile(Icons.email_outlined,         'Email Address',  user?.email ?? '',    const Color(0xFFC62828)),
        infoTile(Icons.phone_outlined,         'Contact Number', user?.contactNo ?? '', Colors.teal),
        infoTile(Icons.fingerprint,            'User ID',
            (user?.uid.length ?? 0) >= 16 ? user!.uid.substring(0, 16) : (user?.uid ?? ''), Colors.purple),
        infoTile(Icons.admin_panel_settings,   'Admin Level',    'Super Administrator', Colors.deepOrange),
        infoTile(Icons.verified_outlined,      'System Status',  'Active & Running',   Colors.green),

        const SizedBox(height: 8),

        // Live stats
        statTile(Icons.group, 'TOTAL REGISTERED USERS',
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (_, s) => Text('${s.data?.docs.length ?? 0} Users',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
          ), Colors.blue),

        statTile(Icons.event, 'TOTAL EVENTS',
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').snapshots(),
            builder: (_, s) => Text('${s.data?.docs.length ?? 0} Events',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
          ), Colors.indigo),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class AdminTimetableScreenWrapper extends StatelessWidget {
  const AdminTimetableScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminTimetableScreen();
  }
}
