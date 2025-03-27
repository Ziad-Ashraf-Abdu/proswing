import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proswing/core/colors.dart';
import 'package:proswing/core/show_message.dart';
import 'package:proswing/core/space.dart';
import 'package:proswing/core/text_style.dart';
import 'package:proswing/page/Home/home_tab.dart';
import 'package:proswing/page/sign_up.dart';
import 'package:proswing/services/google_auth_service.dart';
import 'package:proswing/services/user_auth.dart';
import 'package:proswing/widget/main_button.dart';
import 'package:proswing/widget/text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController userPass = TextEditingController();
  TextEditingController userEmail = TextEditingController();
  bool _isPasswordVisible = false;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final UserAuthentication _auth = UserAuthentication();

  @override
  void dispose() {
    super.dispose();
    userPass.dispose();
    userEmail.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkUserAuthStatus();
  }

  void _checkUserAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1)); // Splash screen delay
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      //await _navigateBasedOnRole(user);
    }
  }

  // Function to handle role-based navigation
  Future<void> _navigateBasedOnRole(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        String? role = userData?['userType'];

        // if (role == 'coach') {
        //   Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(builder: (context) => const CoachHomeScreen()),
        //   );
        // } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreenPage()),
        );
        // }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
      }
    } catch (e) {
      await showMessage(context,
          'Error retrieving user data. Please try again.', false, false);
    }
  }

  // Email/Password sign-in method
  void _signIn() async {
    String email = userEmail.text;
    String password = userPass.text;

    Map<String, dynamic> result =
        await _auth.signInWithEmailAndPassword(email, password);
    String message = result['message'];
    User? user = result['user'];

    if (user != null) {
      await _navigateBasedOnRole(user);
    } else {
      await showMessage(context, message, false, false);
    }
  }

  // Google sign-in method
  Future<void> _signInWithGoogle() async {
    final UserCredential? result = await _googleAuthService.signInWithGoogle();
    User? user = result?.user;

    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        await _navigateBasedOnRole(user);
      } else {
        // If new Google user, redirect to complete profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
      }
    } else {
      await showMessage(
          context, 'Google sign-in failed. Please try again.', false, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBG,
      body: Padding(
        padding: const EdgeInsets.only(top: 50.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SpaceVH(height: 50.0),
              const Text('Welcome Back', style: headline1),
              const SpaceVH(height: 10.0),
              const Text('Please sign in to continue', style: headline3),
              const SpaceVH(height: 60.0),
              textField(
                controller: userEmail,
                keyBordType: TextInputType.emailAddress,
                image: 'user.svg',
                hintTxt: 'Email Address',
              ),
              textField(
                controller: userPass,
                isObs: !_isPasswordVisible,
                image: _isPasswordVisible ? 'visibility.svg' : 'hide.svg',
                hintTxt: 'Password',
                onIconTap: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              const SpaceVH(height: 80.0),
              MainButton(
                onTap: _signIn,
                text: 'Sign In',
                btnColor: greenButton,
              ),
              const SpaceVH(height: 20.0),
              MainButton(
                onTap: _signInWithGoogle,
                text: 'Sign in with Google',
                image: 'google.png',
                btnColor: white,
                txtColor: blackBG,
              ),
              const SpaceVH(height: 20.0),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                  );
                },
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Don\'t have an account? ',
                      style: headline.copyWith(fontSize: 14.0),
                    ),
                    TextSpan(
                      text: 'Sign Up',
                      style: headlineDot.copyWith(fontSize: 14.0),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
