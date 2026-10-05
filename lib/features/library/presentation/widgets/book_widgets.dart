import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/providers.dart';
import '../../../../domain/models/book.dart';
import '../../../../routing/routes.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_card.dart';
import '../../../../widgets/book_cover.dart';
import '../../../../widgets/buttons.dart';
import '../../../../widgets/pressable.dart';
import '../../../../widgets/progress.dart';
import '../../../../widgets/states.dart';
import '../../../settings/application/settings_controller.dart';

/// Opens the reader, or explains why the text isn't on this device.
void openBook(BuildContext context, Book book) {
  if (!book.contentAvailable) {
    showAppSnackBar(
      context,
      'This book was imported on another device. Import the file here to read it.',
      error: true,
    );
    return;
  }
  context.push(Routes.reader(book.id));
}

class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({required this.book, super.key});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final wpm = ref.watch(readerSettingsProvider.select((r) => r.defaultWpm));
    final remaining = book.estimatedTimeAt(wpm);
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => context.push(Routes.book(book.id)),
      semanticLabel: 'Continue reading ${book.title}',
      gradient: LinearGradient(
        colors: [c.accent.withValues(alpha: 0.20), c.card, c.card],
        stops: const [0, 0.55, 1],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(book: book, width: 92),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleLarge),
                if (book.author.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
                const SizedBox(height: 6),
                Text(
                  'Chapter ${book.currentChapter + 1} of ${book.chapterCount}',
                  style: context.text.bodySmall?.copyWith(color: c.subtle),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ProgressBar(value: book.progress)),
                    const SizedBox(width: 10),
                    Text(Formatters.percent(book.progress), style: context.text.labelLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${Formatters.compact(book.wordsRemaining)} words left · '
                  'about ${Formatters.duration(remaining)} at $wpm WPM',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.play_arrow_rounded,
                  height: 46,
                  expand: false,
                  onPressed: () => openBook(context, book),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover with title underneath, for horizontal shelves and grids.
class BookShelfCard extends StatelessWidget {
  const BookShelfCard({required this.book, required this.width, super.key});

  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () => context.push(Routes.book(book.id)),
        onLongPress: () => showBookActions(context, book),
        semanticLabel: book.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                BookCover(book: book, width: width),
                if (book.favorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.favorite_rounded, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                if (book.completed)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
            const SizedBox(height: 2),
            if (book.isInProgress) ...[
              const SizedBox(height: 4),
              ProgressBar(value: book.progress, height: 4),
            ] else
              Text(
                book.author.isEmpty ? Formatters.compact(book.totalWords) : book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class BookListTile extends StatelessWidget {
  const BookListTile({required this.book, super.key});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = book.completed
        ? 'Finished'
        : book.isInProgress
            ? '${Formatters.percent(book.progress)} · ${Formatters.relativeDate(book.lastOpenedAt)}'
            : '${Formatters.compact(book.totalWords)} words';
    return Pressable(
      onTap: () => context.push(Routes.book(book.id)),
      onLongPress: () => showBookActions(context, book),
      semanticLabel: book.title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            BookCover(book: book, width: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  if (book.author.isNotEmpty)
                    Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (book.completed) ...[
                        Icon(Icons.check_circle_rounded, size: 14, color: c.success),
                        const SizedBox(width: 4),
                      ],
                      if (!book.contentAvailable) ...[
                        Icon(Icons.cloud_outlined, size: 14, color: c.subtle),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      ),
                    ],
                  ),
                  if (book.isInProgress) ...[
                    const SizedBox(height: 8),
                    ProgressBar(value: book.progress, height: 4),
                  ],
                ],
              ),
            ),
            if (book.favorite) Icon(Icons.favorite_rounded, size: 18, color: c.accentSecondary),
            IconButton(
              tooltip: 'Book actions',
              icon: Icon(Icons.more_horiz_rounded, color: c.muted),
              onPressed: () => showBookActions(context, book),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showBookActions(BuildContext context, Book book) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _BookActionsSheet(book: book),
  );
}

class _BookActionsSheet extends ConsumerWidget {
  const _BookActionsSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final repo = ref.read(bookRepositoryProvider);

    Future<void> act(Future<void> Function() action, [String? done]) async {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      try {
        await action();
        if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
      } on Object {
        messenger.showSnackBar(const SnackBar(content: Text("That didn't work. Please try again.")));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  BookCover(book: book, width: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  ),
                ],
              ),
            ),
            if (book.contentAvailable)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: Text(book.isInProgress ? 'Continue reading' : 'Start reading'),
                onTap: () {
                  Navigator.of(context).pop();
                  openBook(context, book);
                },
              ),
            ListTile(
              leading: Icon(book.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              title: Text(book.favorite ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () => act(() => repo.toggleFavorite(book.id)),
            ),
            ListTile(
              leading: Icon(book.completed ? Icons.replay_rounded : Icons.check_circle_outline_rounded),
              title: Text(book.completed ? 'Mark as unread' : 'Mark as completed'),
              onTap: () => act(() => repo.setCompleted(book.id, !book.completed)),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: c.danger),
              title: Text('Remove from library', style: TextStyle(color: c.danger)),
              onTap: () async {
                final confirmed = await confirmDeleteBook(context, book);
                if (confirmed && context.mounted) {
                  await act(() => repo.delete(book.id), 'Removed “${book.title}”.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDeleteBook(BuildContext context, Book book) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove this book?'),
      content: Text(
        book.isSample
            ? '“${book.title}” and your progress in it will be removed. '
                'Your reading statistics are kept.'
            : '“${book.title}” will be deleted from this device and your progress removed. '
                'Your reading statistics are kept.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.colors.danger),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return result ?? false;
}
