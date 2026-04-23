import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/event_model.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/services/firestore_service.dart';
import 'package:event_management/services/auth_service.dart';
import 'qr_generator_screen.dart';
import 'package:intl/intl.dart';

class OrganizerDashboard extends StatefulWidget {
  const OrganizerDashboard({super.key});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  final Set<String> _listeningEvents = {};

  Future<void> _showParticipantsModal(BuildContext context, String eventId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Approved Participants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('events').doc(eventId).collection('rsvps').where('status', isEqualTo: 'approved').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final participants = snapshot.data!.docs;

                    if (participants.isEmpty) {
                      return Center(child: Text('No approved participants yet.', style: TextStyle(color: Colors.grey.shade600)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final data = participants[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: const Color(0xFFF7F8FA),
                          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: const Color(0xFF0E1424), child: const Icon(Icons.person, color: Colors.white)),
                            title: Text(data['email'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
                            subtitle: Text('Status: Approved', style: TextStyle(color: Colors.green.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _listenForAttendance(BuildContext context, String eventId) {
    if (_listeningEvents.contains(eventId)) return;
    _listeningEvents.add(eventId);

    final messenger = ScaffoldMessenger.of(context);

    FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('attendance')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc.data();
            if (doc != null && doc.containsKey('userId')) {
               if (mounted) {
                 messenger.showSnackBar(
                   SnackBar(
                     content: Row(
                       children: [
                         const Icon(Icons.check_circle, color: Colors.white),
                         const SizedBox(width: 12),
                         Expanded(child: Text('Student checked in! (ID: ${doc['userId'].toString().substring(0, 5)})')),
                       ],
                     ),
                     behavior: SnackBarBehavior.floating,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     backgroundColor: Colors.green.shade600,
                     duration: const Duration(seconds: 3),
                   )
                 );
               }
            }
          }
        }
      }
    });
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final user = context.read<UserModel?>();

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildApprovalsTab(context, firestore, user);
        break;
      case 1:
        body = _buildEventsTab(context, firestore, user);
        break;
      case 2:
      default:
        body = _buildProfileTab(context, firestore, user);
        break;
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          _buildNavItem(Icons.people, 'Approvals', 0),
          _buildNavItem(Icons.event, 'My Events', 1),
          _buildNavItem(Icons.person_outline_rounded, 'Profile', 2),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: Icon(icon),
      label: label,
    );
  }

  Widget _buildApprovalsTab(BuildContext context, FirestoreService firestore, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: user == null ? const Center(child: CircularProgressIndicator()) : 
        StreamBuilder<QuerySnapshot>(
          stream: firestore.getPendingApprovals(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Database Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
            
            int count = 0;
            List<QueryDocumentSnapshot> docs = [];
            if (snapshot.hasData) {
              docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'pending';
              }).toList();
              count = docs.length;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Approvals ($count)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (count == 0)
                  const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No pending requests.', style: TextStyle(color: Colors.grey, fontSize: 16))))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: count,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildApprovalCard(context, firestore, data['eventId'] ?? '', data['userId'] ?? '', data['email'] ?? 'Unknown User', data['timestamp'] as Timestamp?);
                    },
                  ),
              ],
            );
          }
        ),
    );
  }

  Widget _buildEventsTab(BuildContext context, FirestoreService firestore, UserModel? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Hosted Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0E1424))),
              IconButton(onPressed: () => _createOrUpdateEventModal(context, user!.uid, firestore), icon: const Icon(Icons.add_circle, color: Color(0xFFC62828), size: 32))
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<EventModel>>(
            stream: firestore.getEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final events = snapshot.data!.where((e) => e.organizerId == user?.uid).toList();
              if (events.isEmpty) return const Center(child: Text('No events created yet.', style: TextStyle(color: Colors.grey, fontSize: 16)));
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  _listenForAttendance(context, event.id);
                  return _buildPremiumEventCard(context, event, firestore, index);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, FirestoreService firestore, UserModel? user) {
    final rd          = user?.roleData ?? {};
    final dept        = rd['department']?.toString() ?? '';
    final designation = rd['designation']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.person), title: const Text('Name'), subtitle: Text(user?.name ?? 'N/A')),
        ListTile(leading: const Icon(Icons.email), title: const Text('Email'), subtitle: Text(user?.email ?? 'N/A')),
        ListTile(leading: const Icon(Icons.phone), title: const Text('Contact'), subtitle: Text(user?.contactNo ?? 'N/A')),
        ListTile(leading: const Icon(Icons.domain), title: const Text('Department'), subtitle: Text(dept.isEmpty ? 'N/A' : dept)),
        ListTile(leading: const Icon(Icons.work), title: const Text('Designation'), subtitle: Text(designation.isEmpty ? 'N/A' : designation)),
        ListTile(leading: const Icon(Icons.badge), title: const Text('Role'), subtitle: Text(user?.role ?? 'Organizer')),
        ListTile(
          leading: const Icon(Icons.event),
          title: const Text('Events Hosted'),
          subtitle: StreamBuilder<List<EventModel>>(
            stream: firestore.getEvents(),
            builder: (context, snap) {
              final count = snap.data?.where((e) => e.organizerId == user?.uid).length ?? 0;
              return Text('$count events');
            },
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
        ),
      ]),
    );
  }
  Widget _buildApprovalCard(BuildContext context, FirestoreService firestore, String eventId, String userId, String email, Timestamp? timestamp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await firestore.approveRSVP(eventId, userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participant approved!')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await firestore.rejectRSVP(eventId, userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participant rejected.')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumEventCard(BuildContext context, EventModel event, FirestoreService firestore, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('MMM dd, yyyy - h:mm a').format(event.date)}'),
            Text('Venue: ${event.venue}'),
            Text('Fees: ${event.fees}'),
            if (event.prizePool != 'None' && event.prizePool.isNotEmpty)
              Text('Prize: ${event.prizePool}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showParticipantsModal(context, event.id),
              icon: const Icon(Icons.people),
              label: const Text('View Participants'),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _createOrUpdateEventModal(context, event.organizerId, firestore, existingEvent: event),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, event, firestore),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                Builder(
                  builder: (context) {
                    final now = DateTime.now();
                    final hasStarted = now.isAfter(event.date) || now.isAtSameMomentAs(event.date);
                    return IconButton(
                      onPressed: hasStarted ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => QRGeneratorScreen(eventId: event.id)));
                      } : () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code is locked until the event starts.')));
                      },
                      icon: Icon(hasStarted ? Icons.qr_code_2 : Icons.lock_clock),
                      tooltip: hasStarted ? 'Generate Check-in QR' : 'Locked until event start',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, EventModel event, FirestoreService firestore) {
    // Standard delete dialog implementation...
     showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Delete Event', style: TextStyle(color: Color(0xFF0E1424), fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${event.title}"? This cannot be undone.', style: TextStyle(color: Colors.grey.shade700)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
              onPressed: () async {
                await firestore.deleteEvent(event.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      }
    );
  }

  void _createOrUpdateEventModal(BuildContext context, String organizerId, FirestoreService firestore, {EventModel? existingEvent}) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
         // Placeholder for the form
        return _EventFormSheet(organizerId: organizerId, firestore: firestore, existingEvent: existingEvent);
      }
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  final String organizerId;
  final FirestoreService firestore;
  final EventModel? existingEvent;

  const _EventFormSheet({required this.organizerId, required this.firestore, this.existingEvent});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _organizersNameCtrl;
  late TextEditingController _prizePoolCtrl;
  late TextEditingController _feesCtrl;
  late TextEditingController _tagsCtrl;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingEvent?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existingEvent?.description ?? '');
    _venueCtrl = TextEditingController(text: widget.existingEvent?.venue ?? '');
    _organizersNameCtrl = TextEditingController(text: widget.existingEvent?.organizersName ?? '');
    _prizePoolCtrl = TextEditingController(text: widget.existingEvent?.prizePool ?? '');
    _feesCtrl = TextEditingController(text: widget.existingEvent?.fees ?? '');
    _tagsCtrl = TextEditingController(text: widget.existingEvent?.tags.join(', ') ?? '');
    _selectedDate = widget.existingEvent?.date ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _organizersNameCtrl.dispose();
    _prizePoolCtrl.dispose();
    _feesCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0E1424)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty) return;

    final isUpdate = widget.existingEvent != null;
    final event = EventModel(
      id: isUpdate ? widget.existingEvent!.id : '', 
      title: _titleCtrl.text, 
      description: _descCtrl.text, 
      date: _selectedDate, 
      organizerId: widget.organizerId,
      venue: _venueCtrl.text.isEmpty ? 'TBA' : _venueCtrl.text,
      organizersName: _organizersNameCtrl.text.isEmpty ? 'TBA' : _organizersNameCtrl.text,
      prizePool: _prizePoolCtrl.text.isEmpty ? 'None' : _prizePoolCtrl.text,
      fees: _feesCtrl.text.isEmpty ? 'Free' : _feesCtrl.text,
      tags: _tagsCtrl.text.isEmpty ? [] : _tagsCtrl.text.split(',').map((e) => e.trim()).toList(),
    );

    if (isUpdate) {
      await widget.firestore.updateEvent(event);
    } else {
      await widget.firestore.createEvent(event);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existingEvent != null ? 'Update Event' : 'Create New Event', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0E1424))),
            const SizedBox(height: 24),
            TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Event Title *')),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _venueCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Venue'))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _organizersNameCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Organizers Name'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _prizePoolCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Prize Pool'))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _feesCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Entry Fees'))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _tagsCtrl, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(labelText: 'Tags (comma separated, e.g. Coding, Fun)')),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Event Date & Time', style: TextStyle(color: Colors.black54)),
              subtitle: Text(DateFormat('EEEE, MMM d, yyyy • h:mm a').format(_selectedDate), style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month, color: Color(0xFF0E1424)),
                onPressed: _pickDateTime,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submit, 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A1128)),
                child: Text(widget.existingEvent != null ? 'Save Changes' : 'Publish Event', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
