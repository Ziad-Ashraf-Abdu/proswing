import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proswing/core/colors.dart';
import 'package:proswing/core/show_message.dart';
import 'package:proswing/core/space.dart';
import 'package:proswing/core/text_style.dart';
import 'package:proswing/page/Home/home_tab.dart';
import 'package:proswing/services/user_auth.dart';
import 'package:proswing/widget/main_button.dart';
import 'package:proswing/widget/text_field.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final UserAuthentication _auth = UserAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Text controllers
  TextEditingController userName = TextEditingController();
  TextEditingController userPass = TextEditingController();
  TextEditingController userEmail = TextEditingController();
  TextEditingController userPh = TextEditingController();
  String? selectedGender;
  TextEditingController userHeight = TextEditingController();
  TextEditingController userWeight = TextEditingController();

  bool _isPasswordVisible = false;
  String userType = 'athlete'; // Directly setting userType to 'athlete'

  @override
  void dispose() {
    userName.dispose();
    userPass.dispose();
    userEmail.dispose();
    userPh.dispose();
    userHeight.dispose();
    userWeight.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkUserAuthStatus();
  }

  void _checkUserAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1));
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenPage()),
      );
    }
  }

  // Sign-up form
  Widget _buildSignUpForm() {
    return Column(
      children: [
        const Text(
          'Create new Athlete account',
          style: headline1,
        ),
        const SpaceVH(height: 10.0),
        const Text(
          'Please fill in the form to continue',
          style: headline3,
        ),
        const SpaceVH(height: 40.0),
        textField(
          controller: userName,
          image: 'user.svg',
          keyBordType: TextInputType.name,
          hintTxt: 'Full Name',
        ),
        textField(
          controller: userEmail,
          keyBordType: TextInputType.emailAddress,
          image: 'user.svg',
          hintTxt: 'Email Address',
        ),
        textField(
          controller: userPh,
          image: 'user.svg',
          keyBordType: TextInputType.phone,
          hintTxt: 'Phone Number',
        ),
        const SpaceVH(height: 20.0),
        // Gender Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: blackTextFild,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              labelText: 'Select Gender',
            ),
            value: selectedGender,
            dropdownColor: blackTextFild,
            style: const TextStyle(color: Colors.white),
            items: ['Male', 'Female'].map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                selectedGender = newValue;
              });
            },
          ),
        ),
        const SpaceVH(height: 20.0),
        // Height and Weight fields (for athlete)
        textField(
          controller: userHeight,
          image: 'user.svg',
          keyBordType: TextInputType.number,
          hintTxt: 'Height (cm)',
        ),
        textField(
          controller: userWeight,
          image: 'user.svg',
          keyBordType: TextInputType.number,
          hintTxt: 'Weight (kg)',
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
        const SpaceVH(height: 30.0),
        MainButton(
          onTap: _signUp,
          text: 'Sign Up',
          btnColor: greenButton,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBG,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildSignUpForm(),
          ),
        ),
      ),
    );
  }

  void _signUp() async {
    try {
      String email = userEmail.text;
      String password = userPass.text;
      String name = userName.text;
      String phone = userPh.text;
      String gender = selectedGender ?? '';
      int? height = int.tryParse(userHeight.text);
      int? weight = int.tryParse(userWeight.text);

      Map<String, dynamic> result =
          await _auth.signUpWithEmailAndPassword(email, password);

      String message = result['message'];
      User? user = result['user'];

      await showMessage(context, message, user != null, false);

      if (user != null) {
        await user.updateDisplayName(name);
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'gender': gender,
          'height': height,
          'weight': weight,
          'userType': userType,
          'createdAt': FieldValue.serverTimestamp(),
        });

        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const HomeScreenPage()));
      }
    } catch (e) {
      await showMessage(
          context, 'Failed to sign up. Please try again.', false, false);
    }
  }
}
