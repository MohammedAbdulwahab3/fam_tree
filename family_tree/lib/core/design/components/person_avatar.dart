import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:family_tree/core/design/tokens.dart';
import 'package:family_tree/core/design/typography.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/models/person.dart';

/// A person's photograph, or their initials when there is none.
///
/// One widget for every avatar in the app. There were four near-identical
/// implementations, and they disagreed about what to show when a photo was
/// missing, whether a deceased relative was marked, and what happened when the
/// image failed to load.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.person,
    this.size = Sizes.avatarMd,
    this.localeTag,
    this.generation,
    this.showRing = false,
    this.onTap,
  });

  final Person person;
  final double size;

  /// Renders initials from the person's name in this locale, so an Amharic
  /// reader sees Amharic initials.
  final String? localeTag;

  /// Rings the avatar in the generation's colour, for the tree.
  final int? generation;

  final bool showRing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ringColor = generation != null
        ? AppTheme.getGenerationColor(generation!)
        : c.accent;

    final photo = person.profilePhotoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;

    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.accentSoft,
        border: showRing || generation != null
            ? Border.all(color: ringColor, width: size > 60 ? 3 : 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: photo,
              fit: BoxFit.cover,
              // A grey box while loading rather than a spinner: at avatar size
              // a spinner is noise, and the box is the right shape already.
              placeholder: (_, __) => ColoredBox(color: c.surfaceRaised),
              errorWidget: (_, __, ___) => _Initials(
                person: person,
                size: size,
                localeTag: localeTag,
                color: ringColor,
              ),
            )
          : _Initials(
              person: person,
              size: size,
              localeTag: localeTag,
              color: ringColor,
            ),
    );

    if (person.isDeceased) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          // Slightly desaturated rather than greyed out entirely — this is a
          // family record, and someone who has died is still a member of it.
          Opacity(opacity: 0.82, child: content),
          if (size >= Sizes.avatarMd)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_florist_rounded,
                  size: size * 0.22,
                  color: c.inkMuted,
                ),
              ),
            ),
        ],
      );
    }

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.person,
    required this.size,
    required this.localeTag,
    required this.color,
  });

  final Person person;
  final double size;
  final String? localeTag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.14),
      child: Text(
        person.initialsForLocaleTag(localeTag),
        style: AppType.subheading.copyWith(
          color: color,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
