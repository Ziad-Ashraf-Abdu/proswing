import 'package:flutter/material.dart';

Future<void> showMessage(BuildContext context, String message, bool isSuccess,
    bool isTimerNeeded) async {
  // Show the dialog or snackbar
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing the dialog by clicking outside
    builder: (context) => AlertDialog(
      title: isSuccess ? const Text("Success") : const Text("Error"),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  // Delay for 1-2 seconds
  if (isTimerNeeded) {
    await Future.delayed(const Duration(seconds: 2));

    // Dismiss the dialog
    Navigator.pop(context);
  } else {
    return;
  }
}
