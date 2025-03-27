import 'package:firebase_auth/firebase_auth.dart';

class UserAuthentication {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // For Sign-up
  Future<Map<String, dynamic>> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return {'user': credential.user, 'message': 'Sign-up successful'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'The email address is already in use by another account.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'An unknown error occurred.';
      }
      return {'user': null, 'message': errorMessage};
    } catch (e) {
      return {
        'user': null,
        'message': 'An error occurred. Please try again later.'
      };
    }
  }

  
  // For Sign-in
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return {'user': credential.user, 'message': 'Login successful'};
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'The user account has been disabled.';
          break;
        default:
          errorMessage = 'Wrong email or password';
      }
      return {'user': null, 'message': errorMessage};
    } catch (e) {
      return {
        'user': null,
        'message': 'An error occurred. Please try again later.'
      };
    }
  }
}
