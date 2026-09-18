import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  AuthService._internal({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth get _auth {
    final auth = _customAuth;
    if (auth != null) return auth;
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    final firestore = _customFirestore;
    if (firestore != null) return firestore;
    return FirebaseFirestore.instance;
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => currentUser?.uid;
  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Initialize anonymous auth on app launch.
  /// If online and no active session, signs in anonymously to establish a background UID.
  /// If offline or Firebase is unreachable, fails gracefully.
  Future<User?> initializeGuestAuth() async {
    try {
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }
      final userCredential = await _auth.signInAnonymously();
      // Ensure user profile document exists in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!, isAnonymous: true);
      }
      return userCredential.user;
    } catch (e) {
      // Graceful degradation when offline or network unavailable
      // ignore: avoid_print
      print('[AuthService] Guest auth deferred (offline mode active): $e');
      return null;
    }
  }

  /// Link existing Anonymous account with Apple credentials.
  /// Merges guest profile into permanent identity with zero data loss.
  Future<UserCredential> linkWithApple() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No active user to link with Apple.');
    }

    final appleProvider = OAuthProvider('apple.com');
    appleProvider.addScope('email');
    appleProvider.addScope('name');

    final userCredential = await user.linkWithProvider(appleProvider);
    await _createUserDocument(userCredential.user!, isAnonymous: false);
    return userCredential;
  }

  /// Link existing Anonymous account with Google credentials.
  Future<UserCredential> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No active user to link with Google.');
    }

    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final userCredential = await user.linkWithProvider(googleProvider);
    await _createUserDocument(userCredential.user!, isAnonymous: false);
    return userCredential;
  }

  /// Link existing Anonymous account with Email & Password credentials.
  /// Preserves the existing Anonymous UID and local offline data in Isar.
  Future<UserCredential> linkWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No active user to link with email and password.');
    }

    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    final userCredential = await user.linkWithCredential(credential);
    if (userCredential.user != null) {
      await _createUserDocument(userCredential.user!, isAnonymous: false);
    }
    return userCredential;
  }

  /// Sign in with existing email and password for returning users.
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (userCredential.user != null) {
      await _createUserDocument(userCredential.user!, isAnonymous: false);
    }
    return userCredential;
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Link with an existing AuthCredential (useful for native SDK credential tokens)
  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No active user to link credentials.');
    }

    final userCredential = await user.linkWithCredential(credential);
    await _createUserDocument(userCredential.user!, isAnonymous: false);
    return userCredential;
  }

  /// App Store Guideline 5.1.1(v) Compliant Account Deletion:
  /// Purges user data from Firestore and deletes the Firebase Auth record.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try {
      // 1. Purge user document and subcollections in Firestore
      final userDoc = _firestore.collection('users').doc(uid);
      final routesSnapshot = await userDoc.collection('routes').get();

      final batch = _firestore.batch();
      for (final doc in routesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(userDoc);
      await batch.commit();

      // 2. Delete user from Firebase Auth
      await user.delete();
    } catch (e) {
      // ignore: avoid_print
      print('[AuthService] Error during account deletion: $e');
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _createUserDocument(User user, {required bool isAnonymous}) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'isAnonymous': isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      print('[AuthService] Note: Firestore profile write deferred: $e');
    }
  }
}
