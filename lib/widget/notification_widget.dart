import 'package:flutter/material.dart';

class NotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isSuccess; // true for success, false for failure

  const NotificationDialog({
    super.key,
    required this.title,
    required this.message,
    this.isSuccess = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
