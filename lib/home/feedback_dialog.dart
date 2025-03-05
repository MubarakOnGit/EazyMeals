import 'package:flutter/material.dart';

class FeedbackDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Submit Feedback'),
      content: TextField(
        maxLines: 5,
        decoration: InputDecoration(hintText: 'Enter your feedback...'),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text('Submit'),
          onPressed: () {
            // Save feedback to Firebase
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
