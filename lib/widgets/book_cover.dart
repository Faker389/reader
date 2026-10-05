import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/providers.dart';
import '../domain/models/book.dart';

/// Book cover: the imported image when available, otherwise a generated
/// typographic cover with a deterministic palette per book.
class BookCover extends ConsumerWidget {
  const BookCover({required this.book, required this.width, this.heroTag, super.key});

  static const double aspectRatio = 2 / 3;

  final Book book;
  final double width;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = width / aspectRatio;
    final radius = BorderRadius.circular(width * 0.07);
    final File? file = ref.watch(bookRepositoryProvider).coverFile(book);

    Widget cover = file != null
        ? Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, __, ___) => GeneratedCover(book: book, width: width),
          )
        : GeneratedCover(book: book, width: width);

    cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: width * 0.18, offset: Offset(0, width * 0.08)),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: cover),
    );

    return Semantics(
      image: true,
      label: 'Cover of ${book.title}',
      child: heroTag == null ? cover : Hero(tag: heroTag!, child: cover),
    );
  }
}

class GeneratedCover extends StatelessWidget {
  const GeneratedCover({required this.book, required this.width, super.key});

  final Book book;
  final double width;

  static const List<List<Color>> _palettes = [
    [Color(0xFF2E1065), Color(0xFF7C3AED)],
    [Color(0xFF3F0F2C), Color(0xFFDB2777)],
    [Color(0xFF0C2A3F), Color(0xFF0EA5E9)],
    [Color(0xFF1A2E1F), Color(0xFF16A34A)],
    [Color(0xFF3A1F0B), Color(0xFFEA580C)],
    [Color(0xFF1E1B4B), Color(0xFF6366F1)],
    [Color(0xFF2A2A2E), Color(0xFF71717A)],
    [Color(0xFF3B0A0A), Color(0xFFDC2626)],
  ];

  static const Map<String, int> _samplePalettes = {
    'sample_alice': 1,
    'sample_gatsby': 4,
    'sample_pride': 0,
    'sample_meditations': 6,
    'sample_sherlock': 2,
  };

  List<Color> get _palette {
    final index = _samplePalettes[book.id] ?? book.id.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff);
    return _palettes[index % _palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final height = width / BookCover.aspectRatio;
    final initial = book.title.trim().isEmpty ? '·' : book.title.trim()[0].toUpperCase();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette[1], palette[0]],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -width * 0.12,
            bottom: -width * 0.28,
            child: Text(
              initial,
              style: GoogleFonts.fraunces(
                fontSize: width * 1.05,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.10),
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: width * 0.1,
            top: height * 0.1,
            child: Container(width: width * 0.16, height: 2, color: Colors.white.withValues(alpha: 0.75)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(width * 0.1, height * 0.16, width * 0.1, height * 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fraunces(
                    fontSize: (width * 0.13).clamp(8, 30),
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (book.author.isNotEmpty)
                  Text(
                    book.author.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: (width * 0.065).clamp(6, 13),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
