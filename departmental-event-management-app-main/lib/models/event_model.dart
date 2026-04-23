import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String organizerId;
  final String venue;
  final String organizersName;
  final String prizePool;
  final String fees;
  final List<String> tags;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.organizerId,
    required this.venue,
    required this.organizersName,
    required this.prizePool,
    required this.fees,
    this.tags = const [],
  });

  factory EventModel.fromMap(Map<String, dynamic> map, String docId) {
    return EventModel(
      id: docId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      organizerId: map['organizerId'] ?? '',
      venue: map['venue'] ?? 'TBA',
      organizersName: map['organizersName'] ?? 'Unknown Organizer',
      prizePool: map['prizePool'] ?? 'None',
      fees: map['fees'] ?? 'Free',
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'organizerId': organizerId,
      'venue': venue,
      'organizersName': organizersName,
      'prizePool': prizePool,
      'fees': fees,
      'tags': tags,
    };
  }
}
