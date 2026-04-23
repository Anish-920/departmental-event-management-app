class UserModel {
  final String uid;
  final String email;
  final String role; // 'admin', 'organizer', 'teacher', 'participant'
  final String fcmToken;
  final String name;
  final String contactNo;
  final Map<String, dynamic> roleData;
  final bool isApproved;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.fcmToken = '',
    this.name = '',
    this.contactNo = '',
    this.roleData = const {},
    this.isApproved = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: map['email'] ?? '',
      role: map['role'] ?? 'participant',
      fcmToken: map['fcmToken'] ?? '',
      name: map['name'] ?? '',
      contactNo: map['contactNo'] ?? '',
      roleData: map['roleData'] != null ? Map<String, dynamic>.from(map['roleData']) : {},
      isApproved: map['isApproved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'fcmToken': fcmToken,
      'name': name,
      'contactNo': contactNo,
      'roleData': roleData,
      'isApproved': isApproved,
    };
  }
}
