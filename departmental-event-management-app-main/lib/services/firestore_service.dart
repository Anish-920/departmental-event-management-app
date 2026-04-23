import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/event_model.dart';
import 'package:event_management/models/user_model.dart';
import 'package:event_management/models/timetable_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Timetable queries
  Stream<List<TimetableModel>> getTimetables() {
    return _db.collection('timetables').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TimetableModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<void> createTimetable(TimetableModel timetable) async {
    await _db.collection('timetables').add(timetable.toMap());
  }

  Future<void> deleteTimetable(String id) async {
    await _db.collection('timetables').doc(id).delete();
  }

  // Get stream of events
  Stream<List<EventModel>> getEvents() {
    return _db.collection('events').orderBy('date').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => EventModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // Create new event
  Future<void> createEvent(EventModel event) async {
    await _db.collection('events').add(event.toMap());
  }

  // Update existing event
  Future<void> updateEvent(EventModel event) async {
    await _db.collection('events').doc(event.id).update(event.toMap());
  }

  // Delete event and all of its subcollections (RSVPs, Attendance)
  Future<void> deleteEvent(String eventId) async {
    // Wipe RSVPs
    final rsvps = await _db.collection('events').doc(eventId).collection('rsvps').get();
    for (var doc in rsvps.docs) {
      await doc.reference.delete();
    }

    // Wipe Attendance
    final attendance = await _db.collection('events').doc(eventId).collection('attendance').get();
    for (var doc in attendance.docs) {
      await doc.reference.delete();
    }

    // Finally delete the event itself
    await _db.collection('events').doc(eventId).delete();
  }

  // Delete user and all of their active footprints
  Future<void> deleteUser(String userId) async {
    // Wipe all of their RSVPs across all events
    final rsvps = await _db.collectionGroup('rsvps').where('userId', isEqualTo: userId).get();
    for (var doc in rsvps.docs) {
      await doc.reference.delete();
    }

    // Delete their user document
    await _db.collection('users').doc(userId).delete();
  }


  // Mark Attendance manually or via QR (checks in or out)
  Future<void> markAttendance(String eventId, String userId, String type, {String? notifiedTeacherId, Map<String, dynamic>? studentDetails}) async {
    final timestamp = FieldValue.serverTimestamp();
    // type == 'entry' or 'exit'
    final data = <String, dynamic>{
      '${type}Time': timestamp,
      'userId': userId,
    };

    if (studentDetails != null) {
      data['studentDetails'] = studentDetails;
    }

    // Keep the overarching event attendance collection updated
    await _db.collection('events').doc(eventId).collection('attendance').doc(userId).set(data, SetOptions(merge: true));

    // Save permanently in the Teacher's own subcollection so it bypasses missing Firestore collectionGroup indexes
    if (notifiedTeacherId != null) {
      final docId = "${eventId}_$userId";
      await _db.collection('users').doc(notifiedTeacherId).collection('notifications').doc(docId).set(data, SetOptions(merge: true));
    }
  }

  // Get specific attendance record 
  Stream<DocumentSnapshot> getAttendance(String eventId, String userId) {
    return _db.collection('events').doc(eventId).collection('attendance').doc(userId).snapshots();
  }
  // RSVP Management for Participants & Organizers
  Future<void> requestToJoinEvent(String eventId, String organizerId, String userId, String email) async {
    await _db.collection('events').doc(eventId).collection('rsvps').doc(userId).set({
      'userId': userId,
      'eventId': eventId,
      'organizerId': organizerId,
      'email': email,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveRSVP(String eventId, String userId) async {
    await _db.collection('events').doc(eventId).collection('rsvps').doc(userId).update({
      'status': 'approved',
    });
  }

  Future<void> rejectRSVP(String eventId, String userId) async {
    await _db.collection('events').doc(eventId).collection('rsvps').doc(userId).delete();
  }

  Stream<DocumentSnapshot> getRSVPStatus(String eventId, String userId) {
    return _db.collection('events').doc(eventId).collection('rsvps').doc(userId).snapshots();
  }

  // Get stream of pending approvals for an organizer
  Stream<QuerySnapshot> getPendingApprovals(String organizerId) {
    return _db.collectionGroup('rsvps')
              .where('organizerId', isEqualTo: organizerId)
              .snapshots();
  }

  // Approve User
  Future<void> approveUser(String userId) async {
    await _db.collection('users').doc(userId).update({'isApproved': true});
  }

  // Promote User
  Future<void> promoteUser(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'role': newRole});
  }

  // Update FCM token
  Future<void> updateToken(String userId, String token) async {
    await _db.collection('users').doc(userId).update({'fcmToken': token});
  }
}
