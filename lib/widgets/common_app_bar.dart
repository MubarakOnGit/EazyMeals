import 'package:flutter/material.dart';
import 'dart:io';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final File? profileImage;
  final VoidCallback? onProfileTap;
  final bool showProfile;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.profileImage,
    this.onProfileTap,
    this.showProfile = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.blue[900],
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
      actions: [
        if (showProfile) ...[
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue[900]!),
                image: profileImage != null
                    ? DecorationImage(
                        image: FileImage(profileImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profileImage == null
                  ? Icon(Icons.person, color: Colors.blue[900])
                  : null,
            ),
          ),
        ],
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 