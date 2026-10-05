import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/providers.dart';
import '../../../domain/models/book.dart';
import '../../../routing/routes.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/states.dart';
import '../../home/presentation/main_shell.dart';
import 'widgets/book_widgets.dart';

enum LibrarySort {
  recent('Recently read'),
  added('Recently added'),
  title('Title'),
  author('Author'),
  progress('Progress');

  const LibrarySort(this.label);
  final String label;
}

enum LibraryFilter {
  all('All'),
  reading('Reading'),
  notStarted('Not started'),
  completed('Completed'),
  favorites('Favorites');

  const LibraryFilter(this.label);
  final String label;

  bool matches(Book b) => switch (this) {
        LibraryFilter.all => true,
        LibraryFilter.reading => b.isInProgress,
        LibraryFilter.notStarted => !b.isStarted && !b.completed,
        LibraryFilter.completed => b.completed,
        LibraryFilter.favorites => b.favorite,
      };
}

List<Book> sortBooks(Iterable<Book> books, LibrarySort sort) {
  final list = books.toList();
  int byRecent(Book a, Book b) => (b.lastOpenedAt ?? b.createdAt).compareTo(a.lastOpenedAt ?? a.createdAt);
  switch (sort) {
    case LibrarySort.recent:
      list.sort(byRecent);
    case LibrarySort.added:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case LibrarySort.title:
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case LibrarySort.author:
      list.sort((a, b) => a.author.toLowerCase().compareTo(b.author.toLowerCase()));
    case LibrarySort.progress:
      list.sort((a, b) => b.progress.compareTo(a.progress));
  }
  return list;
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  LibrarySort _sort = LibrarySort.recent;
  LibraryFilter _filter = LibraryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _browsing => _query.isEmpty && _filter == LibraryFilter.all;

  bool _matchesQuery(Book b) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
            child: booksAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(booksProvider)),
              data: (books) {
                final visible = sortBooks(books.where((b) => _filter.matches(b) && _matchesQuery(b)), _sort);
                return CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(child: Text('Library', style: context.text.displaySmall)),
                            PopupMenuButton<LibrarySort>(
                              tooltip: 'Sort',
                              icon: Icon(Icons.swap_vert_rounded, color: c.text),
                              initialValue: _sort,
                              onSelected: (s) => setState(() => _sort = s),
                              itemBuilder: (_) => [
                                for (final s in LibrarySort.values)
                                  CheckedPopupMenuItem(value: s, checked: s == _sort, child: Text(s.label)),
                              ],
                            ),
                            const SizedBox(width: 4),
                            CircleIconButton(
                              icon: Icons.add_rounded,
                              tooltip: 'Import a book',
                              onPressed: () => context.push(Routes.import),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (books.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v.trim()),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search titles and authors',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(() {
                                        _search.clear();
                                        _query = '';
                                      }),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 56,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            children: [
                              for (final f in LibraryFilter.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(f.label),
                                    selected: _filter == f,
                                    onSelected: (_) => setState(() => _filter = f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (books.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: EmptyState(
                            icon: Icons.auto_stories_rounded,
                            title: 'Your library is waiting.',
                            message: 'Import an EPUB, TXT or CSV file and it will appear here.',
                            actionLabel: 'Import a book',
                            onAction: () => context.push(Routes.import),
                          ),
                        ),
                      )
                    else if (_browsing)
                      ..._sections(books)
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                        child: EmptyState(
                          compact: true,
                          icon: Icons.search_off_rounded,
                          title: 'Nothing matches',
                          message: _query.isEmpty
                              ? 'No books in “${_filter.label}” yet.'
                              : 'No books match “$_query”.',
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, i) => BookListTile(book: visible[i]),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: shellBottomInset(context))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(List<Book> books) {
    final reading = sortBooks(books.where((b) => b.isInProgress), LibrarySort.recent);
    final recentlyAdded = sortBooks(books, LibrarySort.added).take(8).toList();
    final completed = sortBooks(books.where((b) => b.completed), LibrarySort.recent);
    final favorites = sortBooks(books.where((b) => b.favorite), _sort);
    final all = sortBooks(books, _sort);

    Widget shelf(List<Book> list) => SliverToBoxAdapter(
          child: SizedBox(
            height: 110 / (2 / 3) + 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => BookShelfCard(book: list[i], width: 110),
            ),
          ),
        );

    void showOnly(LibraryFilter f) => setState(() => _filter = f);

    return [
      if (reading.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Continue reading',
            actionLabel: reading.length > 3 ? 'See all' : null,
            onAction: () => showOnly(LibraryFilter.reading),
          ),
        ),
        shelf(reading),
      ],
      if (books.length > 3) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'Recently added')),
        shelf(recentlyAdded),
      ],
      if (favorites.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Favorites',
            actionLabel: 'See all',
            onAction: () => showOnly(LibraryFilter.favorites),
          ),
        ),
        shelf(favorites),
      ],
      if (completed.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Completed',
            actionLabel: 'See all',
            onAction: () => showOnly(LibraryFilter.completed),
          ),
        ),
        shelf(completed),
      ],
      SliverToBoxAdapter(child: SectionHeader(title: 'My books · ${books.length}')),
      SliverList.builder(itemCount: all.length, itemBuilder: (_, i) => BookListTile(book: all[i])),
    ];
  }
}
