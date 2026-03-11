import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/pocketbase_service.dart';
import '../../features/auth/providers/auth_provider.dart';

class CurrentUserAvatar extends ConsumerWidget {
  const CurrentUserAvatar({
    super.key,
    this.size = 36,
    this.showRing = false,
    this.ringWidth = 2,
    this.backgroundColor,
    this.textColor,
    this.ringColor,
  });

  final double size;
  final bool showRing;
  final double ringWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? ringColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final avatarFile = user?.getStringValue('avatar') ?? '';
    final avatarUrl = user != null && avatarFile.isNotEmpty
        ? getFileUrl(user, avatarFile)
        : null;
    final displayName = _displayName(auth);

    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor:
          backgroundColor ?? AppTheme.primaryColor.withValues(alpha: 0.12),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              _initials(displayName),
              style: TextStyle(
                color: textColor ?? AppTheme.primaryColor,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );

    if (!showRing) {
      return SizedBox(width: size, height: size, child: avatar);
    }

    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor ?? AppTheme.primaryColor.withValues(alpha: 0.45),
          width: ringWidth,
        ),
      ),
      child: avatar,
    );
  }

  static String _displayName(AuthState auth) {
    final nama = auth.user?.getStringValue('nama').trim() ?? '';
    if (nama.isNotEmpty) {
      return nama;
    }

    final name = auth.user?.getStringValue('name').trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final email = auth.user?.getStringValue('email').trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'User';
  }

  static String _initials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
