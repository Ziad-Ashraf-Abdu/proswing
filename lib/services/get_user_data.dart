import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Function to fetch user data from Firestore
Future<Map<String, dynamic>?> getUserData() async {
  try {
    User? currentUser = FirebaseAuth.instance.currentUser; // Get the current user

    if (currentUser == null) {
      print("❌ No user signed in");
      return null;
    }

    print("✅ Fetching data for user: ${currentUser.uid}");

    DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc.data() != null) {
      print("✅ User data found: ${userDoc.data()}");
      return userDoc.data();
    } else {
      print("⚠️ User data not found in Firestore");
      return null;
    }
  } catch (e) {
    print("❌ Error fetching user data: $e");
    return null;
  }
}