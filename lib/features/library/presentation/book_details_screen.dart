import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/sanitize.dart';
import '../../../data/providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/reading_session.dart';
import '../../../domain/models/book_content.dart';
import '../../../domain/reading/reading_pace.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/book_cover.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/progress.dart';
import '../../../widgets/states.dart';
import '../../settings/application/settings_controller.dart';
import '../../statistics/application/stats_providers.dart';
import 'widgets/book_widgets.dart';

String _finishLine(Book book, int wpm, int minutes) {
  final days = ReadingPace.daysRemaining(wordsRemaining: book.wordsRemaining, wpm: wpm, minutesPerDay: minutes);
  if (days == null || days <= 0) return 'You could finish this today.';
  final date = ReadingPace.finishOn(wordsRemaining: book.wordsRemaining, wpm: wpm, minutesPerDay: minutes);
  return 'At $minutes minutes a day, this finishes around ${Formatters.shortDate(date!)}.';
}

final _bookContentProvider = FutureProvider.autoDispose.family<BookContent, String>(
  (ref, id) => ref.watch(bookRepositoryProvider).loadContent(id),
);

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(bookProvider(bookId));
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.menu_book_rounded,
          title: 'Book not found',
          message: 'It may have been removed from your library.',
          actionLabel: 'Back to Library',
          onAction: () => context.go(Routes.library),
        ),
      );
    }
    final c = context.colors;
    final wpm = ref.watch(readerSettingsProvider.select((r) => r.defaultWpm));
    final goalMinutes = ref.watch(goalMinutesProvider);
    final sessions = [
      for (final session in ref.watch(sessionsProvider).value ?? const <ReadingSession>[])
        if (session.bookId == book.id) session,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
    final repo = ref.read(bookRepositoryProvider);
    final wide = MediaQuery.sizeOf(context).width >= LayoutConstants.tabletBreakpoint;

    final header = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        BookCover(book: book, width: wide ? 200 : 168),
        const SizedBox(height: 24),
        Text(
          book.title,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: context.text.headlineLarge,
        ),
        if (book.author.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(book.author, style: context.text.bodyLarge?.copyWith(color: c.muted)),
        ],
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (book.isInProgress) ...[
          Row(
            children: [
              Expanded(child: ProgressBar(value: book.progress, height: 8)),
              const SizedBox(width: 12),
              Text(Formatters.percent(book.progress), style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (book.contentAvailable)
          PrimaryButton(
            label: book.completed ? 'Read again' : (book.isStarted ? 'Continue reading' : 'Start reading'),
            icon: Icons.play_arrow_rounded,
            onPressed: () => openBook(context, book),
          )
        else
          AppCard(
            color: c.surface,
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, color: c.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This book was imported on another device. Import the same file here to read it — '
                    'your progress will carry over.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: book.favorite ? 'Favorited' : 'Favorite',
                icon: book.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                height: 48,
                onPressed: () => repo.toggleFavorite(book.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'More',
                icon: Icons.more_horiz_rounded,
                height: 48,
                onPressed: () => _showMore(context, ref, book),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _Fact(label: 'Words', value: Formatters.compact(book.totalWords))),
            Expanded(child: _Fact(label: 'Chapters', value: '${book.chapterCount}')),
            Expanded(
              child: _Fact(
                label: book.isStarted && !book.completed ? 'Time left' : 'Read time',
                value: Formatters.duration(
                  book.estimatedTimeAt(wpm, words: book.completed ? book.totalWords : null),
                ),
              ),
            ),
          ],
        ),
        if (!book.completed && book.wordsRemaining > 0) ...[
          const SizedBox(height: 16),
          Text(_finishLine(book, wpm, goalMinutes), style: context.text.bodyMedium),
        ],
        if (book.bookmarks.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Saved places', style: context.text.titleLarge),
          const SizedBox(height: 8),
          for (final bookmark in book.bookmarks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bookmark_rounded, color: c.accent),
              title: Text(bookmark.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: book.contentAvailable
                  ? () => context.push(Routes.reader(book.id, start: bookmark.wordIndex))
                  : null,
            ),
        ],
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Recent sessions', style: context.text.titleLarge),
          const SizedBox(height: 8),
          for (final session in sessions.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(Formatters.relativeDate(session.startTime)),
              subtitle: Text(
                '${Formatters.compact(session.wordsRead)} words · ${session.averageWpm} WPM · '
                '${Formatters.duration(Duration(seconds: session.durationSeconds))}',
              ),
            ),
        ],
        if (book.sessionsCount > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Fact(label: 'Sessions', value: '${book.sessionsCount}')),
              Expanded(
                child: _Fact(
                  label: 'Time spent',
                  value: Formatters.duration(Duration(seconds: book.totalReadingSeconds)),
                ),
              ),
              Expanded(child: _Fact(label: 'Last read', value: Formatters.relativeDate(book.lastOpenedAt))),
            ],
          ),
        ],
        if (book.description != null && book.description!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(book.description!, style: context.text.bodyLarge?.copyWith(color: c.muted)),
        ],
        if (book.contentAvailable) ...[
          const SizedBox(height: 28),
          Text('Chapters', style: context.text.titleLarge),
          const SizedBox(height: 8),
          _ChapterList(book: book, wpm: wpm),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit details',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editDetails(context, ref, book),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: wide
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: header),
                        const SizedBox(width: 40),
                        Expanded(child: body),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [header, const SizedBox(height: 28), body],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMore(BuildContext context, WidgetRef ref, Book book) async {
    final repo = ref.read(bookRepositoryProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (book.isStarted)
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Restart from the beginning'),
                onTap: () => Navigator.pop(context, 'restart'),
              ),
            ListTile(
              leading: Icon(book.completed ? Icons.replay_rounded : Icons.check_circle_outline_rounded),
              title: Text(book.completed ? 'Mark as unread' : 'Mark as completed'),
              onTap: () => Navigator.pop(context, 'complete'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: context.colors.danger),
              title: Text('Remove from library', style: TextStyle(color: context.colors.danger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    try {
      switch (action) {
        case 'restart':
          await repo.restart(book.id);
        case 'complete':
          await repo.setCompleted(book.id, !book.completed);
        case 'delete':
          if (await confirmDeleteBook(context, book)) {
            await repo.delete(book.id);
            if (context.mounted) context.pop();
          }
      }
    } on Object catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _editDetails(BuildContext context, WidgetRef ref, Book book) async {
    final title = TextEditingController(text: book.title);
    final author = TextEditingController(text: book.author);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: ImportConstants.maxTitleLength,
              decoration: const InputDecoration(labelText: 'Title', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: author,
              maxLength: ImportConstants.maxAuthorLength,
              decoration: const InputDecoration(labelText: 'Author', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final newTitle = Sanitize.line(title.text, maxLength: ImportConstants.maxTitleLength);
    final newAuthor = Sanitize.line(author.text, maxLength: ImportConstants.maxAuthorLength);
    title.dispose();
    author.dispose();
    if (saved != true) return;
    if (newTitle.isEmpty) {
      if (context.mounted) showAppSnackBar(context, 'A book needs a title.', error: true);
      return;
    }
    await ref.read(bookRepositoryProvider).updateDetails(book.id, title: newTitle, author: newAuthor);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.text.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
        ],
      );
}

class _ChapterList extends ConsumerWidget {
  const _ChapterList({required this.book, required this.wpm});

  final Book book;
  final int wpm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final content = ref.watch(_bookContentProvider(book.id));
    return content.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingState()),
      error: (e, _) => ErrorState(error: e, title: "Chapters couldn't be loaded"),
      data: (content) {
        final current = content.chapterIndexAt(book.currentWordIndex);
        return Column(
          children: [
            for (var i = 0; i < content.chapters.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: context.text.labelLarge?.copyWith(color: i == current && book.isStarted ? c.accent : c.subtle),
                  ),
                ),
                title: Text(content.chapters[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${Formatters.compact(content.chapterWordCount(i))} words · '
                  '${Formatters.duration(book.estimatedTimeAt(wpm, words: content.chapterWordCount(i)))}',
                ),
                trailing: i == current && book.isInProgress
                    ? Icon(Icons.bookmark_rounded, color: c.accent, size: 20)
                    : null,
                onTap: () => context.push(Routes.reader(book.id, start: content.chapters[i].startIndex)),
              ),
          ],
        );
      },
    );
  }
}
