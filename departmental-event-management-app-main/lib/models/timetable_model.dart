class TimetableModel {
  final String id;
  final int dayOfWeek; // 1 = Mon ... 7 = Sun
  final String? date; // Optional date in YYYY-MM-DD
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String teacherId;
  final String teacherEmail; // for display UI

  TimetableModel({
    required this.id,
    required this.dayOfWeek,
    this.date,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    required this.teacherId,
    required this.teacherEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'date': date,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'teacherId': teacherId,
      'teacherEmail': teacherEmail,
    };
  }

  factory TimetableModel.fromMap(String documentId, Map<String, dynamic> data) {
    return TimetableModel(
      id: documentId,
      dayOfWeek: data['dayOfWeek'] ?? 1,
      date: data['date'] as String?,
      startHour: data['startHour'] ?? 0,
      startMinute: data['startMinute'] ?? 0,
      endHour: data['endHour'] ?? 23,
      endMinute: data['endMinute'] ?? 0,
      teacherId: data['teacherId'] ?? '',
      teacherEmail: data['teacherEmail'] ?? 'Unknown',
    );
  }
}
