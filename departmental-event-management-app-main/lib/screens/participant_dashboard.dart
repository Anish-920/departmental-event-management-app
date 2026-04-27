import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/event_model.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/services/firestore_service.dart';
import 'package:event_management/services/auth_service.dart';
import 'qr_scanner_screen.dart';
import 'package:intl/intl.dart';

class ParticipantDashboard extends StatefulWidget {
  const ParticipantDashboard({super.key});

  @override
  State<ParticipantDashboard> createState() => _ParticipantDashboardState();
}

class _ParticipantDashboardState extends State<ParticipantDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Navigation routing for the body
    Widget body;
    switch (_currentIndex) {
      case 0:
        body = const _HomeTab();
        break;
      case 1:
        body = const _EventsTab();
        break;
      case 2:
        body = const _ScanningTab();
        break;
      case 3:
      default:
        body = const _ProfileTab();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
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
            _buildNavItem(Icons.grid_view_rounded, 'Home', 0),
            _buildNavItem(Icons.calendar_today_rounded, 'Events', 1),
            _buildNavItem(Icons.qr_code_scanner_rounded, 'Scanning', 2),
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
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Departmental\nEngagement',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0E1424), height: 1.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quarterly event participation across faculties',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Faculty tags
          Row(
            children: [
              _buildTag('ART'), _buildTag('STEM'), _buildTag('LAW'), _buildTag('MED'), _buildTag('EDU'),
            ],
          ),
          const SizedBox(height: 32),

          // Snapshot Dark Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1128),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0A1128).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('S N A P S H O T', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('142', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                const Text('Active Event Proposals', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                const Text('2.8k', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                const Text('Student RSVP Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Generate Report', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Active Faculty Events Header
          const Text('Active Faculty Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
          const SizedBox(height: 16),

          // Events List
          StreamBuilder<List<EventModel>>(
            stream: firestore.getEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final events = snapshot.data!.where((e) => e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
              if (events.isEmpty) {
                return const Center(child: Text('No events found.', style: TextStyle(color: Colors.grey)));
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildPremiumEventCard(context, events[index], index);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
    );
  }

  Widget _buildPremiumEventCard(BuildContext context, EventModel event, int index, {bool showAction = false}) {
    // Generate a mockup image background gradient
    final gradients = [
      const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];
    final grad = gradients[index % gradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image (Mocked)
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: grad,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('UPCOMING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0E1424)))),
                    if (event.prizePool != 'None')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(event.prizePool, style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('PRIZE POOL', style: TextStyle(color: Colors.grey.shade500, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      )
                    else 
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(event.fees, style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('ENTRY FEE', style: TextStyle(color: Colors.grey.shade500, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${event.venue} • ${DateFormat('MMM d, h:mm a').format(event.date)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Organized by: ${event.organizersName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                if (showAction)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A1128),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                      label: const Text('Scan to Join Event', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mock avatars
                      Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: Colors.blue.shade200, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                          Transform.translate(offset: const Offset(-8, 0), child: CircleAvatar(radius: 12, backgroundColor: Colors.green.shade200, child: const Icon(Icons.person, size: 16, color: Colors.white))),
                          Transform.translate(offset: const Offset(-16, 0), child: CircleAvatar(radius: 12, backgroundColor: Colors.orange.shade200, child: const Icon(Icons.person, size: 16, color: Colors.white))),
                        ],
                      ),
                      const Text('View Analytics', style: TextStyle(color: Color(0xFFC62828), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  // Sort events so that participated events are at the top
  Future<List<EventModel>> _sortEventsByParticipation(List<EventModel> events, String userId) async {
    final db = FirebaseFirestore.instance;
    List<EventModel> participated = [];
    List<EventModel> others = [];

    for (var event in events) {
      // Point read - extremely fast and requires no composite database indexes
      final doc = await db.collection('events').doc(event.id).collection('attendance').doc(userId).get();
      if (doc.exists) {
        participated.add(event);
      } else {
        others.add(event);
      }
    }
    return [...participated, ...others];
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final user = context.watch<UserModel?>();
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 8),
          child: Text('All Events', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Discover and join events hosted across all departments. Events you have participated in appear at the top.', style: TextStyle(fontSize: 14, color: Colors.black54)),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<EventModel>>(
            stream: firestore.getEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final events = snapshot.data!.where((e) => e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
              
              if (events.isEmpty) {
                return const Center(child: Text('No upcoming events found.', style: TextStyle(color: Colors.grey)));
              }
              
              if (user == null) return const Center(child: CircularProgressIndicator());

              return FutureBuilder<List<EventModel>>(
                future: _sortEventsByParticipation(events, user.uid),
                builder: (context, sortedSnapshot) {
                  if (!sortedSnapshot.hasData) {
                     return const Center(child: CircularProgressIndicator());
                  }

                  final sortedEvents = sortedSnapshot.data!;

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 350, // Limits how wide a card can get
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85, // Adjust for nice card proportions
                    ),
                    itemCount: sortedEvents.length,
                    itemBuilder: (context, index) {
                      return _EventCardWidget(event: sortedEvents[index], idx: index, showAction: true);
                    },
                  );
                }
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventCardWidget extends StatelessWidget {
  final EventModel event;
  final int idx;
  final bool showAction;
  
  const _EventCardWidget({required this.event, required this.idx, required this.showAction});

  @override
  Widget build(BuildContext context) {
    final gradients = [
      const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];
    final grad = gradients[idx % gradients.length];
    final firestore = context.read<FirestoreService>();
    final user = context.watch<UserModel?>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: grad,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(12),
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(6)),
              child: const Text('UPCOMING', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(child: Text(DateFormat('MMM d, h:mm a').format(event.date), overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 10))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.venue, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 10))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(event.fees, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      if (event.prizePool != 'None' && event.prizePool.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('Prize: ${event.prizePool}', style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (event.tags.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: event.tags.map((tag) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: Text(tag, style: TextStyle(fontSize: 9, color: Colors.grey.shade800)),
                        )).toList(),
                      ),
                    ),
                  const Spacer(),
                  if (showAction && user != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: firestore.getRSVPStatus(event.id, user.uid),
                      builder: (context, snapshot) {
                        String status = 'none';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          status = (snapshot.data!.data() as Map<String, dynamic>)['status'] ?? 'pending';
                        }
                        
                        // Default state
                        Color btnColor = const Color(0xFF0A1128);
                        String btnText = 'Join';
                        VoidCallback? onPressed = () async {
                          try {
                            await firestore.requestToJoinEvent(event.id, event.organizerId, user.uid, user.email);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent successfully!')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining: $e')));
                            }
                          }
                        };

                        if (status == 'pending') {
                          btnColor = Colors.orange;
                          btnText = 'Pending Info';
                          onPressed = null;
                        } else if (status == 'approved') {
                          btnColor = Colors.green;
                          btnText = 'Joined';
                          onPressed = null; // Can't join again
                        }

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: btnColor,
                              disabledBackgroundColor: btnColor.withOpacity(0.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 0),
                              minimumSize: const Size(double.infinity, 36)
                            ),
                            child: Text(btnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        );
                      }
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ScanningTab extends StatelessWidget {
  const _ScanningTab();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Gradient Hero ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E1424), Color(0xFF1A2340)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Event Check-In', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Scan the QR code at the event entrance to mark your attendance', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.65))),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Main Action Card ──
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFC62828), Color(0xFFE53935)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFFC62828).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Row(children: [
                    Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Open Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Tap to open camera and scan QR', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    ])),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 28),

              // ── How it works ──
              const Text('HOW IT WORKS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              ...[
                ('1', Icons.event_available_rounded, 'Get Approved', 'Request to join an event and wait for organizer approval', Colors.indigo),
                ('2', Icons.qr_code_rounded,          'Find the QR Code', 'At the event, locate the QR code at the entrance', Colors.teal),
                ('3', Icons.check_circle_rounded,      'Scan & Confirm', 'Scan with this app — your attendance is recorded instantly', Colors.green),
              ].map((step) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: (step.$5 as Color).withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(step.$2 as IconData, color: step.$5 as Color, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step.$3 as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0E1424))),
                    const SizedBox(height: 2),
                    Text(step.$5 == Colors.indigo ? 'Request to join an event and wait for organizer approval'
                        : step.$5 == Colors.teal ? 'At the event, locate the QR code at the entrance'
                        : 'Scan with this app — your attendance is recorded instantly',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ])),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final rd   = user?.roleData ?? {};
    final dept = rd['department']?.toString() ?? '';
    final year = rd['year']?.toString() ?? '';
    final name = user?.name ?? '';
    final initials = name.trim().isEmpty ? '?'
        : name.trim().split(' ').take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(children: [
        // Avatar
        CircleAvatar(radius: 40, backgroundColor: const Color(0xFF0E1424),
            child: Text(initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        Text(name.isEmpty ? 'Participant' : name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text((user?.role ?? 'PARTICIPANT').toUpperCase(),
              style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
        ),

        const SizedBox(height: 24),

        // Info tiles
        _infoTile(Icons.email_outlined,   'Email Address',  user?.email ?? '',       const Color(0xFFC62828)),
        _infoTile(Icons.phone_outlined,   'Contact Number', user?.contactNo ?? '',   Colors.teal),
        _infoTile(Icons.domain,           'Department',     dept,                     Colors.indigo),
        _infoTile(Icons.school_outlined,  'Year / Batch',   year,                     Colors.orange),
        _infoTile(Icons.fingerprint,      'User ID',
            (user?.uid.length ?? 0) >= 16 ? user!.uid.substring(0, 16) : (user?.uid ?? ''), Colors.purple),
        _infoTile(Icons.verified_outlined, 'Account Status',
            user?.isApproved == true ? 'Approved & Active' : 'Pending Approval',
            user?.isApproved == true ? Colors.green : Colors.orange),

        const SizedBox(height: 20),
        // Joining history
        Align(alignment: Alignment.centerLeft,
            child: Text('Joining History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0E1424)))),
        const SizedBox(height: 10),

        user == null
          ? const SizedBox()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup('rsvps').where('userId', isEqualTo: user.uid).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final history = snap.data!.docs;
                if (history.isEmpty) return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No joining history yet.', style: TextStyle(color: Colors.grey.shade500)),
                );
                return ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    final data = history[i].data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'pending';
                    final color = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange;
                    return Card(
                      elevation: 0, margin: const EdgeInsets.only(bottom: 8), color: Colors.white,
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.history, color: Color(0xFF0E1424)),
                        title: const Text('Event RSVP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0E1424))),
                        subtitle: Text(data['eventId'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

        const SizedBox(height: 24),
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
