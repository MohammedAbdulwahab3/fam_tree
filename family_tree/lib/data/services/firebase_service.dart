import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:family_tree/firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Initialize Firebase services
class FirebaseService {
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  /// Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable Firestore offline persistence (not supported on web)
    if (!kIsWeb) {
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  }

  /// Get current user ID
  static String? get currentUserId => auth.currentUser?.uid;

  /// Check if user is authenticated
  static bool get isAuthenticated => auth.currentUser != null;
}
