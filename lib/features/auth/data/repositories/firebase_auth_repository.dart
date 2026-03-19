import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/entities/user_profile.dart';
import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  const FirebaseAuthRepository(this._firebaseAuth, this._firestore);

  DocumentReference<Map<String, dynamic>> _userProfileRef(String uid) {
    return _firestore.collection('user_profiles').doc(uid);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return AppUser(id: user.uid, email: user.email);
    });
  }

  @override
  Future<void> login({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String learningLanguage,
    required String displayName,
    String? profileImageUrl,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        if ((profileImageUrl ?? '').trim().isNotEmpty) {
          await user.updatePhotoURL(profileImageUrl!.trim());
        }

        try {
          await _userProfileRef(user.uid).set({
            'learningLanguage': learningLanguage,
            'email': user.email,
            'displayName': displayName,
            'profileImageUrl': profileImageUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // Ignore transient profile write failures; auth account already exists.
        }
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  @override
  Future<String?> getLearningLanguage() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _userProfileRef(user.uid).get();
      final data = doc.data();
      return data?['learningLanguage']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLearningLanguage(String languageCode) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      await _userProfileRef(user.uid).set({
        'learningLanguage': languageCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep app usable offline / during Firestore transient failures.
    }
  }

  @override
  Future<UserProfile> getCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const UserProfile(displayName: 'Learner', learningLanguage: 'fr');
    }

    try {
      final doc = await _userProfileRef(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      return UserProfile(
        displayName:
            (data['displayName']?.toString().trim().isNotEmpty ?? false)
                ? data['displayName'].toString()
                : (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!
                : 'Learner',
        profileImageUrl:
            (data['profileImageUrl']?.toString().trim().isNotEmpty ?? false)
                ? data['profileImageUrl'].toString()
                : (user.photoURL?.trim().isNotEmpty ?? false)
                ? user.photoURL
                : null,
        learningLanguage:
            (data['learningLanguage']?.toString().trim().isNotEmpty ?? false)
                ? data['learningLanguage'].toString()
                : 'fr',
      );
    } catch (_) {
      return UserProfile(
        displayName:
            (user.displayName?.trim().isNotEmpty ?? false)
                ? user.displayName!
                : 'Learner',
        profileImageUrl: user.photoURL,
        learningLanguage: 'fr',
      );
    }
  }

  @override
  Future<void> logout() {
    return _firebaseAuth.signOut();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email format is invalid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
