import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
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
    if (_isBrowserFile(avatar)) {
      return _StoredAvatar(relative: avatar, size: size, cache: cache, fallback: fallback);
    }
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

/// A path with no directory separators is a key in the browser file store.
/// Device avatars are absolute filesystem paths.
bool _isBrowserFile(String value) =>
    !value.startsWith('http') && !value.startsWith('/') && !value.contains('\\') && !value.contains(':/');

class _StoredAvatar extends ConsumerWidget {
  const _StoredAvatar({required this.relative, required this.size, required this.cache, required this.fallback});

  final String relative;
  final double size;
  final int cache;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(storedBytesProvider(relative)).asData?.value;
    if (bytes == null) return fallback;
    return ClipOval(
      child: Image(
        image: ResizeImage(MemoryImage(bytes), width: cache),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
