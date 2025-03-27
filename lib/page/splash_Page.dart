import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:proswing/core/colors.dart';
import 'package:proswing/core/space.dart';
import 'package:proswing/core/text_style.dart';
import 'package:proswing/page/Home/home_tab.dart';
import 'package:proswing/page/login_page.dart';
import 'package:proswing/widget/main_button.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  _SplashScreenPageState createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkUserAuthStatus();
  }


  void _checkUserAuthStatus() async {
    await Future.delayed(
        const Duration(seconds: 1)); // Simulate splash screen delay

    User? user = FirebaseAuth.instance.currentUser;
    print('Current user: $user'); // Debug line

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenPage()),
      );
    } 
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    const String splashText = """
Elevate your tennis game with AI-powered insights.
Track your performance, get personalized feedback,
and reach new levels of play anytime, anywhere.
""";
    return Scaffold(
      backgroundColor: white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: blackBG,
              child: Image.asset(
                'assets/image/92.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height / 3,
              width: width,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(text: 'proswing', style: headline),
                      TextSpan(text: '.', style: headlineDot),
                    ]),
                  ),
                  const SpaceVH(
                    height: 20.0,
                  ),
                  const Text(
                    splashText,
                    textAlign: TextAlign.center,
                    style: headline2,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: MainButton(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (builder) => const LoginPage())
                            );
                      },
                      btnColor: greenButton,
                      text: 'Get Started',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
