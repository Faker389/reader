import 'package:flutter/material.dart';

import '../../../../domain/models/book.dart';
import '../../../../theme/app_colors.dart';

/// Lists saved places in the current book.
Future<void> showBookmarkSheet(
  BuildContext context, {
  required List<BookBookmark> bookmarks,
  required void Function(int wordIndex) onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final c = context.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: bookmarks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No saved places yet. Pause and tap Save place to keep a sentence.',
                    style: context.text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text('Saved places', style: context.text.titleMedium),
                    ),
                    for (final bookmark in bookmarks)
                      ListTile(
                        leading: Icon(Icons.bookmark_rounded, color: c.accent),
                        title: Text(bookmark.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.of(context).pop();
                          onOpen(bookmark.wordIndex);
                        },
                      ),
                  ],
                ),
        ),
      );
    },
  );
}
