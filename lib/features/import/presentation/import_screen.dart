import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/book.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/book_cover.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/motion.dart';
import '../../../widgets/states.dart';
import '../application/import_controller.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final controller = ref.read(importControllerProvider.notifier);

    final Widget body = switch (state) {
      ImportIdle() => _PickView(
          onPick: controller.pickFile,
          onPaste: (title, text) => controller.importPasted(title: title, text: text),
          onLink: controller.importLink,
        ),
      ImportProcessing(:final fileName) => _ProcessingView(fileName: fileName),
      final ImportCsvChoice s => _CsvChoiceView(state: s),
      final ImportReview s => _ReviewView(key: ValueKey(s.fileName), state: s),
      ImportDone(:final book) => _DoneView(book: book),
      ImportFailed(:final message) => _FailedView(message: message, onRetry: controller.pickFile),
    };

    final canGoBack = state is ImportCsvChoice || state is ImportReview || state is ImportFailed;
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.reset();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (state) {
            ImportReview() => 'Review',
            ImportCsvChoice() => 'Choose a column',
            _ => 'Import a book',
          }),
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.library),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AnimatedSwitcher(
                duration: context.motion(MotionConstants.medium),
                child: KeyedSubtree(key: ValueKey(state.runtimeType), child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({required this.onPick, required this.onPaste, required this.onLink});

  final VoidCallback onPick;
  final void Function(String title, String text) onPaste;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget format(String ext, String description, {bool soon = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: soon ? c.surface : c.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ext, style: context.text.labelLarge?.copyWith(color: soon ? c.subtle : c.accent)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(description, style: context.text.bodyMedium)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          onTap: onPick,
          semanticLabel: 'Choose a file to import',
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: c.accentGradient),
                child: Icon(Icons.upload_file_rounded, color: c.onAccent, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Choose a file', style: context.text.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Books you import are stored privately on this device.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Supported formats', style: context.text.titleMedium),
        const SizedBox(height: 14),
        format('EPUB', 'Most ebooks. Title, author, chapters and cover are detected. DRM-protected files can’t be opened.'),
        format('TXT', 'Plain text. Chapter headings like “Chapter 1” are detected automatically.'),
        format('CSV', 'Word lists or text in a column. You choose which column to read.'),
        format('PDF', 'Coming soon.', soon: true),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Browse files', icon: Icons.folder_open_rounded, onPressed: onPick),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Paste text or a link',
          icon: Icons.content_paste_rounded,
          onPressed: () => _pasteDialog(context),
        ),
      ],
    );
  }

  Future<void> _pasteDialog(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final link = TextEditingController();
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an article'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Link'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Article text', alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'link'), child: const Text('Use link')),
          TextButton(onPressed: () => Navigator.pop(context, 'text'), child: const Text('Use text')),
        ],
      ),
    );
    final pastedTitle = title.text;
    final pastedBody = body.text;
    final pastedLink = link.text;
    title.dispose();
    body.dispose();
    link.dispose();
    if (choice == 'link' && pastedLink.trim().isNotEmpty) onLink(pastedLink.trim());
    if (choice == 'text' && pastedBody.trim().isNotEmpty) onPaste(pastedTitle, pastedBody);
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 44,
              child: CircularProgressIndicator(strokeWidth: 3, color: context.colors.accent),
            ),
            const SizedBox(height: 28),
            Text('Preparing your book…', style: context.text.headlineSmall),
            const SizedBox(height: 8),
            Text(fileName, textAlign: TextAlign.center, style: context.text.bodyMedium),
            const SizedBox(height: 4),
            Text('Finding chapters and paragraphs.', style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CsvChoiceView extends ConsumerWidget {
  const _CsvChoiceView({required this.state});

  final ImportCsvChoice state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller = ref.read(importControllerProvider.notifier);
    final inspection = state.inspection;
    final rows = state.hasHeader || !inspection.hasHeader
        ? inspection.previewRows
        : [inspection.columns, ...inspection.previewRows];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('This file has ${inspection.columns.length} columns.', style: context.text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Pick the one that contains the words or text you want to read. '
          '${Formatters.number(inspection.rowCount)} rows found.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('First row is a header'),
          value: state.hasHeader,
          onChanged: controller.setCsvHeader,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < inspection.columns.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              onTap: () => controller.setCsvColumn(i),
              color: i == state.column ? c.accent.withValues(alpha: 0.12) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i == state.column ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: i == state.column ? c.accent : c.subtle,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.hasHeader ? inspection.columns[i] : 'Column ${i + 1}',
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rows.map((r) => i < r.length ? r[i] : '').where((v) => v.isNotEmpty).take(4).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Use this column', onPressed: controller.confirmCsv),
      ],
    );
  }
}

class _ReviewView extends ConsumerStatefulWidget {
  const _ReviewView({required this.state, super.key});

  final ImportReview state;

  @override
  ConsumerState<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<_ReviewView> {
  late final TextEditingController _title = TextEditingController(text: widget.state.book.title);
  late final TextEditingController _author = TextEditingController(text: widget.state.book.author);

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  ImportController get _controller => ref.read(importControllerProvider.notifier);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _renameChapter(int index, String current) async {
    final field = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename chapter'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: ImportConstants.maxChapterTitleLength,
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('Save')),
        ],
      ),
    );
    field.dispose();
    if (result != null && result.trim().isNotEmpty) _controller.renameChapter(index, result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.state;
    final book = s.book;
    final preview = Book(
      id: s.bookId,
      title: book.title.isEmpty ? 'Untitled' : book.title,
      author: book.author,
      format: s.format,
      source: BookSource.imported,
      totalWords: book.wordCount,
      chapterCount: book.chapters.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your book is ready.', style: context.text.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '${Formatters.number(book.wordCount)} words in ${book.chapters.length} '
          '${book.chapters.length == 1 ? 'chapter' : 'chapters'}. Check the details before adding it.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book.coverBytes != null
                      ? Image.memory(book.coverBytes!, width: 104, height: 156, fit: BoxFit.cover)
                      : GeneratedCover(book: preview, width: 104),
                ),
                TextButton(
                  onPressed: s.saving ? null : () => _guard(_controller.pickCover),
                  child: Text(book.coverBytes == null ? 'Add cover' : 'Change'),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    enabled: !s.saving,
                    maxLength: ImportConstants.maxTitleLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Title', counterText: ''),
                    onChanged: _controller.setTitle,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _author,
                    enabled: !s.saving,
                    maxLength: ImportConstants.maxAuthorLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Author', counterText: ''),
                    onChanged: _controller.setAuthor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Chapters', style: context.text.titleLarge)),
            Text('Tap to rename', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < book.chapters.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !s.saving,
            leading: SizedBox(
              width: 28,
              child: Text('${i + 1}', style: context.text.labelLarge?.copyWith(color: c.subtle)),
            ),
            title: Text(book.chapters[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${Formatters.number(book.chapters[i].wordCount)} words'),
            onTap: () => _renameChapter(i, book.chapters[i].title),
            trailing: PopupMenuButton<String>(
              tooltip: 'Chapter options',
              enabled: !s.saving,
              onSelected: (action) => switch (action) {
                'rename' => _renameChapter(i, book.chapters[i].title),
                'merge' => _controller.mergeWithPrevious(i),
                _ => _controller.removeChapter(i),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (i > 0) const PopupMenuItem(value: 'merge', child: Text('Merge with previous')),
                if (book.chapters.length > 1) const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Add to library',
          loading: s.saving,
          onPressed: () => _guard(_controller.save),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: s.saving ? null : _controller.reset, child: const Text('Choose a different file')),
      ],
    );
  }
}

class _DoneView extends ConsumerWidget {
  const _DoneView({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookCover(book: book, width: 140),
            const SizedBox(height: 28),
            Icon(Icons.check_circle_rounded, color: c.success, size: 32),
            const SizedBox(height: 12),
            Text('Added to your library.', style: context.text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(book.title, style: context.text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Start reading',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.pushReplacement(Routes.reader(book.id)),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Import another',
              onPressed: ref.read(importControllerProvider.notifier).reset,
            ),
            TextButton(onPressed: () => context.go(Routes.library), child: const Text('Back to Library')),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: "We couldn't import that file",
        message: message,
        actionLabel: 'Choose another file',
        onAction: onRetry,
      ),
    );
  }
}
