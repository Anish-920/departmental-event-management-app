import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:event_management/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> get user {
    return _auth.authStateChanges().asyncMap((User? firebaseUser) async {
      if (firebaseUser == null) return null;
      DocumentSnapshot doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Future<UserModel?> registerWithEmail({
    required String email, 
    required String password,
    required String name,
    required String contactNo,
    required String role,
    Map<String, dynamic> roleData = const {},
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        // Participants and Admins (if ever allowed via this flow) are approved.
        // Teachers and Organizers must be approved by admin.
        bool isApproved = (role == 'participant' || role == 'admin');

        UserModel newUser = UserModel(
          uid: user.uid, 
          email: email, 
          role: role,
          name: name,
          contactNo: contactNo,
          roleData: roleData,
          isApproved: isApproved,
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
      return null;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      // user will be picked up by stream
      return null;
    } catch (e) {
      print(e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
