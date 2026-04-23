import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/services/auth_service.dart';
import 'package:event_management/screens/report_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _currentIndex = 0;
  Set<String> _dismissed = {};

  Future<Set<String>> _loadDismissed(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('dismissedCards').get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<void> _dismissCard(String uid, String cardId) async {
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('dismissedCards')
        .doc(cardId).set({'dismissedAt': FieldValue.serverTimestamp()});
    setState(() => _dismissed.add(cardId));
  }

  Future<void> _clearDismissed(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('dismissedCards').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) batch.delete(d.reference);
    await batch.commit();
    setState(() => _dismissed.clear());
  }

  // ── Shared helpers ──────────────────────────────────────────────────
  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? 'Not specified' : value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
          ],
        )),
      ]),
    );
  }

  Widget _avatar(String name, {double radius = 38}) {
    final initials = name.trim().isEmpty ? '?'
        : name.trim().split(' ').take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFC62828),
      child: Text(initials, style: TextStyle(fontSize: radius * 0.55, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 0: body = _buildMonitoringTab(context); break;
      case 1: body = const ReportScreen(); break;
      case 2: default: body = _buildProfileTab(context); break;
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white, elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFC62828),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: [
            _navItem(Icons.radar, 'Monitoring', 0),
            _navItem(Icons.analytics_rounded, 'Reports', 1),
            _navItem(Icons.person_outline_rounded, 'Profile', 2),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label, int index) {
    final sel = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFC62828).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: sel ? const Color(0xFFC62828) : Colors.grey.shade400),
      ),
      label: label,
    );
  }

  // ── Monitoring Tab ────────────────────────────────────────────────────
  Widget _buildMonitoringTab(BuildContext context) {
    final user = context.read<UserModel?>();
    return Column(children: [
      // ── Gradient Header ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0E1424), Color(0xFF1A2340)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.radar, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Live Monitoring', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Real-time student check-ins', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          if (user != null)
            GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Hide all current notifications?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFC62828)))),
                      ],
                    ));
                if (ok == true) _clearDismissed(user.uid);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.4)),
                ),
                child: const Row(children: [
                  Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFFF8A80)),
                  SizedBox(width: 6),
                  Text('Clear All', style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
        ]),
      ),

      // List
      Expanded(child: user == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Set<String>>(
              future: _loadDismissed(user.uid),
              builder: (context, dimSnap) {
                if (dimSnap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (dimSnap.hasData) _dismissed = {..._dismissed, ...dimSnap.data!};

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collectionGroup('attendance').snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snap.hasError)
                      return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));

                    final docs = (snap.data?.docs ?? [])
                        .where((d) => !_dismissed.contains(d.id))
                        .toList()
                      ..sort((a, b) {
                        final tA = (a.data() as Map)['entryTime'] as Timestamp?;
                        final tB = (b.data() as Map)['entryTime'] as Timestamp?;
                        if (tA == null) return 1;
                        if (tB == null) return -1;
                        return tB.compareTo(tA);
                      });

                    if (docs.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No recent activity detected.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ]));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final studentUserId = data['userId']?.toString() ?? '';
                        final Timestamp? entryTime = data['entryTime'];
                        final Timestamp? exitTime  = data['exitTime'];
                        final entryStr = entryTime != null
                            ? "${entryTime.toDate().hour.toString().padLeft(2,'0')}:${entryTime.toDate().minute.toString().padLeft(2,'0')}" : "--:--";
                        final exitStr  = exitTime  != null
                            ? "${exitTime.toDate().hour.toString().padLeft(2,'0')}:${exitTime.toDate().minute.toString().padLeft(2,'0')}"  : "--:--";
                        final hasExit = exitTime != null;

                        return Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.delete_outline, color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ]),
                          ),
                          confirmDismiss: (_) async => await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: const Text('Hide this check-in notification?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Dismiss', style: TextStyle(color: Color(0xFFC62828)))),
                              ],
                            ),
                          ) ?? false,
                          onDismissed: (_) => _dismissCard(user.uid, doc.id),

                          // ── Fetch real student data from Firestore ──
                          child: FutureBuilder<DocumentSnapshot>(
                            future: studentUserId.isNotEmpty
                                ? FirebaseFirestore.instance.collection('users').doc(studentUserId).get()
                                : null,
                            builder: (context, userSnap) {
                              final ud = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
                              final rd = ud['roleData'] as Map<dynamic, dynamic>? ?? {};

                              // Prefer fresh Firestore data; fall back to stored studentDetails
                              final sd = data['studentDetails'] as Map<dynamic, dynamic>? ?? {};
                              final studentName = (ud['name']?.toString().isNotEmpty == true)
                                  ? ud['name'].toString()
                                  : sd['name']?.toString() ?? 'Unknown';
                              final dept = rd['department']?.toString() ??
                                  sd['department']?.toString() ?? 'N/A';
                              final year = rd['year']?.toString() ??
                                  sd['year']?.toString() ?? '';
                              final contact = ud['contactNo']?.toString() ??
                                  sd['contactNo']?.toString() ?? '';
                              final uidShort = studentUserId.length >= 8
                                  ? studentUserId.substring(0, 8) : studentUserId;
                              final subLine = year.isNotEmpty ? '$dept · Year $year' : dept;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.grey.shade200)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Container(padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                              color: hasExit ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                              shape: BoxShape.circle),
                                          child: Icon(hasExit ? Icons.exit_to_app : Icons.how_to_reg,
                                              color: hasExit ? Colors.orange : Colors.green, size: 22)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(studentName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0E1424))),
                                        const SizedBox(height: 2),
                                        Text('UID: $uidShort', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontFamily: 'monospace')),
                                      ])),
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.grey.shade400, size: 20),
                                        onPressed: () => _dismissCard(user.uid, doc.id),
                                      ),
                                    ]),
                                    const SizedBox(height: 10),

                                    // Department + Contact row
                                    Row(children: [
                                      _chip(Icons.domain, subLine, Colors.indigo),
                                      const SizedBox(width: 8),
                                      if (contact.isNotEmpty) _chip(Icons.phone, contact, Colors.teal),
                                    ]),

                                    const SizedBox(height: 12),
                                    // Entry / Exit bar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          const Text('ENTRY TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                                          const SizedBox(height: 4),
                                          Text(entryStr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.green)),
                                        ]),
                                        Container(height: 28, width: 1, color: Colors.grey.shade300),
                                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                          const Text('EXIT TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                                          const SizedBox(height: 4),
                                          Text(exitStr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
                                              color: hasExit ? Colors.orange : Colors.grey.shade400)),
                                        ]),
                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            )),
    ]);
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Profile Tab ───────────────────────────────────────────────────────
  Widget _buildProfileTab(BuildContext context) {
    final user = context.read<UserModel?>();
    final rd = user?.roleData ?? {};
    final dept        = rd['department']?.toString() ?? '';
    final designation = rd['designation']?.toString() ?? '';
    final name = user?.name ?? '';

    return SingleChildScrollView(
      child: Column(children: [
        // ── Gradient Hero ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0E1424), Color(0xFF1A2340)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(children: [
            _avatar(name, radius: 44),
            const SizedBox(height: 14),
            Text(name.isEmpty ? 'Teacher' : name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(20)),
              child: const Text('TEACHER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 11)),
            ),
          ]),
        ),

        // ── Info Tiles ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(children: [
            _infoTile(Icons.email_outlined,    'Email Address',  user?.email ?? '',    const Color(0xFFC62828)),
            _infoTile(Icons.phone_outlined,    'Contact Number', user?.contactNo ?? '', Colors.teal),
            _infoTile(Icons.domain,            'Department',     dept,                  Colors.indigo),
            _infoTile(Icons.work_outline,      'Designation',    designation,           Colors.orange),
            _infoTile(Icons.fingerprint,       'User ID',
                (user?.uid.length ?? 0) >= 16 ? user!.uid.substring(0, 16) : (user?.uid ?? ''), Colors.purple),
            _infoTile(Icons.verified_outlined, 'Account Status',
                user?.isApproved == true ? 'Approved & Active' : 'Pending Approval',
                user?.isApproved == true ? Colors.green : Colors.orange),
          ]),
        ),

        // ── Logout Button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: GestureDetector(
            onTap: () => context.read<AuthService>().signOut(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFFC62828).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Log Out', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
