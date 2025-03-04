import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSnackBar extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'success', 'error', 'loading', 'info'

  const GlassSnackBar({
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green.withOpacity(0.9);
        textColor = Colors.white;
        break;
      case 'error':
        backgroundColor = Colors.redAccent.withOpacity(0.9);
        textColor = Colors.white;
        break;
      case 'loading':
        backgroundColor = theme.primaryColor.withOpacity(0.9);
        textColor = Colors.white;
        break;
      default: // info
        backgroundColor =
            isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.white.withOpacity(0.9);
        textColor = isDark ? Colors.white : Colors.black;
    }

    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor.withOpacity(0.7),
            backgroundColor.withOpacity(0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
                  ),
                ),
                if (type == 'loading')
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to show the snackbar
void showGlassSnackBar({
  required BuildContext context,
  required String title,
  required String message,
  required String type,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: type == 'loading' ? Duration(minutes: 5) : duration,
      content: GlassSnackBar(title: title, message: message, type: type),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
