import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../domain/models/book_content.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/buttons.dart';

/// Chapter list plus a position scrubber for jumping anywhere in the book.
class ChapterSheet extends StatefulWidget {
  const ChapterSheet({
    required this.content,
    required this.position,
    required this.wpm,
    required this.onChapter,
    required this.onFraction,
    super.key,
  });

  final BookContent content;
  final int position;
  final int wpm;
  final ValueChanged<int> onChapter;
  final ValueChanged<double> onFraction;

  @override
  State<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<ChapterSheet> {
  late double _fraction =
      widget.content.length <= 1 ? 0 : widget.position / (widget.content.length - 1);

  int get _targetIndex => (_fraction * (widget.content.length - 1)).round();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = widget.content;
    final current = content.chapterIndexAt(widget.position);
    final previewChapter = content.chapters.isEmpty ? null : content.chapters[content.chapterIndexAt(_targetIndex)];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => CustomScrollView(
        controller: scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jump to position', style: context.text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${Formatters.percent(_fraction)} · ${previewChapter?.title ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium,
                  ),
                  Slider(
                    value: _fraction.clamp(0, 1),
                    onChanged: (v) => setState(() => _fraction = v),
                    semanticFormatterCallback: (v) => Formatters.percent(v),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '“${content.words[_targetIndex]}”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyLarge?.copyWith(color: c.muted, fontStyle: FontStyle.italic),
                        ),
                      ),
                      PrimaryButton(
                        label: 'Jump here',
                        expand: false,
                        height: 44,
                        onPressed: () {
                          widget.onFraction(_fraction);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Chapters', style: context.text.titleLarge),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: content.chapters.length,
            itemBuilder: (context, i) {
              final chapter = content.chapters[i];
              final words = content.chapterWordCount(i);
              final isCurrent = i == current;
              return ListTile(
                selected: isCurrent,
                selectedTileColor: c.accent.withValues(alpha: 0.1),
                leading: SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: context.text.labelLarge?.copyWith(color: isCurrent ? c.accent : c.subtle),
                  ),
                ),
                title: Text(chapter.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                subtitle: Text(
                  '${Formatters.compact(words)} words · ${Formatters.duration(Duration(seconds: (words / widget.wpm * 60).round()))}',
                  style: context.text.bodySmall,
                ),
                trailing: isCurrent ? Icon(Icons.graphic_eq_rounded, color: c.accent) : null,
                onTap: () {
                  widget.onChapter(i);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
