// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'package:material_ui/material_ui.dart';

/// Shared AppBar `bottom` bar: a screen title with an optional trailing label.
///
/// Keeps the icon row in the toolbar uncrowded while the name stays readable.
/// Use as `AppBar.bottom` — it reports its own [preferredSize] so the toolbar
/// reserves exactly the space the bar draws in.
class AppBarSubtitle extends StatelessWidget implements PreferredSizeWidget {
  const AppBarSubtitle({super.key, required this.title, this.subtitle});

  /// Primary label, e.g. the channel or contact name.
  final String title;

  /// Optional secondary label shown to the right, e.g. "Private channel".
  final String? subtitle;

  /// Total bar height, including the bottom padding.
  static const double barHeight = 30.0;

  /// Toolbar height to pair with this bar, via `AppBar.toolbarHeight`.
  ///
  /// The Material default of 56 leaves 4px of slack around the 48px icon
  /// buttons, which reads as a gap between the icon row and this bar. 48 is
  /// the floor — below it the icon buttons overflow their own constraints.
  static const double toolbarHeight = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Container(
      height: barHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (subtitle != null)
            Expanded(
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
        ],
      ),
    );
  }
}
