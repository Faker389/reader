import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/models/user_profile.dart';
import '../../../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.profile, this.size = 72, super.key});

  final UserProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatar = profile?.avatar;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: c.accentGradient),
      alignment: Alignment.center,
      child: Text(
        profile?.initials ?? '?',
        style: context.text.titleLarge?.copyWith(color: c.onAccent, fontSize: size * 0.36),
      ),
    );
    if (avatar == null || avatar.isEmpty) return fallback;

    final cache = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final ImageProvider image = avatar.startsWith('http')
        ? ResizeImage(NetworkImage(avatar), width: cache)
        : ResizeImage(FileImage(File(avatar)), width: cache);
    return ClipOval(
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
