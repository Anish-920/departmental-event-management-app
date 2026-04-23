import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/timetable_model.dart';
import 'package:event_management/services/firestore_service.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  String? _selectedTeacherId;
  String? _selectedTeacherEmail;
  int _selectedDay = 1; // 1 = Monday
  int _startHour = 9;
  int _startMinute = 0;
  int _endHour = 11;
  int _endMinute = 0;
  DateTime? _selectedDate;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  Future<void> _addTimetable(FirestoreService firestore) async {
    if (_selectedTeacherId == null || _selectedTeacherEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a teacher first!')));
      return;
    }

    final t = TimetableModel(
      id: '',
      dayOfWeek: _selectedDay,
      date: _selectedDate != null ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}" : null,
      startHour: _startHour,
      startMinute: _startMinute,
      endHour: _endHour,
      endMinute: _endMinute,
      teacherId: _selectedTeacherId!,
      teacherEmail: _selectedTeacherEmail!,
    );

    await firestore.createTimetable(t);
    setState(() {
      _selectedTeacherId = null;
      _selectedTeacherEmail = null;
      _selectedDate = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timetable Added!')));
    }
  }

  // Helper to fetch teachers to select
  // For MVP: Admin just types the Teacher UID or selects from a simplified query.
  // We'll use a simple text form for now to map it, but ideal UI would be a dropdown of active teachers.

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Weekly Timetable')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Assign Teacher Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedDay,
                        decoration: const InputDecoration(labelText: 'Day of Week'),
                        items: List.generate(7, (index) {
                          return DropdownMenuItem(value: index + 1, child: Text(_days[index]));
                        }),
                        onChanged: (val) => setState(() {
                          _selectedDay = val ?? 1;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                           final date = await showDatePicker(
                             context: context,
                             initialDate: DateTime.now(),
                             firstDate: DateTime.now(),
                             lastDate: DateTime(2030)
                           );
                           if (date != null) {
                             setState(() {
                               _selectedDate = date;
                               _selectedDay = date.weekday; // Sync day of week with the chosen date
                             });
                           }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Specific Date',
                            suffixIcon: _selectedDate != null ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _selectedDate = null)
                            ) : const Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(
                            _selectedDate == null ? 'Every Week' : "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
                            style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _startHour,
                        decoration: const InputDecoration(labelText: 'Start Hour (24h)'),
                        items: List.generate(24, (index) => DropdownMenuItem(value: index, child: Text('${index.toString().padLeft(2, '0')}'))),
                        onChanged: (val) => setState(() => _startHour = val ?? 9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _startMinute,
                        decoration: const InputDecoration(labelText: 'Start Min'),
                        items: List.generate(60, (index) => DropdownMenuItem(value: index, child: Text('${index.toString().padLeft(2, '0')}'))),
                        onChanged: (val) => setState(() => _startMinute = val ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _endHour,
                        decoration: const InputDecoration(labelText: 'End Hour (24h)'),
                        items: List.generate(24, (index) => DropdownMenuItem(value: index, child: Text('${index.toString().padLeft(2, '0')}'))),
                        onChanged: (val) => setState(() => _endHour = val ?? 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _endMinute,
                        decoration: const InputDecoration(labelText: 'End Min'),
                        items: List.generate(60, (index) => DropdownMenuItem(value: index, child: Text('${index.toString().padLeft(2, '0')}'))),
                        onChanged: (val) => setState(() => _endMinute = val ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No registered teachers found in database.', style: TextStyle(color: Colors.red)),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Assign to Registered Teacher'),
                      items: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(data['email'] ?? 'Unknown Email'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selectedDoc = docs.firstWhere((element) => element.id == val);
                          final data = selectedDoc.data() as Map<String, dynamic>;
                          setState(() {
                            _selectedTeacherId = val;
                            _selectedTeacherEmail = data['email'] ?? 'Unknown Email';
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _addTimetable(firestore),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Shift'),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TimetableModel>>(
              stream: firestore.getTimetables(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final timetables = snapshot.data!;
                timetables.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

                if (timetables.isEmpty) {
                  return const Center(child: Text('No timetable entries yet.'));
                }

                return ListView.builder(
                  itemCount: timetables.length,
                  itemBuilder: (context, index) {
                    final t = timetables[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(_days[t.dayOfWeek - 1].substring(0, 3))),
                        title: Text(t.teacherEmail),
                        subtitle: Text('${t.date != null ? "Date: ${t.date} | " : ""}${t.startHour.toString().padLeft(2, '0')}:${t.startMinute.toString().padLeft(2, '0')} - ${t.endHour.toString().padLeft(2, '0')}:${t.endMinute.toString().padLeft(2, '0')}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => firestore.deleteTimetable(t.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
